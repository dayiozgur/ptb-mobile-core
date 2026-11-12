import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Self-service password change — current-password verification (CRA F-108
/// mobile counterpart).
///
/// Changing the password from an open session MUST prove knowledge of the
/// current password; otherwise anybody holding an unlocked device can take
/// over the account. Recovery-link and invite flows legitimately set a
/// password without the current one and keep using
/// `AuthService.updatePassword`.

/// Strong-password rule shared by every "set a new password" surface
/// (identical to `AcceptInviteScreen` and the web platform): at least
/// [minLength] characters and a mix of letters and digits.
class PasswordPolicy {
  PasswordPolicy._();

  /// Minimum password length.
  static const int minLength = 8;

  static final RegExp _letter = RegExp(r'[A-Za-zĞÜŞİÖÇğüşıöç]');
  static final RegExp _digit = RegExp(r'\d');

  /// `true` when [password] is long enough.
  static bool hasMinLength(String password) => password.length >= minLength;

  /// `true` when [password] contains both a letter and a digit.
  static bool hasLetterAndDigit(String password) =>
      _letter.hasMatch(password) && _digit.hasMatch(password);

  /// `true` when [password] satisfies the whole rule.
  static bool isStrong(String password) =>
      hasMinLength(password) && hasLetterAndDigit(password);
}

/// Outcome of checking the current password against the auth server.
enum PasswordVerification {
  /// The password is correct for the signed-in user.
  verified,

  /// The server rejected the credentials (wrong password).
  wrongPassword,

  /// HTTP 429 / rate limit — must NOT be reported as a wrong password.
  rateLimited,

  /// No response from the server (offline, timeout, DNS…).
  networkError,

  /// Anything else (5xx, unexpected payload, user mismatch…).
  failed,
}

/// Verifies a user's current password without touching the app session.
abstract class CurrentPasswordVerifier {
  /// Checks [password] for [email]. When [expectedUserId] is given, the
  /// verified identity must match it.
  Future<PasswordVerification> verify({
    required String email,
    required String password,
    String? expectedUserId,
  });
}

/// [CurrentPasswordVerifier] backed by a throwaway, stateless HTTP call to the
/// GoTrue password grant (`POST {authUrl}/token?grant_type=password`), followed
/// by a best-effort `POST {authUrl}/logout?scope=local` that revokes only the
/// throwaway session.
///
/// Why not a second `GoTrueClient`: on Flutter web every `GoTrueClient` opens
/// a `BroadcastChannel` named after the project host and re-posts every auth
/// event on it; the main client listens on the same channel, so the
/// throwaway client's `signedIn`/`signedOut` would be applied to the real
/// session (and sign the user out). A fresh [Dio] with no interceptors keeps
/// nothing in memory, writes nothing to storage, and emits no auth events.
class SupabaseCurrentPasswordVerifier implements CurrentPasswordVerifier {
  /// [authUrl] is `<supabaseUrl>/auth/v1`; [apiKey] the anon/publishable key.
  SupabaseCurrentPasswordVerifier({
    required String authUrl,
    required String apiKey,
    Dio? dio,
  })  : _authUrl = authUrl.endsWith('/')
            ? authUrl.substring(0, authUrl.length - 1)
            : authUrl,
        _apiKey = apiKey,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));

  /// Builds a verifier from the project URL (`https://<ref>.supabase.co`).
  factory SupabaseCurrentPasswordVerifier.forProject({
    required String supabaseUrl,
    required String apiKey,
    Dio? dio,
  }) {
    final base = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    return SupabaseCurrentPasswordVerifier(
      authUrl: '$base/auth/v1',
      apiKey: apiKey,
      dio: dio,
    );
  }

  /// Derives URL + key from an initialised [SupabaseClient]
  /// (`client.rest.url` = `<supabaseUrl>/rest/v1`, `client.auth.headers`
  /// carries `apikey`). Returns `null` when they cannot be derived.
  static SupabaseCurrentPasswordVerifier? fromClient(SupabaseClient client) {
    final restUrl = client.rest.url;
    final apiKey = client.auth.headers['apikey'];
    const suffix = '/rest/v1';
    if (apiKey == null || apiKey.isEmpty || !restUrl.endsWith(suffix)) {
      return null;
    }
    return SupabaseCurrentPasswordVerifier.forProject(
      supabaseUrl: restUrl.substring(0, restUrl.length - suffix.length),
      apiKey: apiKey,
    );
  }

  final String _authUrl;
  final String _apiKey;
  final Dio _dio;

  Map<String, String> get _baseHeaders => {
        'apikey': _apiKey,
        'Content-Type': 'application/json',
      };

  @override
  Future<PasswordVerification> verify({
    required String email,
    required String password,
    String? expectedUserId,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '$_authUrl/token',
        queryParameters: const {'grant_type': 'password'},
        data: {'email': email, 'password': password},
        options: Options(headers: _baseHeaders),
      );
    } on DioException catch (e) {
      return classifyError(e);
    } catch (_) {
      return PasswordVerification.failed;
    }

    final body = response.data;
    if (body is! Map) return PasswordVerification.failed;
    final accessToken = body['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      return PasswordVerification.failed;
    }

    // Revoke only the throwaway session (scope=local). Never fails the check.
    await _revoke(accessToken);

    if (expectedUserId != null) {
      final user = body['user'];
      final id = user is Map ? user['id'] : null;
      if (id != expectedUserId) return PasswordVerification.failed;
    }
    return PasswordVerification.verified;
  }

  Future<void> _revoke(String accessToken) async {
    try {
      await _dio.post<dynamic>(
        '$_authUrl/logout',
        queryParameters: const {'scope': 'local'},
        options: Options(headers: {
          ..._baseHeaders,
          'Authorization': 'Bearer $accessToken',
        }),
      );
    } catch (_) {
      // Best effort: the throwaway token expires on its own.
    }
  }

  /// Maps a failed password-grant call to a [PasswordVerification].
  static PasswordVerification classifyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return PasswordVerification.networkError;
      case DioExceptionType.unknown:
        return e.error is SocketException
            ? PasswordVerification.networkError
            : PasswordVerification.failed;
      case DioExceptionType.badResponse:
        break;
      default:
        return PasswordVerification.failed;
    }

    final status = e.response?.statusCode;
    final data = e.response?.data;
    final code = _errorCode(data);
    final message = _errorMessage(data).toLowerCase();

    if (status == 429 ||
        code == 'over_request_rate_limit' ||
        message.contains('rate limit')) {
      return PasswordVerification.rateLimited;
    }
    if (code == 'invalid_credentials' ||
        (status == 400 && message.contains('invalid login credentials'))) {
      return PasswordVerification.wrongPassword;
    }
    return PasswordVerification.failed;
  }

  static String? _errorCode(dynamic data) {
    if (data is! Map) return null;
    final errorCode = data['error_code'];
    if (errorCode is String) return errorCode;
    // API version >= 2024-01-01 puts the string code in `code`.
    final code = data['code'];
    return code is String ? code : null;
  }

  static String _errorMessage(dynamic data) {
    if (data is Map) {
      for (final key in const [
        'msg',
        'message',
        'error_description',
        'error'
      ]) {
        final v = data[key];
        if (v is String) return v;
      }
      return '';
    }
    return data is String ? data : '';
  }
}

/// Outcome of a verified self-service password change.
enum PasswordChangeOutcome {
  /// Password changed.
  success,

  /// The current password is wrong — show on the current-password field.
  wrongCurrentPassword,

  /// The new password equals the current one.
  samePassword,

  /// The new password violates [PasswordPolicy] (or the server's rule).
  weakPassword,

  /// Rate limited — show a "wait and retry" message, never "wrong password".
  rateLimited,

  /// No network — show the generic error.
  networkError,

  /// No signed-in user with an email address.
  sessionMissing,

  /// Any other failure — show the generic error.
  failed,
}

/// Result of `AuthService.changePasswordVerified`.
class PasswordChangeResult {
  /// Creates a result.
  const PasswordChangeResult(this.outcome, {this.error});

  /// The outcome.
  final PasswordChangeOutcome outcome;

  /// Underlying error (for logging only — never show raw to the user).
  final Object? error;

  /// `true` when the password was changed.
  bool get isSuccess => outcome == PasswordChangeOutcome.success;

  @override
  String toString() => 'PasswordChangeResult($outcome)';
}

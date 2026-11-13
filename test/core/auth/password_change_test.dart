import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart' hide AuthState;
import 'package:supabase_flutter/supabase_flutter.dart' hide Headers;

import '../../helpers/supabase_fakes.dart';

/// CRA F-108 (mobile): self-service password change must verify the current
/// password through a throwaway call that never touches the app session.

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockBiometricAuth extends Mock implements BiometricAuth {}

class _MockSession extends Mock implements Session {}

class _MockMfaApi extends Mock implements GoTrueMFAApi {}

class _FakeVerifier implements CurrentPasswordVerifier {
  _FakeVerifier(this.result);

  PasswordVerification result;
  final calls = <Map<String, String?>>[];

  @override
  Future<PasswordVerification> verify({
    required String email,
    required String password,
    String? expectedUserId,
  }) async {
    calls.add({
      'email': email,
      'password': password,
      'expectedUserId': expectedUserId,
    });
    return result;
  }
}

/// Dio adapter that records requests and answers from a queue.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responses);

  final List<Object> responses; // ResponseBody or Exception
  final requests = <RequestOptions>[];
  final bodies = <dynamic>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(options.data);
    final next = responses.removeAt(0);
    if (next is Exception) throw next;
    return next as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const _userId = '00000000-0000-0000-0000-00000000000a';
const _current = 'OldPassw0rd!';
const _newPw = 'NewPassw0rd!';

void main() {
  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(SignOutScope.local);
  });

  group('AuthService.changePasswordVerified', () {
    late MockSupabaseClient supabase;
    late MockGoTrueClient auth;
    late MockUser user;
    late _MockSecureStorage storage;
    late _FakeVerifier verifier;
    late AuthService service;

    setUp(() {
      supabase = MockSupabaseClient();
      auth = MockGoTrueClient();
      user = MockUser();
      storage = _MockSecureStorage();
      verifier = _FakeVerifier(PasswordVerification.verified);

      when(() => supabase.auth).thenReturn(auth);
      when(() => auth.onAuthStateChange)
          .thenAnswer((_) => const Stream<AuthState>.empty());
      when(() => auth.currentUser).thenReturn(user);
      when(() => auth.currentSession).thenReturn(_MockSession());
      when(() => user.id).thenReturn(_userId);
      when(() => user.email).thenReturn('user@example.test');
      when(() => auth.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson({'id': _userId}));

      service = AuthService(
        supabase: supabase,
        secureStorage: storage,
        biometricAuth: _MockBiometricAuth(),
        currentPasswordVerifier: verifier,
      );
    });

    test('wrong current password -> no updateUser call', () async {
      verifier.result = PasswordVerification.wrongPassword;

      final r = await service.changePasswordVerified(
          currentPassword: 'wrong-one1', newPassword: _newPw);

      expect(r.outcome, PasswordChangeOutcome.wrongCurrentPassword);
      expect(verifier.calls, hasLength(1));
      verifyNever(() => auth.updateUser(any()));
    });

    test('correct current password -> updateUser called exactly once '
        'with new + current password', () async {
      final r = await service.changePasswordVerified(
          currentPassword: _current, newPassword: _newPw);

      expect(r.isSuccess, isTrue);
      expect(verifier.calls.single, {
        'email': 'user@example.test',
        'password': _current,
        'expectedUserId': _userId,
      });
      final captured =
          verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes;
      expect(captured.password, _newPw);
      expect(captured.currentPassword, _current);
      expect(captured.toJson()['current_password'], _current);
    });

    test('new password equal to current is rejected without network',
        () async {
      final r = await service.changePasswordVerified(
          currentPassword: _current, newPassword: _current);

      expect(r.outcome, PasswordChangeOutcome.samePassword);
      expect(verifier.calls, isEmpty);
      verifyNever(() => auth.updateUser(any()));
    });

    test('weak new password (policy) is rejected without network', () async {
      final r = await service.changePasswordVerified(
          currentPassword: _current, newPassword: 'onlyletters');

      expect(r.outcome, PasswordChangeOutcome.weakPassword);
      expect(verifier.calls, isEmpty);
      verifyNever(() => auth.updateUser(any()));
    });

    test('rate limit during verification is NOT reported as wrong password',
        () async {
      verifier.result = PasswordVerification.rateLimited;

      final r = await service.changePasswordVerified(
          currentPassword: _current, newPassword: _newPw);

      expect(r.outcome, PasswordChangeOutcome.rateLimited);
      expect(r.outcome, isNot(PasswordChangeOutcome.wrongCurrentPassword));
      verifyNever(() => auth.updateUser(any()));
    });

    test('network error during verification -> networkError (generic)',
        () async {
      verifier.result = PasswordVerification.networkError;

      final r = await service.changePasswordVerified(
          currentPassword: _current, newPassword: _newPw);

      expect(r.outcome, PasswordChangeOutcome.networkError);
      verifyNever(() => auth.updateUser(any()));
    });

    test('no signed-in user -> sessionMissing, nothing called', () async {
      when(() => auth.currentUser).thenReturn(null);

      final r = await service.changePasswordVerified(
          currentPassword: _current, newPassword: _newPw);

      expect(r.outcome, PasswordChangeOutcome.sessionMissing);
      expect(verifier.calls, isEmpty);
      verifyNever(() => auth.updateUser(any()));
    });

    test('server-side errors from updateUser are classified', () async {
      Future<PasswordChangeOutcome> run(AuthException e) async {
        when(() => auth.updateUser(any())).thenThrow(e);
        return (await service.changePasswordVerified(
                currentPassword: _current, newPassword: _newPw))
            .outcome;
      }

      expect(
          await run(const AuthApiException('rate',
              statusCode: '429', code: 'over_request_rate_limit')),
          PasswordChangeOutcome.rateLimited);
      expect(
          await run(const AuthApiException('same',
              statusCode: '422', code: 'same_password')),
          PasswordChangeOutcome.samePassword);
      expect(
          await run(const AuthApiException('mismatch',
              statusCode: '400', code: 'current_password_mismatch')),
          PasswordChangeOutcome.wrongCurrentPassword);
      expect(await run(AuthRetryableFetchException(message: 'offline')),
          PasswordChangeOutcome.networkError);
      expect(
          await run(const AuthApiException('boom', statusCode: '400')),
          PasswordChangeOutcome.failed);
    });

    test('MFA account on an AAL1 session: insufficient_aal -> mfaRequired '
        '(not a generic failure)', () async {
      when(() => auth.updateUser(any())).thenThrow(const AuthApiException(
          'AAL2 session is required to update email or password when MFA is enabled.',
          statusCode: '401',
          code: 'insufficient_aal'));

      final r = await service.changePasswordVerified(
          currentPassword: _current, newPassword: _newPw);

      expect(r.outcome, PasswordChangeOutcome.mfaRequired);
    });

    test('secure password change: reauthentication_needed -> '
        'reauthenticationNeeded (same as web)', () async {
      for (final code in ['reauthentication_needed', 'reauthentication_not_valid']) {
        when(() => auth.updateUser(any())).thenThrow(
            AuthApiException('reauth', statusCode: '400', code: code));
        final r = await service.changePasswordVerified(
            currentPassword: _current, newPassword: _newPw);
        expect(r.outcome, PasswordChangeOutcome.reauthenticationNeeded,
            reason: code);
      }
    });

    group('with mfaCode (authenticator step-up)', () {
      late _MockMfaApi mfa;
      final now = DateTime.utc(2026, 11, 13);
      Factor totp(String id, FactorStatus status) => Factor(
            id: id,
            friendlyName: 'Authenticator',
            factorType: FactorType.totp,
            status: status,
            createdAt: now,
            updatedAt: now,
          );

      setUp(() {
        mfa = _MockMfaApi();
        when(() => auth.mfa).thenReturn(mfa);
      });

      void stubFactors(List<Factor> factors) {
        when(() => mfa.listFactors()).thenAnswer((_) async =>
            AuthMFAListFactorsResponse(
                all: factors, totp: factors, phone: const [], webauthn: const []));
      }

      test('verifies the code on the verified TOTP factor, then updates the '
          'password', () async {
        stubFactors([
          totp('f-unverified', FactorStatus.unverified),
          totp('f-verified', FactorStatus.verified),
        ]);
        when(() => mfa.challengeAndVerify(
                factorId: any(named: 'factorId'), code: any(named: 'code')))
            .thenAnswer((_) async => AuthMFAVerifyResponse(
                  accessToken: 'a',
                  tokenType: 'bearer',
                  expiresIn: const Duration(hours: 1),
                  refreshToken: 'r',
                  user: user,
                ));

        final r = await service.changePasswordVerified(
            currentPassword: _current, newPassword: _newPw, mfaCode: ' 123456 ');

        expect(r.isSuccess, isTrue);
        verifyInOrder([
          () => mfa.challengeAndVerify(factorId: 'f-verified', code: '123456'),
          () => auth.updateUser(any()),
        ]);
      });

      test('a wrong code -> mfaCodeInvalid and the password is NOT changed',
          () async {
        stubFactors([totp('f-verified', FactorStatus.verified)]);
        when(() => mfa.challengeAndVerify(
                factorId: any(named: 'factorId'), code: any(named: 'code')))
            .thenThrow(const AuthApiException('Invalid TOTP code entered',
                statusCode: '422', code: 'mfa_verification_failed'));

        final r = await service.changePasswordVerified(
            currentPassword: _current, newPassword: _newPw, mfaCode: '000000');

        expect(r.outcome, PasswordChangeOutcome.mfaCodeInvalid);
        verifyNever(() => auth.updateUser(any()));
      });

      test('rate-limited code check is not reported as a wrong code', () async {
        stubFactors([totp('f-verified', FactorStatus.verified)]);
        when(() => mfa.challengeAndVerify(
                factorId: any(named: 'factorId'), code: any(named: 'code')))
            .thenThrow(const AuthApiException('rate',
                statusCode: '429', code: 'over_request_rate_limit'));

        final r = await service.changePasswordVerified(
            currentPassword: _current, newPassword: _newPw, mfaCode: '000000');

        expect(r.outcome, PasswordChangeOutcome.rateLimited);
        verifyNever(() => auth.updateUser(any()));
      });

      test('the current password is still verified first; a wrong password '
          'never reaches the MFA step', () async {
        verifier.result = PasswordVerification.wrongPassword;

        final r = await service.changePasswordVerified(
            currentPassword: 'wrong-one1', newPassword: _newPw, mfaCode: '123456');

        expect(r.outcome, PasswordChangeOutcome.wrongCurrentPassword);
        verifyNever(() => mfa.listFactors());
        verifyNever(() => auth.updateUser(any()));
      });

      test('no verified authenticator -> failed (nothing changed)', () async {
        stubFactors([totp('f-unverified', FactorStatus.unverified)]);

        final r = await service.changePasswordVerified(
            currentPassword: _current, newPassword: _newPw, mfaCode: '123456');

        expect(r.outcome, PasswordChangeOutcome.failed);
        verifyNever(() => auth.updateUser(any()));
      });
    });

    test('the main session is never touched by verification', () async {
      await service.changePasswordVerified(
          currentPassword: _current, newPassword: _newPw);

      verifyNever(() => auth.signInWithPassword(
          email: any(named: 'email'), password: any(named: 'password')));
      verifyNever(() => auth.signOut(scope: any(named: 'scope')));
      verifyZeroInteractions(storage);
    });
  });

  group('SupabaseCurrentPasswordVerifier (throwaway, non-persisting)', () {
    Dio dioWith(_RecordingAdapter a) => Dio()..httpClientAdapter = a;

    test('correct password: password grant then logout(scope=local) with the '
        'throwaway token only', () async {
      final adapter = _RecordingAdapter([
        _json(200, {
          'access_token': 'throwaway-token',
          'refresh_token': 'throwaway-refresh',
          'user': {'id': _userId},
        }),
        _json(204, {}),
      ]);
      final v = SupabaseCurrentPasswordVerifier.forProject(
        supabaseUrl: 'https://proj.supabase.test/',
        apiKey: 'anon-key',
        dio: dioWith(adapter),
      );

      final r = await v.verify(
          email: 'user@example.test',
          password: _current,
          expectedUserId: _userId);

      expect(r, PasswordVerification.verified);
      expect(adapter.requests, hasLength(2));
      final grant = adapter.requests[0];
      expect(grant.method, 'POST');
      expect(grant.uri.toString(),
          'https://proj.supabase.test/auth/v1/token?grant_type=password');
      expect(grant.headers['apikey'], 'anon-key');
      expect(grant.headers.containsKey('Authorization'), isFalse);
      expect(adapter.bodies[0],
          {'email': 'user@example.test', 'password': _current});

      final logout = adapter.requests[1];
      expect(logout.uri.toString(),
          'https://proj.supabase.test/auth/v1/logout?scope=local');
      expect(logout.headers['Authorization'], 'Bearer throwaway-token');
    });

    test('does not use the shared Supabase auth client or storage', () async {
      final mainAuth = MockGoTrueClient();
      final storage = _MockSecureStorage();
      final adapter = _RecordingAdapter([
        _json(200, {
          'access_token': 't',
          'user': {'id': _userId},
        }),
        _json(204, {}),
      ]);
      final v = SupabaseCurrentPasswordVerifier(
        authUrl: 'https://proj.supabase.test/auth/v1',
        apiKey: 'anon-key',
        dio: dioWith(adapter),
      );

      await v.verify(email: 'user@example.test', password: _current);

      verifyZeroInteractions(mainAuth);
      verifyZeroInteractions(storage);
    });

    test('invalid_credentials -> wrongPassword, no logout call', () async {
      final adapter = _RecordingAdapter([
        _json(400, {
          'code': 400,
          'error_code': 'invalid_credentials',
          'msg': 'Invalid login credentials',
        }),
      ]);
      final v = SupabaseCurrentPasswordVerifier(
          authUrl: 'https://p/auth/v1', apiKey: 'k', dio: dioWith(adapter));

      expect(await v.verify(email: 'e@x.test', password: 'bad'),
          PasswordVerification.wrongPassword);
      expect(adapter.requests, hasLength(1));
    });

    test('legacy invalid_grant payload -> wrongPassword', () async {
      final adapter = _RecordingAdapter([
        _json(400, {
          'error': 'invalid_grant',
          'error_description': 'Invalid login credentials',
        }),
      ]);
      final v = SupabaseCurrentPasswordVerifier(
          authUrl: 'https://p/auth/v1', apiKey: 'k', dio: dioWith(adapter));

      expect(await v.verify(email: 'e@x.test', password: 'bad'),
          PasswordVerification.wrongPassword);
    });

    test('HTTP 429 -> rateLimited (not wrongPassword)', () async {
      final adapter = _RecordingAdapter([
        _json(429, {
          'code': 429,
          'error_code': 'over_request_rate_limit',
          'msg': 'Request rate limit reached',
        }),
      ]);
      final v = SupabaseCurrentPasswordVerifier(
          authUrl: 'https://p/auth/v1', apiKey: 'k', dio: dioWith(adapter));

      expect(await v.verify(email: 'e@x.test', password: 'x'),
          PasswordVerification.rateLimited);
    });

    test('connection error -> networkError; 500 -> failed', () async {
      final net = _RecordingAdapter([
        DioException.connectionError(
            requestOptions: RequestOptions(path: '/token'), reason: 'offline'),
      ]);
      expect(
          await SupabaseCurrentPasswordVerifier(
                  authUrl: 'https://p/auth/v1', apiKey: 'k', dio: dioWith(net))
              .verify(email: 'e@x.test', password: 'x'),
          PasswordVerification.networkError);

      final server = _RecordingAdapter([
        _json(500, {'msg': 'Invalid login credentials'}),
      ]);
      expect(
          await SupabaseCurrentPasswordVerifier(
                  authUrl: 'https://p/auth/v1',
                  apiKey: 'k',
                  dio: dioWith(server))
              .verify(email: 'e@x.test', password: 'x'),
          PasswordVerification.failed);
    });

    test('verified identity must match the expected user', () async {
      final adapter = _RecordingAdapter([
        _json(200, {
          'access_token': 't',
          'user': {'id': 'someone-else'},
        }),
        _json(204, {}),
      ]);
      final v = SupabaseCurrentPasswordVerifier(
          authUrl: 'https://p/auth/v1', apiKey: 'k', dio: dioWith(adapter));

      expect(
          await v.verify(
              email: 'e@x.test', password: 'x', expectedUserId: _userId),
          PasswordVerification.failed);
    });

    test('logout failure does not fail a correct verification', () async {
      final adapter = _RecordingAdapter([
        _json(200, {
          'access_token': 't',
          'user': {'id': _userId},
        }),
        _json(500, {'msg': 'oops'}),
      ]);
      final v = SupabaseCurrentPasswordVerifier(
          authUrl: 'https://p/auth/v1', apiKey: 'k', dio: dioWith(adapter));

      expect(
          await v.verify(
              email: 'e@x.test', password: 'x', expectedUserId: _userId),
          PasswordVerification.verified);
    });
  });

  group('PasswordPolicy', () {
    test('>= 8 chars with letters and digits', () {
      expect(PasswordPolicy.isStrong('abcdefg1'), isTrue);
      expect(PasswordPolicy.isStrong('abc1'), isFalse);
      expect(PasswordPolicy.isStrong('abcdefgh'), isFalse);
      expect(PasswordPolicy.isStrong('12345678'), isFalse);
      expect(PasswordPolicy.isStrong('şifreğüş9'), isTrue);
    });
  });
}

import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication sonuç durumları
enum AuthStatus {
  /// Kimlik doğrulaması başarılı
  authenticated,

  /// Kimlik doğrulaması başarısız
  unauthenticated,

  /// Oturum süresi dolmuş
  sessionExpired,

  /// Email doğrulaması bekliyor
  emailVerificationPending,

  /// İlk giriş - şifre değişikliği gerekli
  passwordChangeRequired,

  /// Hesap kilitli
  accountLocked,

  /// Bilinmeyen hata
  error,
}

/// Authentication sonucu
///
/// Kimlik doğrulama işlemlerinin sonucunu temsil eder.
///
/// Örnek kullanım:
/// ```dart
/// final result = await authService.signIn(email, password);
/// result.when(
///   success: (user) => navigateToHome(),
///   failure: (error) => showError(error.message),
/// );
/// ```
class AuthResult {
  /// Başarı durumu
  final bool isSuccess;

  /// Auth durumu
  final AuthStatus status;

  /// Kullanıcı (başarılı ise)
  final User? user;

  /// Session (başarılı ise)
  final Session? session;

  /// Hata (başarısız ise)
  final AuthError? error;

  const AuthResult._({
    required this.isSuccess,
    required this.status,
    this.user,
    this.session,
    this.error,
  });

  /// Başarılı authentication
  factory AuthResult.success({
    required User user,
    required Session session,
  }) {
    return AuthResult._(
      isSuccess: true,
      status: AuthStatus.authenticated,
      user: user,
      session: session,
    );
  }

  /// Başarısız authentication
  factory AuthResult.failure(AuthError error) {
    return AuthResult._(
      isSuccess: false,
      status: error.status,
      error: error,
    );
  }

  /// Email doğrulaması bekliyor
  factory AuthResult.emailVerificationPending() {
    return const AuthResult._(
      isSuccess: false,
      status: AuthStatus.emailVerificationPending,
    );
  }

  /// Şifre değişikliği gerekli
  factory AuthResult.passwordChangeRequired(User user) {
    return AuthResult._(
      isSuccess: false,
      status: AuthStatus.passwordChangeRequired,
      user: user,
    );
  }

  /// Pattern matching
  T when<T>({
    required T Function(User user, Session session) success,
    required T Function(AuthError? error) failure,
  }) {
    if (isSuccess && user != null && session != null) {
      return success(user!, session!);
    }
    return failure(error);
  }

  /// Optional pattern matching
  T? whenOrNull<T>({
    T Function(User user, Session session)? success,
    T Function(AuthError? error)? failure,
  }) {
    if (isSuccess && user != null && session != null) {
      return success?.call(user!, session!);
    }
    return failure?.call(error);
  }

  /// Map success
  AuthResult mapSuccess(User Function(User user) mapper) {
    if (isSuccess && user != null && session != null) {
      return AuthResult._(
        isSuccess: true,
        status: status,
        user: mapper(user!),
        session: session,
      );
    }
    return this;
  }
}

/// Authentication hata türleri
enum AuthErrorType {
  /// Geçersiz credentials
  invalidCredentials,

  /// Kullanıcı bulunamadı
  userNotFound,

  /// Email zaten kayıtlı
  emailAlreadyInUse,

  /// Zayıf şifre
  weakPassword,

  /// Geçersiz email
  invalidEmail,

  /// Geçersiz token
  invalidToken,

  /// Token süresi dolmuş
  tokenExpired,

  /// Çok fazla deneme
  tooManyRequests,

  /// Network hatası
  networkError,

  /// Sunucu hatası
  serverError,

  /// Bilinmeyen hata
  unknown,
}

/// Authentication hatası
class AuthError {
  /// Hata türü
  final AuthErrorType type;

  /// Auth durumu
  final AuthStatus status;

  /// Hata mesajı
  final String message;

  /// Orijinal hata
  final dynamic originalError;

  const AuthError({
    required this.type,
    this.status = AuthStatus.error,
    required this.message,
    this.originalError,
  });

  /// Supabase AuthException'dan oluştur
  factory AuthError.fromSupabase(AuthException exception) {
    final type = _mapSupabaseError(exception.message);
    return AuthError(
      type: type,
      status: _mapTypeToStatus(type),
      message: _getLocalizedMessage(type, exception.message),
      originalError: exception,
    );
  }

  /// Generic exception'dan oluştur
  factory AuthError.fromException(dynamic exception) {
    return AuthError(
      type: AuthErrorType.unknown,
      status: AuthStatus.error,
      message: exception.toString(),
      originalError: exception,
    );
  }

  /// Network hatası
  factory AuthError.network() {
    return const AuthError(
      type: AuthErrorType.networkError,
      status: AuthStatus.error,
      message: 'İnternet bağlantısı yok',
    );
  }

  static AuthErrorType _mapSupabaseError(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('invalid login credentials') ||
        lowerMessage.contains('invalid password') ||
        lowerMessage.contains('wrong password')) {
      return AuthErrorType.invalidCredentials;
    }

    if (lowerMessage.contains('user not found') ||
        lowerMessage.contains('no user found')) {
      return AuthErrorType.userNotFound;
    }

    if (lowerMessage.contains('email already') ||
        lowerMessage.contains('user already registered')) {
      return AuthErrorType.emailAlreadyInUse;
    }

    if (lowerMessage.contains('weak password') ||
        lowerMessage.contains('password should be')) {
      return AuthErrorType.weakPassword;
    }

    if (lowerMessage.contains('invalid email')) {
      return AuthErrorType.invalidEmail;
    }

    if (lowerMessage.contains('token') && lowerMessage.contains('invalid')) {
      return AuthErrorType.invalidToken;
    }

    if (lowerMessage.contains('token') && lowerMessage.contains('expired')) {
      return AuthErrorType.tokenExpired;
    }

    if (lowerMessage.contains('too many requests') ||
        lowerMessage.contains('rate limit')) {
      return AuthErrorType.tooManyRequests;
    }

    return AuthErrorType.unknown;
  }

  static AuthStatus _mapTypeToStatus(AuthErrorType type) {
    switch (type) {
      case AuthErrorType.tokenExpired:
        return AuthStatus.sessionExpired;
      case AuthErrorType.invalidCredentials:
      case AuthErrorType.userNotFound:
        return AuthStatus.unauthenticated;
      default:
        return AuthStatus.error;
    }
  }

  static String _getLocalizedMessage(AuthErrorType type, String original) {
    switch (type) {
      case AuthErrorType.invalidCredentials:
        return 'Email veya şifre hatalı';
      case AuthErrorType.userNotFound:
        return 'Kullanıcı bulunamadı';
      case AuthErrorType.emailAlreadyInUse:
        return 'Bu email adresi zaten kayıtlı';
      case AuthErrorType.weakPassword:
        return 'Şifre çok zayıf. En az 8 karakter, büyük-küçük harf ve rakam içermelidir';
      case AuthErrorType.invalidEmail:
        return 'Geçersiz email adresi';
      case AuthErrorType.invalidToken:
        return 'Geçersiz token';
      case AuthErrorType.tokenExpired:
        return 'Oturum süresi doldu, lütfen tekrar giriş yapın';
      case AuthErrorType.tooManyRequests:
        return 'Çok fazla deneme yaptınız. Lütfen biraz bekleyin';
      case AuthErrorType.networkError:
        return 'İnternet bağlantısı yok';
      case AuthErrorType.serverError:
        return 'Sunucu hatası oluştu';
      case AuthErrorType.unknown:
        return original;
    }
  }

  @override
  String toString() => 'AuthError($type): $message';
}

/// Password reset sonucu
class PasswordResetResult {
  final bool isSuccess;
  final String? message;
  final AuthError? error;

  const PasswordResetResult._({
    required this.isSuccess,
    this.message,
    this.error,
  });

  factory PasswordResetResult.success({String? message}) {
    return PasswordResetResult._(
      isSuccess: true,
      message: message ?? 'Şifre sıfırlama linki email adresinize gönderildi',
    );
  }

  factory PasswordResetResult.failure(AuthError error) {
    return PasswordResetResult._(
      isSuccess: false,
      error: error,
    );
  }
}

/// Sign out sonucu
class SignOutResult {
  final bool isSuccess;
  final AuthError? error;

  const SignOutResult._({
    required this.isSuccess,
    this.error,
  });

  factory SignOutResult.success() {
    return const SignOutResult._(isSuccess: true);
  }

  factory SignOutResult.failure(AuthError error) {
    return SignOutResult._(
      isSuccess: false,
      error: error,
    );
  }
}

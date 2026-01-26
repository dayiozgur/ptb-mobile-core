import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'auth_result.dart';
import 'biometric_auth.dart';

/// Authentication durumu
class AuthState {
  /// Kullanıcı
  final User? user;

  /// Session
  final Session? session;

  /// Durum
  final AuthStatus status;

  /// Loading durumu
  final bool isLoading;

  const AuthState({
    this.user,
    this.session,
    this.status = AuthStatus.unauthenticated,
    this.isLoading = false,
  });

  /// Authenticated mi?
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  /// Initial state
  static const initial = AuthState();

  /// Loading state
  AuthState loading() => AuthState(
        user: user,
        session: session,
        status: status,
        isLoading: true,
      );

  /// Copy with
  AuthState copyWith({
    User? user,
    Session? session,
    AuthStatus? status,
    bool? isLoading,
  }) {
    return AuthState(
      user: user ?? this.user,
      session: session ?? this.session,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Authentication Servisi
///
/// Supabase Auth ile entegre kimlik doğrulama servisi.
/// Email/password, OAuth, biyometrik ve session yönetimi sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final authService = AuthService(
///   supabase: Supabase.instance.client,
///   secureStorage: SecureStorage(),
/// );
///
/// // State dinle
/// authService.authStateStream.listen((state) {
///   if (state.isAuthenticated) {
///     navigateToHome();
///   }
/// });
///
/// // Giriş yap
/// final result = await authService.signInWithEmail(
///   email: 'user@example.com',
///   password: 'password123',
/// );
/// ```
class AuthService {
  final SupabaseClient _supabase;
  final SecureStorage _secureStorage;
  final BiometricAuth _biometricAuth;

  // Auth state stream
  final _authStateController = StreamController<AuthState>.broadcast();
  AuthState _currentState = AuthState.initial;

  // Supabase auth state subscription
  StreamSubscription<AuthState>? _authSubscription;

  AuthService({
    required SupabaseClient supabase,
    required SecureStorage secureStorage,
    BiometricAuth? biometricAuth,
  })  : _supabase = supabase,
        _secureStorage = secureStorage,
        _biometricAuth = biometricAuth ?? BiometricAuth() {
    _initAuthListener();
  }

  /// Auth state stream
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Mevcut auth state
  AuthState get currentState => _currentState;

  /// Mevcut kullanıcı
  User? get currentUser => _supabase.auth.currentUser;

  /// Mevcut session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Authenticated mi?
  bool get isAuthenticated => currentUser != null && currentSession != null;

  /// BiometricAuth instance
  BiometricAuth get biometricAuth => _biometricAuth;

  // ============================================
  // INITIALIZATION
  // ============================================

  void _initAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      Logger.debug('Auth state changed: $event');

      switch (event) {
        case AuthChangeEvent.signedIn:
          _updateState(AuthState(
            user: session?.user,
            session: session,
            status: AuthStatus.authenticated,
          ));
          _saveSession(session);
          break;

        case AuthChangeEvent.signedOut:
          _updateState(const AuthState(
            status: AuthStatus.unauthenticated,
          ));
          _clearSession();
          break;

        case AuthChangeEvent.tokenRefreshed:
          _updateState(AuthState(
            user: session?.user,
            session: session,
            status: AuthStatus.authenticated,
          ));
          _saveSession(session);
          break;

        case AuthChangeEvent.userUpdated:
          _updateState(_currentState.copyWith(user: session?.user));
          break;

        case AuthChangeEvent.passwordRecovery:
          // Şifre sıfırlama akışı
          break;

        default:
          break;
      }
    });
  }

  void _updateState(AuthState state) {
    _currentState = state;
    _authStateController.add(state);
  }

  Future<void> _saveSession(Session? session) async {
    if (session != null) {
      await _secureStorage.saveAccessToken(session.accessToken);
      if (session.refreshToken != null) {
        await _secureStorage.saveRefreshToken(session.refreshToken!);
      }
    }
  }

  Future<void> _clearSession() async {
    await _secureStorage.clearAuthData();
  }

  // ============================================
  // EMAIL/PASSWORD AUTH
  // ============================================

  /// Email ile kayıt ol
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
    String? redirectTo,
  }) async {
    try {
      _updateState(_currentState.loading());

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
        emailRedirectTo: redirectTo,
      );

      if (response.user == null) {
        return AuthResult.failure(AuthError(
          type: AuthErrorType.unknown,
          message: 'Kayıt başarısız',
        ));
      }

      // Email doğrulaması gerekiyor mu?
      if (response.session == null) {
        _updateState(const AuthState(
          status: AuthStatus.emailVerificationPending,
        ));
        return AuthResult.emailVerificationPending();
      }

      Logger.info('User signed up: ${response.user!.email}');
      return AuthResult.success(
        user: response.user!,
        session: response.session!,
      );
    } on AuthException catch (e) {
      Logger.error('Sign up failed', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('Sign up error', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError.fromException(e));
    }
  }

  /// Email ile giriş yap
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _updateState(_currentState.loading());

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null || response.session == null) {
        return AuthResult.failure(AuthError(
          type: AuthErrorType.invalidCredentials,
          message: 'Giriş başarısız',
        ));
      }

      Logger.info('User signed in: ${response.user!.email}');
      return AuthResult.success(
        user: response.user!,
        session: response.session!,
      );
    } on AuthException catch (e) {
      Logger.error('Sign in failed', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('Sign in error', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError.fromException(e));
    }
  }

  /// Şifre sıfırlama emaili gönder
  Future<PasswordResetResult> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      Logger.info('Password reset email sent to: $email');
      return PasswordResetResult.success();
    } on AuthException catch (e) {
      Logger.error('Password reset failed', e);
      return PasswordResetResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('Password reset error', e);
      return PasswordResetResult.failure(AuthError.fromException(e));
    }
  }

  /// Şifre güncelle
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        return AuthResult.failure(AuthError(
          type: AuthErrorType.unknown,
          message: 'Şifre güncelleme başarısız',
        ));
      }

      Logger.info('Password updated');
      return AuthResult.success(
        user: response.user!,
        session: currentSession!,
      );
    } on AuthException catch (e) {
      Logger.error('Password update failed', e);
      return AuthResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('Password update error', e);
      return AuthResult.failure(AuthError.fromException(e));
    }
  }

  // ============================================
  // OAUTH AUTH
  // ============================================

  /// OAuth ile giriş yap
  Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    try {
      _updateState(_currentState.loading());

      final response = await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: redirectTo,
        scopes: scopes,
        queryParams: queryParams,
      );

      Logger.info('OAuth sign in initiated: $provider');
      return response;
    } catch (e) {
      Logger.error('OAuth sign in failed', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return false;
    }
  }

  /// Google ile giriş
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    return signInWithOAuth(
      provider: OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  /// Apple ile giriş
  Future<bool> signInWithApple({String? redirectTo}) async {
    return signInWithOAuth(
      provider: OAuthProvider.apple,
      redirectTo: redirectTo,
    );
  }

  // ============================================
  // MAGIC LINK AUTH
  // ============================================

  /// Magic link ile giriş
  Future<bool> signInWithMagicLink({
    required String email,
    String? redirectTo,
  }) async {
    try {
      _updateState(_currentState.loading());

      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectTo,
      );

      Logger.info('Magic link sent to: $email');
      _updateState(const AuthState(status: AuthStatus.emailVerificationPending));
      return true;
    } catch (e) {
      Logger.error('Magic link sign in failed', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return false;
    }
  }

  /// OTP doğrula
  Future<AuthResult> verifyOtp({
    required String email,
    required String token,
    OtpType type = OtpType.magiclink,
  }) async {
    try {
      _updateState(_currentState.loading());

      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: type,
      );

      if (response.user == null || response.session == null) {
        return AuthResult.failure(AuthError(
          type: AuthErrorType.invalidToken,
          message: 'Geçersiz doğrulama kodu',
        ));
      }

      Logger.info('OTP verified: $email');
      return AuthResult.success(
        user: response.user!,
        session: response.session!,
      );
    } on AuthException catch (e) {
      Logger.error('OTP verification failed', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('OTP verification error', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError.fromException(e));
    }
  }

  // ============================================
  // BIOMETRIC AUTH
  // ============================================

  /// Biyometrik authentication kullanılabilir mi?
  Future<bool> isBiometricAvailable() async {
    return _biometricAuth.isAvailable();
  }

  /// Biyometrik ile doğrula
  Future<BiometricResult> authenticateWithBiometric({
    String reason = 'Uygulamaya erişmek için doğrulama yapın',
  }) async {
    return _biometricAuth.authenticate(reason: reason);
  }

  /// Biyometrik girişi etkinleştir
  Future<void> enableBiometricLogin() async {
    await _secureStorage.write(
      key: 'biometric_enabled',
      value: 'true',
    );
    Logger.info('Biometric login enabled');
  }

  /// Biyometrik girişi devre dışı bırak
  Future<void> disableBiometricLogin() async {
    await _secureStorage.delete('biometric_enabled');
    Logger.info('Biometric login disabled');
  }

  /// Biyometrik giriş etkin mi?
  Future<bool> isBiometricLoginEnabled() async {
    final value = await _secureStorage.read('biometric_enabled');
    return value == 'true';
  }

  // ============================================
  // SESSION MANAGEMENT
  // ============================================

  /// Session'ı yenile
  Future<AuthResult> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();

      if (response.user == null || response.session == null) {
        return AuthResult.failure(AuthError(
          type: AuthErrorType.tokenExpired,
          status: AuthStatus.sessionExpired,
          message: 'Session yenilenemedi',
        ));
      }

      Logger.info('Session refreshed');
      return AuthResult.success(
        user: response.user!,
        session: response.session!,
      );
    } on AuthException catch (e) {
      Logger.error('Session refresh failed', e);
      return AuthResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('Session refresh error', e);
      return AuthResult.failure(AuthError.fromException(e));
    }
  }

  /// Stored session'dan giriş yap (auto-login)
  Future<AuthResult> restoreSession() async {
    try {
      _updateState(_currentState.loading());

      // Mevcut session var mı?
      final session = currentSession;
      if (session != null) {
        // Session hala geçerli mi?
        if (!session.isExpired) {
          Logger.info('Session restored');
          return AuthResult.success(
            user: currentUser!,
            session: session,
          );
        }

        // Session expired, refresh dene
        final refreshResult = await refreshSession();
        if (refreshResult.isSuccess) {
          return refreshResult;
        }
      }

      // Stored token'lardan dene
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final response = await _supabase.auth.setSession(refreshToken);
          if (response.user != null && response.session != null) {
            Logger.info('Session restored from stored token');
            return AuthResult.success(
              user: response.user!,
              session: response.session!,
            );
          }
        } catch (e) {
          Logger.warning('Failed to restore session from token', e);
        }
      }

      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError(
        type: AuthErrorType.tokenExpired,
        status: AuthStatus.sessionExpired,
        message: 'Session bulunamadı',
      ));
    } catch (e) {
      Logger.error('Session restore error', e);
      _updateState(const AuthState(status: AuthStatus.unauthenticated));
      return AuthResult.failure(AuthError.fromException(e));
    }
  }

  // ============================================
  // USER MANAGEMENT
  // ============================================

  /// Kullanıcı bilgilerini güncelle
  Future<AuthResult> updateUser({
    String? email,
    String? phone,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          email: email,
          phone: phone,
          data: metadata,
        ),
      );

      if (response.user == null) {
        return AuthResult.failure(AuthError(
          type: AuthErrorType.unknown,
          message: 'Kullanıcı güncelleme başarısız',
        ));
      }

      Logger.info('User updated');
      return AuthResult.success(
        user: response.user!,
        session: currentSession!,
      );
    } on AuthException catch (e) {
      Logger.error('User update failed', e);
      return AuthResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('User update error', e);
      return AuthResult.failure(AuthError.fromException(e));
    }
  }

  /// Email doğrulama emaili tekrar gönder
  Future<bool> resendEmailVerification({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectTo,
      );

      Logger.info('Verification email resent to: $email');
      return true;
    } catch (e) {
      Logger.error('Failed to resend verification email', e);
      return false;
    }
  }

  // ============================================
  // SIGN OUT
  // ============================================

  /// Çıkış yap
  Future<SignOutResult> signOut({SignOutScope scope = SignOutScope.local}) async {
    try {
      await _supabase.auth.signOut(scope: scope);
      await _clearSession();

      Logger.info('User signed out');
      return SignOutResult.success();
    } on AuthException catch (e) {
      Logger.error('Sign out failed', e);
      return SignOutResult.failure(AuthError.fromSupabase(e));
    } catch (e) {
      Logger.error('Sign out error', e);
      return SignOutResult.failure(AuthError.fromException(e));
    }
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _authSubscription?.cancel();
    _authStateController.close();
    Logger.debug('AuthService disposed');
  }
}

/// OAuth Provider extension
extension OAuthProviderExtension on OAuthProvider {
  String get displayName {
    switch (this) {
      case OAuthProvider.google:
        return 'Google';
      case OAuthProvider.apple:
        return 'Apple';
      case OAuthProvider.facebook:
        return 'Facebook';
      case OAuthProvider.twitter:
        return 'Twitter';
      case OAuthProvider.github:
        return 'GitHub';
      case OAuthProvider.gitlab:
        return 'GitLab';
      case OAuthProvider.discord:
        return 'Discord';
      case OAuthProvider.slack:
        return 'Slack';
      default:
        return name;
    }
  }

  String get iconAsset {
    switch (this) {
      case OAuthProvider.google:
        return 'assets/icons/google.svg';
      case OAuthProvider.apple:
        return 'assets/icons/apple.svg';
      case OAuthProvider.facebook:
        return 'assets/icons/facebook.svg';
      case OAuthProvider.twitter:
        return 'assets/icons/twitter.svg';
      case OAuthProvider.github:
        return 'assets/icons/github.svg';
      default:
        return 'assets/icons/oauth.svg';
    }
  }
}

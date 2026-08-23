import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// **Biyometrik uygulama kilidi** — biyometrik giriş etkinse (Ayarlar toggle'ı)
/// ve kullanıcı oturum açmışsa, uygulama açılışında ve arka plandan dönüşte
/// Face ID / Touch ID doğrulaması ister; doğrulanana kadar içeriği gizler.
///
/// `MaterialApp.router`'ın `builder`'ına sarılır → tüm rotaların üstünde çalışır.
/// Ayar `AuthService.isBiometricLoginEnabled()` (secure storage) her yaşam-döngüsü
/// değişiminde taze okunur → Ayarlar'da açınca app-restart gerekmez.
class BiometricLockGate extends StatefulWidget {
  final Widget child;

  /// Kilit ekranı vurgu rengi (app markası). Verilmezse tema birincil rengi.
  final Color? brandColor;

  const BiometricLockGate({super.key, required this.child, this.brandColor});

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold-start: etkin + oturum varsa kilitle ve doğrulamayı başlat.
    WidgetsBinding.instance.addPostFrameCallback((_) => _lockIfEnabled(prompt: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _loggedIn => authService.currentUser != null;

  Future<void> _lockIfEnabled({required bool prompt}) async {
    final enabled = await authService.isBiometricLoginEnabled();
    if (!mounted) return;
    if (enabled && _loggedIn) {
      if (!_locked) setState(() => _locked = true);
      if (prompt) _authenticate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Arka plana giderken kilitle (ayarı taze oku).
      _lockIfEnabled(prompt: false);
    } else if (state == AppLifecycleState.resumed) {
      if (_locked && !_checking) _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_checking) return;
    setState(() => _checking = true);
    BiometricResult result;
    try {
      result = await authService.authenticateWithBiometric(
        reason: 'Uygulamaya erişmek için kimliğinizi doğrulayın',
      );
    } catch (_) {
      result = BiometricResult.failure(status: BiometricStatus.unknown);
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (result.isSuccess) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockOverlay(
              brandColor: widget.brandColor ?? Theme.of(context).primaryColor,
              busy: _checking,
              onUnlock: _authenticate,
            ),
          ),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  final Color brandColor;
  final bool busy;
  final VoidCallback onUnlock;

  const _LockOverlay({
    required this.brandColor,
    required this.busy,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    // Opak tam-ekran → altındaki içerik görünmez (güvenlik).
    return Material(
      color: brandColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Uygulama Kilitli',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Devam etmek için kimliğinizi doğrulayın',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: FilledButton.tonalIcon(
                  onPressed: busy ? null : onUnlock,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: Text(busy ? 'Doğrulanıyor…' : 'Kilidi Aç'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

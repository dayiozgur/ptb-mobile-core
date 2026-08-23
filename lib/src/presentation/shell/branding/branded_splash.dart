import 'dart:async';

import 'package:flutter/material.dart';

/// **Markalı açılış ekranı (splash)** — uygulama açılışında app'in kendi
/// renginde tam-ekran arka plan + BEYAZ Protoolbag logosu + slogan gösterir,
/// kısa bir süre sonra alttaki içeriğe (uygulama) yumuşakça geçer.
///
/// `MaterialApp.router`'ın `builder`'ına sarılır. Logo çekirdek paketten gelir
/// (`assets/brand/ptb_logo.png`, `package: protoolbag_core`) ve `BlendMode.srcIn`
/// ile beyaza boyanır → tek asset tüm app renklerinde beyaz görünür.
class BrandedSplash extends StatefulWidget {
  final Widget child;

  /// App marka rengi (tam-ekran arka plan).
  final Color color;

  /// Uygulama adı (logo altında, opsiyonel).
  final String? appName;

  /// Slogan / alt başlık (opsiyonel).
  final String? slogan;

  /// Splash süresi (fade dahil).
  final Duration duration;

  const BrandedSplash({
    super.key,
    required this.child,
    required this.color,
    this.appName,
    this.slogan,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<BrandedSplash> createState() => _BrandedSplashState();
}

class _BrandedSplashState extends State<BrandedSplash>
    with SingleTickerProviderStateMixin {
  bool _show = true;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    Timer(widget.duration, () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedOpacity(
          opacity: _show ? 1 : 0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !_show,
            child: _show || _c.isAnimating
                ? _splash(context)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _splash(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.86, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    return Material(
      color: widget.color,
      child: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _logo(),
                if ((widget.appName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(
                    widget.appName!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                if ((widget.slogan ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      widget.slogan!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    // Tek renkli asset'i beyaza boya (srcIn) → her app renginde beyaz logo.
    // Logo geniş bir wordmark (397×92) — genişliğe göre ölçekle, en-boy koru.
    return Image.asset(
      'assets/brand/ptb_logo.png',
      package: 'protoolbag_core',
      width: 240,
      fit: BoxFit.contain,
      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, __, ___) => const Text(
        'protoolbag',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

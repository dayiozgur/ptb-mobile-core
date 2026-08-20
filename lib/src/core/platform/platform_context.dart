import 'dart:async';

import 'package:flutter/foundation.dart';

import '../menu/mobile_menu_service.dart';
import '../utils/logger.dart';

/// Aktif platform context'i (Windows-OS "hangi uygulama açık" durumu).
///
/// Tek app + in-app platform switch modeli: aktif `platformId` MenuService'i
/// besler; değiştiğinde shell menüyü yeniden kurar. Varsayılan platform PMS.
///
/// [ChangeNotifier] + [Stream] — hem Riverpod/`AnimatedBuilder` hem de
/// stream tabanlı dinleyiciler kullanabilsin.
class PlatformContext extends ChangeNotifier {
  /// Varsayılan (ve şu an tek tam-kurulu) platform: PMS.
  static const String defaultPlatformId = MobileMenuService.pmsPlatformId;

  String _activePlatformId;
  String? _activePlatformCode;

  final _controller = StreamController<String>.broadcast();

  PlatformContext({String? initialPlatformId, String? initialPlatformCode})
      : _activePlatformId = initialPlatformId ?? defaultPlatformId,
        _activePlatformCode = initialPlatformCode ?? 'PMS';

  /// Aktif platform id (MenuService platform_id kaynağı).
  String get activePlatformId => _activePlatformId;

  /// Aktif platform kodu (biliniyorsa: PMS/CRM/...).
  String? get activePlatformCode => _activePlatformCode;

  /// Aktif platform değişiklikleri stream'i (yeni platformId yayınlar).
  Stream<String> get platformStream => _controller.stream;

  /// Aktif platformu değiştir → dinleyiciler (shell) menüyü rebuild eder.
  void setActivePlatform(String platformId, {String? code}) {
    if (platformId == _activePlatformId && code == _activePlatformCode) return;
    _activePlatformId = platformId;
    if (code != null) _activePlatformCode = code;
    Logger.info('Active platform → $platformId (${_activePlatformCode ?? '?'})');
    _controller.add(platformId);
    notifyListeners();
  }

  /// PMS'e (varsayılan) geri dön.
  void resetToDefault() =>
      setActivePlatform(defaultPlatformId, code: 'PMS');

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

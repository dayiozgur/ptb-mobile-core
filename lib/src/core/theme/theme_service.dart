import 'dart:async';

import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter/material.dart' as material show ThemeMode;
import 'package:flutter/scheduler.dart';

import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'app_theme.dart';

/// Tema modu
enum AppThemeMode {
  /// Sistem ayarlarını takip et
  system('system', 'Sistem'),

  /// Her zaman açık tema
  light('light', 'Açık'),

  /// Her zaman koyu tema
  dark('dark', 'Koyu');

  final String value;
  final String label;
  const AppThemeMode(this.value, this.label);

  static AppThemeMode fromString(String? value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AppThemeMode.system,
    );
  }

  /// Flutter ThemeMode'a dönüştür
  material.ThemeMode toFlutter() {
    switch (this) {
      case AppThemeMode.system:
        return material.ThemeMode.system;
      case AppThemeMode.light:
        return material.ThemeMode.light;
      case AppThemeMode.dark:
        return material.ThemeMode.dark;
    }
  }
}

/// Tema ayarları
class ThemeSettings {
  final AppThemeMode mode;
  final Color? customPrimaryColor;
  final Color? customAccentColor;
  final bool useHighContrast;
  final double? fontScale;

  const ThemeSettings({
    this.mode = AppThemeMode.system,
    this.customPrimaryColor,
    this.customAccentColor,
    this.useHighContrast = false,
    this.fontScale,
  });

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    return ThemeSettings(
      mode: AppThemeMode.fromString(json['mode'] as String?),
      customPrimaryColor: json['custom_primary_color'] != null
          ? Color(json['custom_primary_color'] as int)
          : null,
      customAccentColor: json['custom_accent_color'] != null
          ? Color(json['custom_accent_color'] as int)
          : null,
      useHighContrast: json['use_high_contrast'] as bool? ?? false,
      fontScale: (json['font_scale'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'custom_primary_color': customPrimaryColor?.value,
        'custom_accent_color': customAccentColor?.value,
        'use_high_contrast': useHighContrast,
        'font_scale': fontScale,
      };

  ThemeSettings copyWith({
    AppThemeMode? mode,
    Color? customPrimaryColor,
    Color? customAccentColor,
    bool? useHighContrast,
    double? fontScale,
  }) {
    return ThemeSettings(
      mode: mode ?? this.mode,
      customPrimaryColor: customPrimaryColor ?? this.customPrimaryColor,
      customAccentColor: customAccentColor ?? this.customAccentColor,
      useHighContrast: useHighContrast ?? this.useHighContrast,
      fontScale: fontScale ?? this.fontScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSettings &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          customPrimaryColor == other.customPrimaryColor &&
          customAccentColor == other.customAccentColor &&
          useHighContrast == other.useHighContrast &&
          fontScale == other.fontScale;

  @override
  int get hashCode =>
      mode.hashCode ^
      customPrimaryColor.hashCode ^
      customAccentColor.hashCode ^
      useHighContrast.hashCode ^
      fontScale.hashCode;
}

/// Tema Servisi
///
/// Tema tercihlerini yönetir ve kalıcı olarak saklar.
/// Sistem teması değişikliklerini dinler.
///
/// Örnek kullanım:
/// ```dart
/// final themeService = ThemeService(storage: SecureStorage());
/// await themeService.initialize();
///
/// // Tema modunu değiştir
/// await themeService.setThemeMode(AppThemeMode.dark);
///
/// // Tema değişikliklerini dinle
/// themeService.settingsStream.listen((settings) {
///   // Tema güncellendi
/// });
/// ```
class ThemeService {
  final SecureStorage _storage;

  // State
  ThemeSettings _settings = const ThemeSettings();
  bool _isInitialized = false;

  // Stream controllers
  final _settingsController = StreamController<ThemeSettings>.broadcast();

  // Storage keys
  static const String _settingsKey = 'theme_settings';

  ThemeService({
    required SecureStorage storage,
  }) : _storage = storage;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut tema ayarları
  ThemeSettings get settings => _settings;

  /// Mevcut tema modu
  AppThemeMode get themeMode => _settings.mode;

  /// Koyu tema mı?
  bool get isDarkMode {
    if (_settings.mode == AppThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _settings.mode == AppThemeMode.dark;
  }

  /// Açık tema mı?
  bool get isLightMode => !isDarkMode;

  /// Tema ayarları stream'i
  Stream<ThemeSettings> get settingsStream => _settingsController.stream;

  /// Başlatıldı mı?
  bool get isInitialized => _isInitialized;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Kayıtlı ayarları yükle
      final savedSettings = await _storage.read(_settingsKey);
      if (savedSettings != null) {
        try {
          final json = _parseJson(savedSettings);
          _settings = ThemeSettings.fromJson(json);
        } catch (e) {
          Logger.warning('Failed to parse theme settings, using defaults');
        }
      }

      _isInitialized = true;
      Logger.info('ThemeService initialized with mode: ${_settings.mode.label}');
    } catch (e) {
      Logger.error('Failed to initialize ThemeService', e);
      _isInitialized = true; // Default değerlerle devam et
    }
  }

  // ============================================
  // THEME MODE
  // ============================================

  /// Tema modunu ayarla
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_settings.mode == mode) return;

    _settings = _settings.copyWith(mode: mode);
    await _saveSettings();
    _settingsController.add(_settings);

    Logger.info('Theme mode changed to: ${mode.label}');
  }

  /// Temayı değiştir (toggle)
  Future<void> toggleTheme() async {
    final newMode = switch (_settings.mode) {
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
      AppThemeMode.system => AppThemeMode.light,
    };
    await setThemeMode(newMode);
  }

  /// Light/Dark arasında geçiş (system hariç)
  Future<void> toggleLightDark() async {
    final newMode = isDarkMode ? AppThemeMode.light : AppThemeMode.dark;
    await setThemeMode(newMode);
  }

  // ============================================
  // CUSTOM COLORS
  // ============================================

  /// Özel primary renk ayarla
  Future<void> setCustomPrimaryColor(Color? color) async {
    _settings = _settings.copyWith(customPrimaryColor: color);
    await _saveSettings();
    _settingsController.add(_settings);

    Logger.info('Custom primary color changed');
  }

  /// Özel accent renk ayarla
  Future<void> setCustomAccentColor(Color? color) async {
    _settings = _settings.copyWith(customAccentColor: color);
    await _saveSettings();
    _settingsController.add(_settings);

    Logger.info('Custom accent color changed');
  }

  // ============================================
  // ACCESSIBILITY
  // ============================================

  /// Yüksek kontrast modunu ayarla
  Future<void> setHighContrast(bool enabled) async {
    if (_settings.useHighContrast == enabled) return;

    _settings = _settings.copyWith(useHighContrast: enabled);
    await _saveSettings();
    _settingsController.add(_settings);

    Logger.info('High contrast mode: ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Font ölçeğini ayarla
  Future<void> setFontScale(double? scale) async {
    _settings = _settings.copyWith(fontScale: scale);
    await _saveSettings();
    _settingsController.add(_settings);

    Logger.info('Font scale changed to: ${scale ?? 'default'}');
  }

  // ============================================
  // THEME DATA BUILDERS
  // ============================================

  /// Mevcut ayarlara göre light tema al
  ThemeData get lightTheme {
    if (_settings.customPrimaryColor != null ||
        _settings.customAccentColor != null) {
      return AppTheme.customLight(
        primaryColor: _settings.customPrimaryColor,
        accentColor: _settings.customAccentColor,
      );
    }
    return AppTheme.light;
  }

  /// Mevcut ayarlara göre dark tema al
  ThemeData get darkTheme {
    if (_settings.customPrimaryColor != null ||
        _settings.customAccentColor != null) {
      return AppTheme.customDark(
        primaryColor: _settings.customPrimaryColor,
        accentColor: _settings.customAccentColor,
      );
    }
    return AppTheme.dark;
  }

  /// Mevcut brightness'a göre aktif tema
  ThemeData get currentTheme => isDarkMode ? darkTheme : lightTheme;

  /// Flutter ThemeMode al
  material.ThemeMode get flutterThemeMode => _settings.mode.toFlutter();

  // ============================================
  // RESET
  // ============================================

  /// Tüm ayarları sıfırla
  Future<void> reset() async {
    _settings = const ThemeSettings();
    await _storage.delete(_settingsKey);
    _settingsController.add(_settings);

    Logger.info('Theme settings reset to defaults');
  }

  // ============================================
  // PRIVATE HELPERS
  // ============================================

  Future<void> _saveSettings() async {
    try {
      await _storage.write(key: _settingsKey, value: _encodeJson(_settings.toJson()));
    } catch (e) {
      Logger.error('Failed to save theme settings', e);
    }
  }

  Map<String, dynamic> _parseJson(String json) {
    // Simple JSON parsing
    final result = <String, dynamic>{};
    final clean = json.trim();

    if (!clean.startsWith('{') || !clean.endsWith('}')) {
      return result;
    }

    final content = clean.substring(1, clean.length - 1);
    final pairs = content.split(',');

    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex == -1) continue;

      final key = pair.substring(0, colonIndex).trim().replaceAll('"', '');
      var value = pair.substring(colonIndex + 1).trim();

      // Parse value
      if (value == 'null') {
        result[key] = null;
      } else if (value == 'true') {
        result[key] = true;
      } else if (value == 'false') {
        result[key] = false;
      } else if (value.startsWith('"') && value.endsWith('"')) {
        result[key] = value.substring(1, value.length - 1);
      } else if (value.contains('.')) {
        result[key] = double.tryParse(value);
      } else {
        result[key] = int.tryParse(value);
      }
    }

    return result;
  }

  String _encodeJson(Map<String, dynamic> json) {
    final pairs = json.entries.map((e) {
      final value = e.value;
      final valueStr = switch (value) {
        null => 'null',
        bool b => b.toString(),
        num n => n.toString(),
        String s => '"$s"',
        _ => '"$value"',
      };
      return '"${e.key}":$valueStr';
    });
    return '{${pairs.join(',')}}';
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _settingsController.close();
    Logger.debug('ThemeService disposed');
  }
}

/// Tema değişikliklerini dinleyen widget
class ThemeBuilder extends StatefulWidget {
  final ThemeService themeService;
  final Widget Function(BuildContext context, ThemeSettings settings) builder;

  const ThemeBuilder({
    super.key,
    required this.themeService,
    required this.builder,
  });

  @override
  State<ThemeBuilder> createState() => _ThemeBuilderState();
}

class _ThemeBuilderState extends State<ThemeBuilder> {
  late StreamSubscription<ThemeSettings> _subscription;
  late ThemeSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.themeService.settings;
    _subscription = widget.themeService.settingsStream.listen((settings) {
      if (mounted) {
        setState(() {
          _settings = settings;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _settings);
  }
}

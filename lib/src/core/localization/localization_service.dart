import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../storage/secure_storage.dart';
import '../utils/logger.dart';
import 'app_localizations.dart';

/// Desteklenen diller
enum AppLocale {
  /// Türkçe
  turkish('tr', 'Türkçe', 'TR'),

  /// İngilizce
  english('en', 'English', 'US'),

  /// Almanca
  german('de', 'Deutsch', 'DE');

  final String languageCode;
  final String displayName;
  final String countryCode;

  const AppLocale(this.languageCode, this.displayName, this.countryCode);

  /// Flutter Locale'e dönüştür
  Locale toLocale() => Locale(languageCode, countryCode);

  /// Dil kodundan bul
  static AppLocale fromLanguageCode(String? code) {
    if (code == null) return AppLocale.turkish;
    return AppLocale.values.firstWhere(
      (e) => e.languageCode == code,
      orElse: () => AppLocale.turkish,
    );
  }

  /// Locale'den bul
  static AppLocale fromLocale(Locale? locale) {
    if (locale == null) return AppLocale.turkish;
    return fromLanguageCode(locale.languageCode);
  }
}

/// Lokalizasyon Servisi
///
/// Dil tercihlerini yönetir ve çevirileri sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final localizationService = LocalizationService(storage: SecureStorage());
/// await localizationService.initialize();
///
/// // Dili değiştir
/// await localizationService.setLocale(AppLocale.english);
///
/// // Çeviri al
/// final text = localizationService.translate('common.save');
/// ```
class LocalizationService {
  final SecureStorage _storage;

  // State
  AppLocale _currentLocale = AppLocale.turkish;
  Map<String, String> _translations = {};
  bool _isInitialized = false;

  // Stream controllers
  final _localeController = StreamController<AppLocale>.broadcast();

  // Storage keys
  static const String _localeKey = 'app_locale';

  LocalizationService({
    required SecureStorage storage,
  }) : _storage = storage;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut dil
  AppLocale get currentLocale => _currentLocale;

  /// Mevcut Flutter Locale
  Locale get locale => _currentLocale.toLocale();

  /// Dil değişikliği stream'i
  Stream<AppLocale> get localeStream => _localeController.stream;

  /// Başlatıldı mı?
  bool get isInitialized => _isInitialized;

  /// Desteklenen diller
  List<AppLocale> get supportedLocales => AppLocale.values;

  /// Desteklenen Flutter Locale'ler
  List<Locale> get supportedFlutterLocales =>
      AppLocale.values.map((e) => e.toLocale()).toList();

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Servisi başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Kayıtlı dili yükle
      final savedLocale = await _storage.read(_localeKey);
      if (savedLocale != null) {
        _currentLocale = AppLocale.fromLanguageCode(savedLocale);
      } else {
        // Sistem dilini kontrol et
        final systemLocale = PlatformDispatcher.instance.locale;
        _currentLocale = AppLocale.fromLocale(systemLocale);
      }

      // Çevirileri yükle
      await _loadTranslations(_currentLocale);

      _isInitialized = true;
      Logger.info(
          'LocalizationService initialized with locale: ${_currentLocale.displayName}');
    } catch (e) {
      Logger.error('Failed to initialize LocalizationService', e);
      // Default Türkçe ile devam et
      await _loadTranslations(AppLocale.turkish);
      _isInitialized = true;
    }
  }

  // ============================================
  // LOCALE MANAGEMENT
  // ============================================

  /// Dili değiştir
  Future<void> setLocale(AppLocale locale) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    await _loadTranslations(locale);
    await _storage.write(key: _localeKey, value: locale.languageCode);
    _localeController.add(locale);

    Logger.info('Locale changed to: ${locale.displayName}');
  }

  /// Sistem diline ayarla
  Future<void> useSystemLocale() async {
    final systemLocale = PlatformDispatcher.instance.locale;
    final appLocale = AppLocale.fromLocale(systemLocale);
    await setLocale(appLocale);
  }

  /// Çevirileri yükle
  Future<void> _loadTranslations(AppLocale locale) async {
    _translations = AppLocalizations.getTranslations(locale);
    Logger.debug('Loaded ${_translations.length} translations for ${locale.languageCode}');
  }

  // ============================================
  // TRANSLATIONS
  // ============================================

  /// Çeviri al
  String translate(String key, {Map<String, dynamic>? params}) {
    var text = _translations[key] ?? key;

    // Parametreleri değiştir
    if (params != null) {
      params.forEach((paramKey, value) {
        text = text.replaceAll('{$paramKey}', value.toString());
      });
    }

    return text;
  }

  /// Kısaltma - çeviri al
  String tr(String key, {Map<String, dynamic>? params}) =>
      translate(key, params: params);

  /// Çoğul çeviri
  String plural(String key, int count, {Map<String, dynamic>? params}) {
    final pluralKey = count == 1 ? '${key}_one' : '${key}_other';
    final finalParams = {
      ...?params,
      'count': count,
    };
    return translate(
      _translations.containsKey(pluralKey) ? pluralKey : key,
      params: finalParams,
    );
  }

  // ============================================
  // FORMATTERS
  // ============================================

  /// Tarih formatla
  String formatDate(DateTime date, {String? pattern}) {
    // Basit tarih formatı
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    switch (_currentLocale) {
      case AppLocale.turkish:
        return '$day.$month.$year';
      case AppLocale.english:
        return '$month/$day/$year';
      case AppLocale.german:
        return '$day.$month.$year';
    }
  }

  /// Saat formatla
  String formatTime(DateTime time, {bool use24Hour = true}) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');

    if (use24Hour) {
      return '${hour.toString().padLeft(2, '0')}:$minute';
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }

  /// Sayı formatla
  String formatNumber(num number, {int decimals = 0}) {
    final formatted = number.toStringAsFixed(decimals);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    // Binlik ayırıcı ekle
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(_currentLocale == AppLocale.english ? ',' : '.');
      }
      buffer.write(intPart[i]);
    }

    if (decPart.isNotEmpty) {
      buffer.write(_currentLocale == AppLocale.english ? '.' : ',');
      buffer.write(decPart);
    }

    return buffer.toString();
  }

  /// Para birimi formatla
  String formatCurrency(num amount, {String? symbol, int decimals = 2}) {
    final formatted = formatNumber(amount, decimals: decimals);
    final currencySymbol = symbol ?? _getDefaultCurrencySymbol();

    switch (_currentLocale) {
      case AppLocale.turkish:
        return '$formatted $currencySymbol';
      case AppLocale.english:
        return '$currencySymbol$formatted';
      case AppLocale.german:
        return '$formatted $currencySymbol';
    }
  }

  String _getDefaultCurrencySymbol() {
    switch (_currentLocale) {
      case AppLocale.turkish:
        return '₺';
      case AppLocale.english:
        return '\$';
      case AppLocale.german:
        return '€';
    }
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _localeController.close();
    Logger.debug('LocalizationService disposed');
  }
}

/// Lokalizasyon değişikliklerini dinleyen widget
class LocalizationBuilder extends StatefulWidget {
  final LocalizationService localizationService;
  final Widget Function(BuildContext context, AppLocale locale) builder;

  const LocalizationBuilder({
    super.key,
    required this.localizationService,
    required this.builder,
  });

  @override
  State<LocalizationBuilder> createState() => _LocalizationBuilderState();
}

class _LocalizationBuilderState extends State<LocalizationBuilder> {
  late StreamSubscription<AppLocale> _subscription;
  late AppLocale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.localizationService.currentLocale;
    _subscription = widget.localizationService.localeStream.listen((locale) {
      if (mounted) {
        setState(() {
          _locale = locale;
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
    return widget.builder(context, _locale);
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
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
  german('de', 'Deutsch', 'DE'),

  /// İtalyanca
  italian('it', 'Italiano', 'IT');

  final String languageCode;
  final String displayName;
  final String countryCode;

  const AppLocale(this.languageCode, this.displayName, this.countryCode);

  /// Flutter Locale'e dönüştür
  Locale toLocale() => Locale(languageCode, countryCode);

  /// Web `keywords` tablosundaki `language_id` (canlı DB — tek doğruluk kaynağı).
  ///
  /// Bu UUID'ler web portalıyla aynı DB'yi paylaşır; değiştirmeyin.
  String get languageId {
    switch (this) {
      case AppLocale.turkish:
        return 'fc6e12d2-73b1-4c19-a465-ffdd1a785715';
      case AppLocale.english:
        return '198b2bf7-c859-4cc5-8a26-a1367cdd28ef';
      case AppLocale.german:
        return '44929d49-5cf2-4ba9-b325-2166d250dabc';
      case AppLocale.italian:
        return '009377a3-faee-4c5e-ba26-ff1e6953c506';
    }
  }

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

  /// DB `keywords` tablosuna erişim (opsiyonel — null ise sadece statik map).
  final SupabaseClient? _supabase;

  /// DB çevirilerini 1 saat TTL ile önbelleğe alır (web IDB 1h aynası).
  final CacheManager? _cacheManager;

  // State
  AppLocale _currentLocale = AppLocale.turkish;

  /// Statik fallback map (offline / DB yoksa). `app_localizations.dart`.
  Map<String, String> _translations = {};

  /// Canlı DB `keywords` map'i (cache'den veya ağdan). Statiğe ÜSTÜN gelir,
  /// böylece mobil bir daha sessizce drift edemez.
  Map<String, String> _dbTranslations = {};

  bool _isInitialized = false;

  /// Aynı locale için eşzamanlı ağ yenilemesini engeller.
  Future<void>? _refreshInFlight;

  // Stream controllers
  final _localeController = StreamController<AppLocale>.broadcast();

  // Storage keys
  static const String _localeKey = 'app_locale';

  /// DB keyword cache önekı (locale koduna göre): `keywords_i18n_tr` vb.
  static const String _dbCachePrefix = 'keywords_i18n_';

  /// DB keyword cache TTL — web'in IDB 1 saatlik cache'ini yansıtır.
  static const Duration _dbCacheTtl = Duration(hours: 1);

  /// Supabase varsayılan satır limiti 1000; sayfa başına çekilen satır.
  static const int _pageSize = 1000;

  /// Sonsuz döngü koruması (tr-TR ~19.5k satır → ~20 sayfa).
  static const int _maxRows = 40000;

  LocalizationService({
    required SecureStorage storage,
    SupabaseClient? supabase,
    CacheManager? cacheManager,
  })  : _storage = storage,
        _supabase = supabase,
        _cacheManager = cacheManager;

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
        // Türk pazarı — web (LOCALE_ID=tr-TR pinli) ile tutarlı: kayıtlı bir dil
        // tercihi yoksa uygulama VARSAYILAN OLARAK TÜRKÇE açılır (dil seçici
        // gelene kadar). Cihazın sistem dili İngilizce olsa bile Türkçe başlar;
        // kullanıcı ayarlardan değiştirebilir (setLocale tercihi kaydeder).
        _currentLocale = AppLocale.turkish;
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

  /// Çevirileri yükle.
  ///
  /// Sıra (soğuk-başlangıçta ağ beklemez):
  /// 1. Statik map ile anında boya (fallback).
  /// 2. Cache'deki DB kopyasını (varsa) yükle → hemen kullanılır.
  /// 3. Arka planda DB'den yenile, gelince swap-in + UI'ı yeniden çiz.
  Future<void> _loadTranslations(AppLocale locale) async {
    // 1) Statik fallback — her zaman mevcut, asla null.
    _translations = AppLocalizations.getTranslations(locale);
    Logger.debug(
        'Loaded ${_translations.length} static translations for ${locale.languageCode}');

    // 2) Cache'deki DB kopyası (yerel Hive — hızlı, ağ yok).
    _dbTranslations = await _loadDbFromCache(locale);
    if (_dbTranslations.isNotEmpty) {
      Logger.debug(
          'Loaded ${_dbTranslations.length} cached DB keywords for ${locale.languageCode}');
    }

    // 3) Arka planda DB yenilemesi (fire-and-forget; başlatmayı bloklamaz).
    unawaited(_refreshFromDb(locale));
  }

  /// Cache'deki DB keyword kopyasını oku (TTL dolmuşsa boş döner).
  Future<Map<String, String>> _loadDbFromCache(AppLocale locale) async {
    final cache = _cacheManager;
    if (cache == null) return {};
    try {
      final raw =
          await cache.get<Map<String, dynamic>>('$_dbCachePrefix${locale.languageCode}');
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    } catch (e) {
      Logger.warning('DB keyword cache read failed for ${locale.languageCode}', e);
      return {};
    }
  }

  /// DB `keywords` tablosundan güncel çevirileri çek, swap-in yap ve cache'le.
  ///
  /// Ağ hatasında sessizce cache/statik ile devam eder (asla çökmez).
  Future<void> _refreshFromDb(AppLocale locale) async {
    final supabase = _supabase;
    if (supabase == null) return;

    // Aynı anda tek yenileme.
    if (_refreshInFlight != null) return;

    final completer = Completer<void>();
    _refreshInFlight = completer.future;
    try {
      final fetched = await _fetchKeywordsFromDb(supabase, locale);
      if (fetched.isEmpty) {
        Logger.debug('DB keyword fetch returned no rows for ${locale.languageCode}');
        return;
      }

      // Locale bu arada değişmiş olabilir — yalnızca hâlâ geçerliyse uygula.
      if (locale == _currentLocale) {
        _dbTranslations = fetched;
        // Değişikliği dinleyicilere bildir → LocalizationBuilder yeniden çizer.
        if (!_localeController.isClosed) {
          _localeController.add(_currentLocale);
        }
      }

      // Bir sonraki soğuk-başlangıç için cache'le.
      await _cacheManager?.set(
        '$_dbCachePrefix${locale.languageCode}',
        fetched,
        ttl: _dbCacheTtl,
      );
      Logger.info(
          'Refreshed ${fetched.length} DB keywords for ${locale.languageCode}');
    } catch (e) {
      // Sessizce statik/cache fallback ile devam.
      Logger.warning('DB keyword refresh failed for ${locale.languageCode}', e);
    } finally {
      _refreshInFlight = null;
      completer.complete();
    }
  }

  /// `keywords` tablosundan sayfalı olarak tüm satırları çek.
  ///
  /// Okuma önceliği (web ile aynı): `defaultvalue || shortvalue || longvalue`.
  Future<Map<String, String>> _fetchKeywordsFromDb(
    SupabaseClient supabase,
    AppLocale locale,
  ) async {
    final result = <String, String>{};
    var offset = 0;

    while (offset < _maxRows) {
      final rows = await supabase
          .from('keywords')
          .select('key, defaultvalue, shortvalue, longvalue')
          .eq('language_id', locale.languageId)
          .eq('active', true)
          // STABİL sıralama ŞART: `.order` olmadan `.range` sayfalaması satır
          // atlar/tekrarlar (PostgREST sıra garantisi yok) → rastgele key'ler ham
          // görünür. `id` benzersiz+stabil; tüm aktif key'ler güvenilir çekilir.
          .order('id', ascending: true)
          .range(offset, offset + _pageSize - 1);

      final list = rows as List<dynamic>;
      for (final row in list) {
        final map = row as Map<String, dynamic>;
        final key = map['key'] as String?;
        if (key == null || key.isEmpty) continue;
        final value = _pickValue(map);
        if (value == null) continue;
        result[key] = value;
      }

      if (list.length < _pageSize) break; // son sayfa
      offset += _pageSize;
    }

    return result;
  }

  /// Web okuma önceliği: `defaultvalue || shortvalue || longvalue` (boş atlanır).
  String? _pickValue(Map<String, dynamic> row) {
    for (final col in const ['defaultvalue', 'shortvalue', 'longvalue']) {
      final v = row[col];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  // ============================================
  // TRANSLATIONS
  // ============================================

  /// Çeviri al.
  ///
  /// Çözüm sırası: DB keyword (cache/ağ) → statik fallback → anahtarın kendisi.
  /// DB varsa kazanır (mobil bir daha sessizce drift etmez). Asla null döndürmez;
  /// yükleme bitmeden çağrılırsa cache/statik/anahtar ile güvenli çalışır.
  String translate(String key, {Map<String, dynamic>? params}) {
    var text = _dbTranslations[key] ?? _translations[key] ?? key;

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
    final hasPlural = _dbTranslations.containsKey(pluralKey) ||
        _translations.containsKey(pluralKey);
    return translate(
      hasPlural ? pluralKey : key,
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
      case AppLocale.italian:
        return '$day/$month/$year';
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
      case AppLocale.italian:
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
      case AppLocale.italian:
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

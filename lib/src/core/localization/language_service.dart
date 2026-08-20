import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/platform_context.dart';
import '../utils/logger.dart';
import 'localization_service.dart';

/// Bir dil seçeneği — picker satırının veri modeli.
///
/// Web portalıyla aynı sözleşme: [code] = `languages.code` (örn. 'tr-TR'),
/// [nativeName] = `languages.name` (ana-dilde ad, örn. 'Türkçe'), [locale] =
/// koda karşılık gelen uygulama-içi [AppLocale] (çeviri fetch'ini besler).
class LanguageOption {
  /// DB `languages.code` (örn. 'tr-TR', 'en-US').
  final String code;

  /// DB `languages.name` — ana-dilde görünen ad (örn. 'Türkçe', 'Italiano').
  final String nativeName;

  /// Koda karşılık gelen uygulama locale'i.
  final AppLocale locale;

  const LanguageOption({
    required this.code,
    required this.nativeName,
    required this.locale,
  });
}

/// Dil Servisi (Language Service)
///
/// Web portalının DB-güdümlü dil mekaniğini mobile taşır:
///   - `languages` (active=true) → sistemde aktif dil kümesi (code + ana-ad).
///   - `platform_app_configs.supported_languages` (text[]) → aktif platformun
///     sunduğu diller; `default_language` → platform varsayılanı.
///
/// Sunulan diller = aktif-DB-dilleri ∩ platform-desteklenen ∩ {AppLocale'e
/// eşlenen kodlar}. Sonuç platform başına bellek-cache'lenir. Hata durumunda
/// mantıklı bir fallback döner (asla çökmez).
class LanguageService {
  final SupabaseClient _supabase;
  final PlatformContext _platformContext;

  /// Platform başına sunulan dil listesi bellek-cache'i (her açılışta yeniden
  /// çekmeyi önler). Anahtar = platformId.
  final Map<String, List<LanguageOption>> _cache = {};

  LanguageService({
    required SupabaseClient supabase,
    required PlatformContext platformContext,
  })  : _supabase = supabase,
        _platformContext = platformContext;

  /// Aktif platform için sunulan dilleri döndürür.
  ///
  /// Kesişim: (aktif `languages`) ∩ (platform `supported_languages`) ∩
  /// (AppLocale'e eşlenen kodlar). `supported_languages` null/boş ise "tüm
  /// aktif diller" olarak yorumlanır. Sonuç platform başına cache'lenir.
  Future<List<LanguageOption>> availableLanguages() async {
    final platformId = _platformContext.activePlatformId;

    final cached = _cache[platformId];
    if (cached != null) return cached;

    try {
      // 1) Aktif DB dilleri (code + ana-ad).
      final langRows = await _supabase
          .from('languages')
          .select('code, name')
          .eq('active', true);

      // 2) Platformun desteklediği kodlar (yoksa → tüm aktif diller).
      final Set<String>? supportedCodes =
          await _fetchSupportedCodes(platformId);

      // 3) Kesişim + AppLocale eşlemesi.
      final options = <LanguageOption>[];
      final seen = <String>{};
      for (final row in langRows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final code = map['code'] as String?;
        if (code == null || code.isEmpty || seen.contains(code)) continue;

        // Platform bu dili sunmuyorsa atla.
        if (supportedCodes != null && !supportedCodes.contains(code)) continue;

        // Bu koda karşılık gelen bir AppLocale var mı? (yoksa render edemeyiz)
        if (!_hasMatchingLocale(code)) continue;

        final locale = AppLocale.fromLanguageCode(_shortCode(code));
        final nativeName = (map['name'] as String?)?.trim();
        options.add(LanguageOption(
          code: code,
          nativeName: (nativeName != null && nativeName.isNotEmpty)
              ? nativeName
              : locale.displayName,
          locale: locale,
        ));
        seen.add(code);
      }

      if (options.isEmpty) {
        Logger.warning(
            'availableLanguages: intersection empty for platform $platformId → fallback');
        final fallback = _fallbackOptions();
        _cache[platformId] = fallback;
        return fallback;
      }

      _cache[platformId] = options;
      Logger.info(
          'availableLanguages: ${options.length} language(s) for platform $platformId');
      return options;
    } catch (e) {
      Logger.warning('availableLanguages failed → fallback', e);
      return _fallbackOptions();
    }
  }

  /// Aktif platformun varsayılan dil kodunu (`default_language`) döndürür.
  ///
  /// Bulunamazsa/hatada null döner (çağıran mevcut default'u koruyabilir).
  Future<String?> platformDefaultLanguage() async {
    try {
      final row = await _supabase
          .from('platform_app_configs')
          .select('default_language')
          .eq('platform_id', _platformContext.activePlatformId)
          .maybeSingle();
      final value = row?['default_language'] as String?;
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (e) {
      Logger.warning('platformDefaultLanguage failed', e);
      return null;
    }
  }

  /// Bellek cache'ini temizler (platform değişince veya konsol güncellemesi
  /// sonrası yeniden çekmek için).
  void clearCache() => _cache.clear();

  // ============================================
  // INTERNALS
  // ============================================

  /// `platform_app_configs.supported_languages` (text[]) — platformun sunduğu
  /// dil kodları. Satır/kolon null/boş ise `null` döner → "tüm aktif diller".
  Future<Set<String>?> _fetchSupportedCodes(String platformId) async {
    try {
      final row = await _supabase
          .from('platform_app_configs')
          .select('supported_languages')
          .eq('platform_id', platformId)
          .maybeSingle();

      final raw = row?['supported_languages'];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toSet();
      }
      // null/boş → kısıt yok, tüm aktif diller.
      return null;
    } catch (e) {
      Logger.warning('supported_languages read failed for $platformId', e);
      return null;
    }
  }

  /// Verilen DB kodunun ('tr-TR') bir [AppLocale]'e eşlenip eşlenmediği.
  bool _hasMatchingLocale(String code) {
    final short = _shortCode(code);
    return AppLocale.values.any((l) => l.languageCode == short);
  }

  /// 'tr-TR' → 'tr' (AppLocale.languageCode kısa-kodu).
  String _shortCode(String code) =>
      code.contains('-') ? code.split('-').first : code;

  /// Kesişim/ağ başarısızsa mantıklı fallback: en yaygın iki dil (tr, en).
  List<LanguageOption> _fallbackOptions() => const [
        LanguageOption(
          code: 'tr-TR',
          nativeName: 'Türkçe',
          locale: AppLocale.turkish,
        ),
        LanguageOption(
          code: 'en-US',
          nativeName: 'English',
          locale: AppLocale.english,
        ),
      ];
}

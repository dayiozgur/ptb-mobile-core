import 'package:flutter/material.dart';

/// Auth branding paneli özelliği (slogan/feature kartı).
///
/// Web login'in `auth-branding` panelindeki her bir madde ile aynı sözleşme:
/// `icon` bir bootstrap-icons sınıfıdır (`bi-*`), [title]/[body] locale'e göre
/// çözülmüş metinlerdir.
class BrandingFeature {
  /// bootstrap-icons sınıfı (ör. `bi-calendar-check`).
  final String icon;

  /// Başlık.
  final String title;

  /// Açıklama gövdesi.
  final String body;

  const BrandingFeature({
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// Marka Yapılandırması (Branding Config)
///
/// Konsol tarafından yönetilen `platform_app_configs` (platform tabanı) ve
/// `tenant_app_configs` (tenant override) tablolarının mobil karşılığıdır.
///
/// Web konsoluyla aynı sözleşme: platform tabanı üzerine tenant override'ı
/// non-null alanlarda kazanacak şekilde uygulanır (bkz. [merge]).
class BrandingConfig {
  /// Marka adı (ör. 'Protoolbag HR')
  final String? brandName;

  /// Marka sloganı (ör. 'İnsan kaynakları yönetimi')
  final String? brandTagline;

  /// Logo URL
  final String? logoUrl;

  /// Küçük logo URL (ikon/kompakt)
  final String? logoSmallUrl;

  /// Ana renk (hex, ör. '#7c3aed')
  final String? primaryColor;

  /// Vurgu rengi (hex)
  final String? accentColor;

  /// Navbar rengi (hex) — yalnız platform tabanında
  final String? navbarColor;

  /// Sidebar rengi (hex) — yalnız platform tabanında
  final String? sidebarColor;

  /// Auth branding paneli JSON'u (`platform_app_configs.auth_branding_json`).
  ///
  /// Şekil: `{ "tagline": "<tr>", "features": [ {icon,title,body}, ... ],
  /// "i18n": { "en-US": { "tagline": "...", "features": [...] }, ... } }`.
  /// Üst seviye = varsayılan (Türkçe); `i18n.<code>` locale override'ıdır.
  /// Supabase jsonb → Dart `Map` olarak gelir.
  final Map<String, dynamic>? authBrandingJson;

  const BrandingConfig({
    this.brandName,
    this.brandTagline,
    this.logoUrl,
    this.logoSmallUrl,
    this.primaryColor,
    this.accentColor,
    this.navbarColor,
    this.sidebarColor,
    this.authBrandingJson,
  });

  /// Boş yapılandırma (varsayılan).
  static const BrandingConfig empty = BrandingConfig();

  /// DB satırından oluşturur. Hem `platform_app_configs` hem de
  /// `tenant_app_configs` satırlarıyla uyumludur (eksik alanlar null olur).
  factory BrandingConfig.fromJson(Map<String, dynamic> json) {
    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    // jsonb → supabase-flutter tarafından Map olarak gelir; savunmacı cast.
    Map<String, dynamic>? asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;

    return BrandingConfig(
      brandName: str(json['brand_name']),
      brandTagline: str(json['brand_tagline']),
      logoUrl: str(json['logo_url']),
      logoSmallUrl: str(json['logo_small_url']),
      primaryColor: str(json['primary_color']),
      accentColor: str(json['accent_color']),
      navbarColor: str(json['navbar_color']),
      sidebarColor: str(json['sidebar_color']),
      authBrandingJson: asMap(json['auth_branding_json']),
    );
  }

  /// Bu tabanın üzerine [override]'ı uygular; override'ın non-null alanları
  /// kazanır. `null` override → taban değeri korunur.
  BrandingConfig merge(BrandingConfig? override) {
    if (override == null) return this;
    return BrandingConfig(
      brandName: override.brandName ?? brandName,
      brandTagline: override.brandTagline ?? brandTagline,
      logoUrl: override.logoUrl ?? logoUrl,
      logoSmallUrl: override.logoSmallUrl ?? logoSmallUrl,
      primaryColor: override.primaryColor ?? primaryColor,
      accentColor: override.accentColor ?? accentColor,
      navbarColor: override.navbarColor ?? navbarColor,
      sidebarColor: override.sidebarColor ?? sidebarColor,
      authBrandingJson: override.authBrandingJson ?? authBrandingJson,
    );
  }

  /// [localeCode] (ör. 'en-US') için auth-branding tagline'ı çözer.
  /// Sıra: `i18n.<code>.tagline` → üst-seviye `tagline` → [brandTagline].
  String? taglineFor(String localeCode) {
    final json = authBrandingJson;
    if (json == null) return brandTagline;
    final i18n = json['i18n'];
    if (i18n is Map) {
      final loc = i18n[localeCode];
      if (loc is Map) {
        final t = loc['tagline'];
        if (t is String && t.trim().isNotEmpty) return t;
      }
    }
    final top = json['tagline'];
    if (top is String && top.trim().isNotEmpty) return top;
    return brandTagline;
  }

  /// [localeCode] (ör. 'en-US') için auth-branding feature listesini çözer.
  /// Sıra: `i18n.<code>.features` → üst-seviye `features` → `[]`.
  List<BrandingFeature> featuresFor(String localeCode) {
    final json = authBrandingJson;
    if (json == null) return const [];

    List? raw;
    final i18n = json['i18n'];
    if (i18n is Map) {
      final loc = i18n[localeCode];
      if (loc is Map && loc['features'] is List) {
        raw = loc['features'] as List;
      }
    }
    raw ??= (json['features'] is List) ? json['features'] as List : null;
    if (raw == null) return const [];

    final result = <BrandingFeature>[];
    for (final item in raw) {
      if (item is! Map) continue;
      String s(dynamic v) => v == null ? '' : v.toString();
      result.add(BrandingFeature(
        icon: s(item['icon']),
        title: s(item['title']),
        body: s(item['body']),
      ));
    }
    return result;
  }

  /// [primaryColor] hex string'ini [Color]'a çevirir; çözülemezse null.
  Color? get primary => _parseHex(primaryColor);

  /// [accentColor] hex string'ini [Color]'a çevirir; çözülemezse null.
  Color? get accent => _parseHex(accentColor);

  /// `#RRGGBB` → `Color(0xFFRRGGBB)`. Geçersiz/null → null.
  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var value = hex.trim();
    if (value.startsWith('#')) {
      value = value.substring(1);
    }
    if (value.length == 8) {
      // ARGB verilmişse aynen kullan.
      final argb = int.tryParse(value, radix: 16);
      return argb == null ? null : Color(argb);
    }
    if (value.length != 6) return null;
    final rgb = int.tryParse(value, radix: 16);
    if (rgb == null) return null;
    return Color(0xFF000000 | rgb);
  }
}

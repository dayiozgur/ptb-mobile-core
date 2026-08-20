import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import 'branding_config.dart';

/// Marka Servisi (Branding Service)
///
/// Konsol tarafından yönetilen marka yapılandırmasını DB'den yükler:
///   - `platform_app_configs` → platform tabanı (marka adı, slogan, renkler)
///   - `tenant_app_configs`   → tenant override (non-null alanlar tabanı ezer)
///
/// Web konsoluyla aynı sözleşmeyi izler; böylece her platform-app (PMS, PHR)
/// KENDİ markasını gösterir (PMS-branding sızıntısı düzeltilir).
class BrandingService {
  final SupabaseClient _supabase;

  /// Aktif marka yapılandırması stream'i.
  final _controller = StreamController<BrandingConfig>.broadcast();

  /// Son yüklenen yapılandırma (bellek cache).
  BrandingConfig? _current;

  BrandingService({
    required SupabaseClient supabase,
  }) : _supabase = supabase;

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut (son yüklenen) marka yapılandırması. Henüz yüklenmediyse null.
  BrandingConfig? get current => _current;

  /// Marka yapılandırması değişiklik stream'i.
  Stream<BrandingConfig> get stream => _controller.stream;

  // ============================================
  // LOAD
  // ============================================

  /// Marka yapılandırmasını yükler.
  ///
  /// [platformId] için `platform_app_configs` tabanını okur; [tenantId]
  /// verilmişse `tenant_app_configs` override'ını okuyup taban üzerine
  /// [BrandingConfig.merge] ile uygular. Sonucu belleğe alır, stream'e
  /// yayınlar ve döndürür. Hata durumunda markayı çökertmemek için
  /// [current] döner.
  Future<BrandingConfig?> load(String platformId, {String? tenantId}) async {
    try {
      final baseRow = await _supabase
          .from('platform_app_configs')
          .select()
          .eq('platform_id', platformId)
          .eq('active', true)
          .maybeSingle();

      var config = baseRow == null
          ? BrandingConfig.empty
          : BrandingConfig.fromJson(baseRow);

      if (tenantId != null) {
        final overrideRow = await _supabase
            .from('tenant_app_configs')
            .select()
            .eq('tenant_id', tenantId)
            .maybeSingle();

        if (overrideRow != null) {
          config = config.merge(BrandingConfig.fromJson(overrideRow));
        }
      }

      _current = config;
      _controller.add(config);
      Logger.info(
        'Branding loaded for platform $platformId'
        '${tenantId != null ? ' (tenant $tenantId)' : ''}: '
        '${config.brandName ?? '(no brand_name)'}',
      );
      return config;
    } catch (e) {
      Logger.error('Error loading branding config: $e');
      // Markayı çökertme — son bilinen değeri döndür.
      return _current;
    }
  }

  // ============================================
  // RESET
  // ============================================

  /// Bellek cache'ini sıfırlar.
  void clear() {
    _current = null;
  }

  /// Servisi kapat.
  void dispose() {
    _controller.close();
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Admin — Entegrasyon (integration connector) görüntüleyici (salt-okuma) servis.
///
/// Web portal `/admin/integrations` (ops-console + integration framework)
/// okuma-yolunu aynalar. Kanonik kaynak `integration_connectors` tablosudur
/// (web `IntegrationConnectorsService.list()` ile aynı). Her connector, en son
/// çalıştırma durumunu satır-içi `last_run_at / last_status / last_error`
/// kolonlarında taşır (ayrıca `integration_runs` geçmiş tablosu vardır; mobil
/// v1 salt-okuma liste için connector satırındaki özet yeterlidir).
///
/// Yazma YOK — v1 salt-okuma liste. Tenant/platform kapsamı **RLS** ile
/// sağlanır; ada göre sıralanır.
class AdminIntegrationService {
  final SupabaseClient _supabase;

  static const String _table = 'integration_connectors';

  AdminIntegrationService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Yapılandırılmış entegrasyonları (ada göre) getirir. RLS-scoped.
  Future<List<IntegrationRow>> listIntegrations({int limit = 100}) async {
    try {
      final rows = await _supabase
          .from(_table)
          .select(
            'id, name, kind, provider, enabled, schedule, '
            'last_run_at, last_status, last_error, created_at',
          )
          .order('name', ascending: true)
          .limit(limit);

      final result = (rows as List)
          .map((e) => IntegrationRow.fromJson(e as Map<String, dynamic>))
          .toList();

      Logger.debug('AdminIntegrationService.listIntegrations → ${result.length}');
      return result;
    } catch (e, st) {
      Logger.error('AdminIntegrationService.listIntegrations hata', e, st);
      rethrow;
    }
  }
}

/// Entegrasyon connector satırı görüntü-modeli (salt-okuma).
class IntegrationRow {
  final String id;
  final String? name;

  /// Bağlayıcı türü (`weather | bank | einvoice | rest | ...`).
  final String? kind;

  /// Sağlayıcı (`openweather | accuweather | ...`).
  final String? provider;

  final bool enabled;

  /// Cron ifadesi ya da null (manuel).
  final String? schedule;

  /// En son çalıştırma zamanı.
  final DateTime? lastRunAt;

  /// En son çalıştırma durumu (`success | error | running | ...`).
  final String? lastStatus;

  /// En son çalıştırma hatası (varsa).
  final String? lastError;

  final DateTime? createdAt;

  const IntegrationRow({
    required this.id,
    this.name,
    this.kind,
    this.provider,
    this.enabled = false,
    this.schedule,
    this.lastRunAt,
    this.lastStatus,
    this.lastError,
    this.createdAt,
  });

  /// Görüntülenecek tür etiketi: `kind · provider` (ikisi de varsa).
  String get typeLabel {
    final k = (kind ?? '').trim();
    final p = (provider ?? '').trim();
    if (k.isNotEmpty && p.isNotEmpty) return '$k · $p';
    if (k.isNotEmpty) return k;
    if (p.isNotEmpty) return p;
    return '—';
  }

  factory IntegrationRow.fromJson(Map<String, dynamic> json) {
    return IntegrationRow(
      id: json['id'] as String,
      name: json['name'] as String?,
      kind: json['kind'] as String?,
      provider: json['provider'] as String?,
      enabled: (json['enabled'] as bool?) ?? false,
      schedule: json['schedule'] as String?,
      lastRunAt: DateTime.tryParse((json['last_run_at'] as String?) ?? ''),
      lastStatus: json['last_status'] as String?,
      lastError: json['last_error'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

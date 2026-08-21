import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Admin/Hesap — Abonelik (subscription) görüntüleyici (salt-okuma) servis.
///
/// Web `SubscriptionService.getActiveSubscription()` + `getPlanQuotas()` okuma
/// yolunu aynalar (aynı Supabase projesi). Geçerli tenant'ın aktif planı,
/// durumu, deneme/yenileme tarihleri ve plan kotaları (limit) okunur. Varsa
/// `tenant_usage_metrics`'ten kullanım değerleri eşleştirilir (web `BillingService`
/// mantığı). RLS/JWT ile tenant-scoped; **satın alma YOK** (mobilde yasak).
///
/// Kotalar `subscription_plans` → `plan_quotas` (plan başına limit) tablosundan
/// gelir; global (platform_id NULL) abonelik tercih edilir — web `getActiveSubscription`
/// ile aynı çözünürlük.
class AdminSubscriptionService {
  final SupabaseClient _supabase;

  AdminSubscriptionService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Geçerli tenant'ın aktif aboneliğini getirir (trial | active | past_due).
  /// Global abonelik (platform_id NULL) tercih edilir.
  Future<SubscriptionInfo?> getSubscription({required String? tenantId}) async {
    try {
      if (tenantId == null || tenantId.isEmpty) {
        Logger.debug('AdminSubscriptionService: tenant yok');
        return null;
      }

      final row = await _supabase
          .from('tenant_subscriptions')
          .select('''
            *,
            subscription_plan:subscription_plans(
              id, plan_code, plan_name, description,
              price_monthly, price_yearly, currency, trial_days
            )
          ''')
          .eq('tenant_id', tenantId)
          .inFilter('status', ['trial', 'active', 'past_due'])
          .order('platform_id', ascending: true, nullsFirst: true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) return null;
      return SubscriptionInfo.fromJson(row);
    } catch (e, st) {
      Logger.error('AdminSubscriptionService.getSubscription hata', e, st);
      rethrow;
    }
  }

  /// Plan kotalarını (limit) getirir. Kullanım değerleri (`tenant_usage_metrics`)
  /// varsa quota_key ↔ metric_key ile eşleştirilir.
  Future<List<QuotaRow>> listPlanQuotas({
    required String planId,
    String? tenantId,
  }) async {
    try {
      final quotas = await _supabase
          .from('plan_quotas')
          .select('quota_key, quota_value, quota_unit')
          .eq('subscription_plan_id', planId);

      final usage = <String, double>{};
      if (tenantId != null && tenantId.isNotEmpty) {
        try {
          final metrics = await _supabase
              .from('tenant_usage_metrics')
              .select('metric_key, metric_value')
              .eq('tenant_id', tenantId);
          for (final m in (metrics as List)) {
            final map = m as Map<String, dynamic>;
            final key = map['metric_key'] as String?;
            final val = (map['metric_value'] as num?)?.toDouble();
            if (key != null && val != null) usage[key] = val;
          }
        } catch (e) {
          // Kullanım metrikleri opsiyoneldir — hata yalnız log, limitler yine gösterilir.
          Logger.warning('AdminSubscriptionService kullanım metrikleri okunamadı: $e');
        }
      }

      final result = (quotas as List).map((e) {
        final map = e as Map<String, dynamic>;
        final key = map['quota_key'] as String?;
        return QuotaRow(
          quotaKey: key,
          quotaValue: (map['quota_value'] as num?)?.toInt(),
          quotaUnit: map['quota_unit'] as String?,
          usedValue: key == null ? null : usage[key],
        );
      }).toList()
        ..sort((a, b) => (a.quotaKey ?? '').compareTo(b.quotaKey ?? ''));

      Logger.debug('AdminSubscriptionService.listPlanQuotas → ${result.length}');
      return result;
    } catch (e, st) {
      Logger.error('AdminSubscriptionService.listPlanQuotas hata', e, st);
      rethrow;
    }
  }
}

/// Abonelik görüntü-modeli (salt-okuma).
class SubscriptionInfo {
  final String id;
  final String? planId;
  final String? planName;
  final String? planCode;

  /// `trial | active | past_due | canceled | expired`.
  final String? status;
  final String? currency;
  final num? priceMonthly;
  final num? priceYearly;

  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? trialStartsAt;
  final DateTime? trialEndsAt;
  final bool cancelAtPeriodEnd;

  const SubscriptionInfo({
    required this.id,
    this.planId,
    this.planName,
    this.planCode,
    this.status,
    this.currency,
    this.priceMonthly,
    this.priceYearly,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.trialStartsAt,
    this.trialEndsAt,
    this.cancelAtPeriodEnd = false,
  });

  bool get isTrial => status == 'trial';

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? plan;
    final embed = json['subscription_plan'];
    if (embed is Map<String, dynamic>) {
      plan = embed;
    } else if (embed is List && embed.isNotEmpty && embed.first is Map) {
      plan = (embed.first as Map).cast<String, dynamic>();
    }

    DateTime? d(String key) =>
        DateTime.tryParse((json[key] as String?) ?? '');

    return SubscriptionInfo(
      id: json['id'] as String,
      planId: plan?['id'] as String?,
      planName: plan?['plan_name'] as String?,
      planCode: plan?['plan_code'] as String?,
      status: json['status'] as String?,
      currency: plan?['currency'] as String?,
      priceMonthly: plan?['price_monthly'] as num?,
      priceYearly: plan?['price_yearly'] as num?,
      currentPeriodStart: d('current_period_start'),
      currentPeriodEnd: d('current_period_end'),
      trialStartsAt: d('trial_starts_at'),
      trialEndsAt: d('trial_ends_at'),
      cancelAtPeriodEnd: (json['cancel_at_period_end'] as bool?) ?? false,
    );
  }
}

/// Kota (limit) satırı görüntü-modeli. `usedValue` varsa kullanım gösterilir.
class QuotaRow {
  final String? quotaKey;
  final int? quotaValue;
  final String? quotaUnit;
  final double? usedValue;

  const QuotaRow({
    this.quotaKey,
    this.quotaValue,
    this.quotaUnit,
    this.usedValue,
  });

  /// 0..1 kullanım oranı (limit ve kullanım varsa). Aksi halde null.
  double? get usageFraction {
    final limit = quotaValue;
    final used = usedValue;
    if (limit == null || limit <= 0 || used == null) return null;
    final f = used / limit;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }
}

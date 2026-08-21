import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/admin_performance_review.dart';
import 'models/competency.dart';
import 'models/performance_cycle.dart';

/// İK yönetim (admin) performans + yetkinlik salt-okuma veri katmanı.
///
/// PHR mobil yönetim ekranlarını besler:
///   • [cycles]        → `/admin/performance/cycles`  (Performans Dönemleri)
///   • [allReviews]    → `/admin/performance/reviews` (Tüm Değerlendirmeler)
///   • [competencies]  → `/admin/competencies`        (Yetkinlikler)
///
/// Web PHR yönetim servisleriyle **birebir** okuma sözleşmesi:
///   • [cycles] ↔ `PerformanceService.getCycles` (`CYCLE_SELECT`)
///   • [allReviews] ↔ `PerformanceService.getReviews` (`REVIEW_SELECT`) — tenant
///     genelindeki tüm değerlendirmeler, değerlendiren + değerlendirilen embed'li
///   • [competencies] ↔ `CompetencyService.list` (`competencies`, aktif)
///
/// Tenant kapsamı RLS ile sağlanır; ek olarak `TenantService.currentTenantId`
/// biliniyorsa sorgu `tenant_id` ile daraltılır (web ile aynı davranış).
/// Hata durumunda [Logger.error] + `rethrow` — ekran gerçek hatayı gösterir.
///
/// Yazma YOK — v1 salt-okuma viewer.
class AdminPerformanceService {
  final SupabaseClient _supabase;

  AdminPerformanceService({required SupabaseClient supabase})
      : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  /// Web `PerformanceService.CYCLE_SELECT`.
  static const String _cycleSelect =
      'id,tenant_id,name,description,period_start,period_end,status,active';

  /// Web `PerformanceService.REVIEW_SELECT` — dönem + değerlendirilen + değerlendiren
  /// embed'leri FK-hint ayrımıyla (staffs iki kez join olduğundan zorunlu).
  static const String _reviewSelect =
      'id,tenant_id,cycle_id,staff_id,reviewer_staff_id,organization_id,'
      'self_rating,manager_rating,overall_rating,self_comments,manager_comments,'
      'status,decided_at,active,created_at,'
      'performance_cycles(name),'
      'staffs!performance_reviews_staff_id_fkey(name,first_name,last_name),'
      'reviewer:staffs!performance_reviews_reviewer_staff_id_fkey('
      'name,first_name,last_name)';

  // ============================================
  // PERFORMANS DÖNEMLERİ (performance_cycles)
  // ============================================

  /// Tenant'ın performans dönemleri — `performance_cycles`, `period_start`
  /// azalan. Web `PerformanceService.getCycles` ile birebir.
  Future<List<PerformanceCycle>> cycles() async {
    try {
      var query = _supabase.from('performance_cycles').select(_cycleSelect);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response =
          await query.order('period_start', ascending: false);

      return (response as List)
          .map((e) => PerformanceCycle.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPerformanceService.cycles hata: $e');
      rethrow;
    }
  }

  // ============================================
  // TÜM DEĞERLENDİRMELER (performance_reviews)
  // ============================================

  /// Tenant genelindeki tüm performans değerlendirmeleri (İK admin görünümü) —
  /// `performance_reviews`, `created_at` azalan; değerlendiren + değerlendirilen
  /// + dönem adı embed'li. Web `PerformanceService.getReviews` ile birebir.
  Future<List<AdminPerformanceReview>> allReviews({int limit = 200}) async {
    try {
      var query =
          _supabase.from('performance_reviews').select(_reviewSelect);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((e) =>
              AdminPerformanceReview.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPerformanceService.allReviews hata: $e');
      rethrow;
    }
  }

  // ============================================
  // YETKİNLİKLER (competencies)
  // ============================================

  /// Aktif yetkinlikler — tenant'a ait + global (paylaşımlı, `tenant_id` null)
  /// satırlar; `name` sıralı. Web `CompetencyService.list` okumasının aynası;
  /// tek fark: global şablonları da kapsamak için tenant filtresi `or(tenant
  /// eq X, tenant is null)` biçimindedir (RLS ile aynı okuma sınırı).
  Future<List<Competency>> competencies() async {
    try {
      var query =
          _supabase.from('competencies').select('*').eq('active', true);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.or('tenant_id.eq.$tenantId,tenant_id.is.null');
      }

      final response = await query.order('name');

      return (response as List)
          .map((e) => Competency.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPerformanceService.competencies hata: $e');
      rethrow;
    }
  }
}

/// DI kısayolu — kayıtlı [AdminPerformanceService] örneğini döndürür.
/// (Web PHR yönetim servislerinin mobil salt-okuma karşılığı.)
AdminPerformanceService get adminPerformanceService =>
    sl<AdminPerformanceService>();

import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'hr_ess_service.dart';
import 'models/leave_calendar_entry.dart';
import 'models/review_competency_rating.dart';
import 'models/review_queue_item.dart';

// Yeni takvim/kuyruk modellerini barrel'a (protoolbag_core) taşı: barrel bu
// dosyayı export ettiğinden re-export transitif olarak yayılır.
export 'models/leave_calendar_entry.dart';
export 'models/review_competency_rating.dart';
export 'models/review_queue_item.dart';

/// PHR ESS — **İzin Takvimi** + **Değerlendirme Kuyruğu** veri katmanı.
///
/// [HrEssService]'i tamamlayan ayrı bir salt-veri servisidir (paylaşılan dosyayı
/// değiştirmemek için ayrık tutulur). Web `LeaveService` / `PerformanceService`
/// ile **birebir aynı DB sözleşmesi** kullanılır:
///
/// * [leaveCalendar]  → `leave_requests` (approved+pending, tarih-kesişim);
///   web `getTeamRequests`. Kapsam RLS'e bırakılır (çalışan → kendi + astları/
///   organizasyon, yönetici → ekip, admin → tenant). Web'in workspace org-filtresi
///   mobilde YOK; kapsam tamamen RLS ile belirlenir.
/// * [reviewQueue]    → `performance_reviews` where `reviewer_staff_id = benim`;
///   web `getReviewQueue` (durum filtresi YOK — web tüm reviewer satırlarını döner).
/// * [reviewCompetencies] → `review_competency_ratings` (detay alt-sayfası).
///
/// Tüm metodlar hata durumunda **rethrow** eder (sessiz-boş DÖNMEZ) — ekranlar
/// gerçek hatayı gösterebilir. Staff çözümü [HrEssService.currentStaffId] ile.
class HrCalendarReviewService {
  final SupabaseClient _supabase;

  HrCalendarReviewService({required SupabaseClient supabase})
      : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  // Web LeaveService.REQUEST_SELECT'in takvim için ihtiyaç duyulan alt kümesi.
  static const String _leaveSelect =
      'id,tenant_id,staff_id,leave_type_id,start_date,end_date,day_count,status,'
      'leave_types(name),'
      'staffs!leave_requests_staff_id_fkey(name,first_name,last_name)';

  // Web PerformanceService.REVIEW_SELECT ile aynı alanlar + değerlendirilen embed.
  static const String _reviewSelect =
      'id,tenant_id,cycle_id,staff_id,reviewer_staff_id,organization_id,'
      'self_rating,manager_rating,overall_rating,self_comments,manager_comments,'
      'status,decided_at,active,created_at,'
      'performance_cycles(name),'
      'staffs!performance_reviews_staff_id_fkey(name,first_name,last_name)';

  static const String _competencySelect =
      'id,tenant_id,review_id,competency_id,competency_label,rating,comment';

  // ============================================
  // LEAVE CALENDAR
  // ============================================

  /// Belirtilen [from]–[to] aralığıyla kesişen izinler — `leave_requests`
  /// (approved + pending). Web `LeaveService.getTeamRequests` ile birebir:
  ///   `status in (approved, pending)` AND `start_date <= to` AND `end_date >= from`,
  ///   `start_date` artan. Kapsam RLS ile (kendi + ekip/organizasyon/tenant).
  Future<List<LeaveCalendarEntry>> leaveCalendar({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      var query = _supabase
          .from('leave_requests')
          .select(_leaveSelect)
          .inFilter('status', ['approved', 'pending'])
          .lte('start_date', _fmtDate(to))
          .gte('end_date', _fmtDate(from));

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('start_date', ascending: true);

      return (response as List)
          .map((e) => LeaveCalendarEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching leave calendar: $e');
      rethrow;
    }
  }

  // ============================================
  // REVIEW QUEUE (yönetici)
  // ============================================

  /// Mevcut kullanıcının değerlendirmesi gereken performans değerlendirmeleri —
  /// `performance_reviews` where `reviewer_staff_id = benim staff'ım`. Web
  /// `PerformanceService.getReviewQueue` ile birebir (durum filtresi YOK;
  /// `created_at DESC`). Staff çözülemezse boş liste döner.
  Future<List<ReviewQueueItem>> reviewQueue() async {
    try {
      final staffId = await hrEssService.currentStaffId();
      if (staffId == null) return [];

      var query = _supabase
          .from('performance_reviews')
          .select(_reviewSelect)
          .eq('reviewer_staff_id', staffId);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((e) => ReviewQueueItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching review queue: $e');
      rethrow;
    }
  }

  /// Bir değerlendirmenin yetkinlik puanları — `review_competency_ratings`
  /// (web `PerformanceService.getCompetencyRatings`). Detay alt-sayfasında
  /// salt-okuma gösterim.
  Future<List<ReviewCompetencyRating>> reviewCompetencies(
      String reviewId) async {
    try {
      var query = _supabase
          .from('review_competency_ratings')
          .select(_competencySelect)
          .eq('review_id', reviewId);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('created_at', ascending: true);

      return (response as List)
          .map((e) =>
              ReviewCompetencyRating.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching review competencies: $e');
      rethrow;
    }
  }

  /// `yyyy-MM-dd` biçimi (date sütun karşılaştırmaları için).
  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

/// Global erişim kısayolu (service_locator kaydından çözer).
HrCalendarReviewService get hrCalendarReviewService =>
    sl<HrCalendarReviewService>();

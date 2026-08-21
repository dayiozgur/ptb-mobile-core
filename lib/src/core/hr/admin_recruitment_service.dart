import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/hr_analytics_snapshot.dart';
import 'models/job_application_row.dart';
import 'models/job_posting_row.dart';
import 'models/pipeline_stage_group.dart';

/// İK yönetim — işe alım (ATS) + İK analitik salt-okuma veri katmanı.
///
/// PHR mobil yönetim ekranlarını besler:
///   • [postings]        → `/admin/recruitment/postings`   (İş İlanları)
///   • [applications]    → `/admin/recruitment/candidates`  (Adaylar)
///   • [pipelineByStage] → `/admin/recruitment/pipeline`    (İşe Alım Hattı)
///   • [analytics]       → `/admin/hr-analytics`            (İK Analitik)
///
/// Web PHR ATS servisiyle **birebir** okuma sözleşmesi:
///   • [postings] ↔ `AtsService.getPostings` (`POSTING_SELECT`); ek olarak
///     PostgREST `job_applications(count)` aggregate embed'i ile başvuru sayısı.
///   • [applications] ↔ `AtsService.getApplications` (`APPLICATION_SELECT`) —
///     ilan başlığı + aday adı FK-hint embed'li.
///   • [pipelineByStage] — `job_applications` satırlarını `stage` kolonuna göre
///     kanonik hat sırasında gruplar (web `ApplicationStage` sırası).
///
/// Tenant kapsamı RLS ile sağlanır; ayrıca `TenantService.currentTenantId`
/// biliniyorsa sorgu `tenant_id` ile daraltılır (web ile aynı davranış).
/// Hata durumunda [Logger.error] + `rethrow` — ekran gerçek hatayı gösterir.
///
/// Yazma YOK — v1 salt-okuma viewer.
class AdminRecruitmentService {
  final SupabaseClient _supabase;

  AdminRecruitmentService({required SupabaseClient supabase})
      : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  /// Web `AtsService.POSTING_SELECT` + başvuru sayısı aggregate embed'i.
  static const String _postingSelect =
      'id,tenant_id,organization_id,department_id,title,description,'
      'employment_type,location,openings,status,active,created_at,'
      'departments!job_postings_department_id_fkey(name),'
      'job_applications(count)';

  /// Web `AtsService.APPLICATION_SELECT` — ilan + aday embed'leri FK-hint
  /// ayrımıyla (aday adı `job_candidates` üzerinden çözülür).
  static const String _applicationSelect =
      'id,tenant_id,job_posting_id,candidate_id,organization_id,stage,rating,'
      'recruiter_staff_id,applied_at,decided_at,notes,active,created_at,'
      'job_postings!job_applications_job_posting_id_fkey(title),'
      'job_candidates!job_applications_candidate_id_fkey(first_name,last_name)';

  /// İşe alım hattının kanonik aşama sırası (web `ApplicationStage` ile aynı).
  static const List<String> pipelineStageOrder = [
    'applied',
    'screening',
    'interview',
    'offer',
    'hired',
    'rejected',
  ];

  // ============================================
  // İŞ İLANLARI (job_postings)
  // ============================================

  /// Tenant'ın iş ilanları — `job_postings`, `created_at` azalan; departman adı
  /// + başvuru sayısı embed'li. Web `AtsService.getPostings` ile birebir.
  Future<List<JobPostingRow>> postings() async {
    try {
      var query = _supabase.from('job_postings').select(_postingSelect);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((e) => JobPostingRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminRecruitmentService.postings hata: $e');
      rethrow;
    }
  }

  // ============================================
  // ADAYLAR / BAŞVURULAR (job_applications)
  // ============================================

  /// Tenant'ın aday başvuruları — `job_applications`, `applied_at` azalan; ilan
  /// başlığı + aday adı embed'li. Web `AtsService.getApplications` ile birebir.
  Future<List<JobApplicationRow>> applications({int limit = 300}) async {
    try {
      var query =
          _supabase.from('job_applications').select(_applicationSelect);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response =
          await query.order('applied_at', ascending: false).limit(limit);

      return (response as List)
          .map((e) => JobApplicationRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminRecruitmentService.applications hata: $e');
      rethrow;
    }
  }

  // ============================================
  // İŞE ALIM HATTI (job_applications, stage'e göre gruplu)
  // ============================================

  /// Başvuruları `stage` kolonuna göre kanonik hat sırasında gruplar. Boş
  /// aşamalar da (0 sayı) döner ki hat tam görünsün; bilinmeyen aşamalar sona
  /// eklenir. v1: sürükle-bırak değil, aşama başına sayı + kart listesi.
  Future<List<PipelineStageGroup>> pipelineByStage() async {
    try {
      final rows = await applications();

      final Map<String, List<JobApplicationRow>> byStage = {
        for (final s in pipelineStageOrder) s: <JobApplicationRow>[],
      };
      for (final a in rows) {
        (byStage[a.stage] ??= <JobApplicationRow>[]).add(a);
      }

      // Kanonik sıra önce, ardından şemada olmayan (bilinmeyen) aşamalar.
      final ordered = <String>[
        ...pipelineStageOrder,
        ...byStage.keys.where((k) => !pipelineStageOrder.contains(k)),
      ];

      return ordered
          .map((s) => PipelineStageGroup(
                stage: s,
                applications: byStage[s] ?? const [],
              ))
          .toList();
    } catch (e) {
      Logger.error('AdminRecruitmentService.pipelineByStage hata: $e');
      rethrow;
    }
  }

  // ============================================
  // İK ANALİTİK (KPI özeti)
  // ============================================

  /// İK yönetim panosu KPI özeti — birkaç tenant-kapsamlı sayım + (varsa)
  /// `fn_hr_headcount_trend` üzerinden trailing-12-ay işten ayrılma oranı.
  /// Web ağır dimensional RPC'lerinin mobil v1 sadeleştirmesi.
  Future<HrAnalyticsSnapshot> analytics() async {
    try {
      final tenantId = _tenant.currentTenantId;

      final results = await Future.wait([
        _count('staffs', tenantId),
        _count('staffs', tenantId, activeOnly: true),
        _count('job_postings', tenantId, status: 'open'),
        _count('job_applications', tenantId),
        _count('leave_requests', tenantId, status: 'pending'),
      ]);

      final totalHeadcount = results[0];
      final activeHeadcount = results[1];
      final openPositions = results[2];
      final totalApplications = results[3];
      final pendingLeave = results[4];

      final turnoverRate =
          await _turnoverRate(activeHeadcount: activeHeadcount);

      return HrAnalyticsSnapshot(
        totalHeadcount: totalHeadcount,
        activeHeadcount: activeHeadcount,
        openPositions: openPositions,
        totalApplications: totalApplications,
        pendingLeave: pendingLeave,
        turnoverRate: turnoverRate,
      );
    } catch (e) {
      Logger.error('AdminRecruitmentService.analytics hata: $e');
      rethrow;
    }
  }

  /// Tenant-kapsamlı satır sayısı (opsiyonel `active`/`status` süzgeci).
  Future<int> _count(
    String table,
    String? tenantId, {
    bool activeOnly = false,
    String? status,
  }) async {
    var query = _supabase.from(table).select('id');
    if (tenantId != null) query = query.eq('tenant_id', tenantId);
    if (activeOnly) query = query.eq('active', true);
    if (status != null) query = query.eq('status', status);
    final response = await query.count(CountOption.exact);
    return response.count;
  }

  /// Trailing-12-ay işten ayrılma oranı % (çıkış / aktif headcount). RPC
  /// başarısızsa veya headcount 0 ise `null` — kart "—" gösterir. Hata YUTULUR
  /// (analitik özet, panonun geri kalanını bloklamamalı).
  Future<double?> _turnoverRate({required int activeHeadcount}) async {
    if (activeHeadcount <= 0) return null;
    try {
      final now = DateTime.now();
      final to = _ymd(now);
      final from = _ymd(DateTime(now.year, now.month - 11, 1));

      final data = await _supabase.rpc(
        'fn_hr_headcount_trend',
        params: {'p_from': from, 'p_to': to},
      );

      if (data is! List) return null;
      var exits = 0;
      for (final r in data) {
        if (r is Map) exits += _toInt(r['exits']);
      }
      final pct = (exits / activeHeadcount) * 100;
      return (pct * 10).roundToDouble() / 10; // 1 ondalık
    } catch (e) {
      Logger.error('AdminRecruitmentService._turnoverRate hata: $e');
      return null;
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// 'YYYY-MM-DD' — RPC tarih parametresi için.
  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// DI kısayolu — kayıtlı [AdminRecruitmentService] örneğini döndürür.
AdminRecruitmentService get adminRecruitmentService =>
    sl<AdminRecruitmentService>();

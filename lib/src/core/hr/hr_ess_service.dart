import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/employee_goal.dart';
import 'models/leave_balance.dart';
import 'models/leave_request_row.dart';
import 'models/onboarding_task.dart';
import 'models/payslip.dart';
import 'models/pdks_day.dart';
import 'models/performance_review.dart';

// Yeni performans self-servis modellerini barrel'a (protoolbag_core) aktar:
// barrel bu dosyayı export ettiğinden re-export transitif olarak taşınır.
export 'models/employee_goal.dart';
export 'models/performance_review.dart';

/// HR Employee-Self-Service (ESS) data layer.
///
/// PHR mobil uygulamasının izin / bordro / puantaj (PDKS) / oryantasyon
/// ekranlarını beslediği salt-veri servisidir. Tüm metodlar hata durumunda
/// **rethrow** eder (sessiz-boş DÖNMEZ) — böylece ekranlar gerçek hatayı
/// gösterebilir.
///
/// RLS sahibi-kapsamlı olduğundan tablo sorguları doğrudan yapılır; RPC'ler
/// `auth.uid()` / verilen `staff_id` üzerinden kapsanır.
class HrEssService {
  final SupabaseClient _supabase;

  /// Çözümlenen mevcut `staff_id` (bir kez çözülür + cache'lenir).
  String? _cachedStaffId;

  HrEssService({required SupabaseClient supabase}) : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  /// Cache'i temizle (ör. logout / tenant değişimi sonrası).
  void clearCache() {
    _cachedStaffId = null;
  }

  // ============================================
  // STAFF RESOLUTION
  // ============================================

  /// Mevcut oturum açmış kullanıcının `staffs.id` değerini çözer.
  ///
  /// Bağlantı: `auth.uid()` == `profiles.id` == `staffs.profile_id`
  /// (canlı DB'de doğrulandı; `profile_id` populated & profiles'a join olur).
  /// Sonuç bir kez çözülüp cache'lenir. Eşleşme yoksa `null` döner.
  Future<String?> currentStaffId() async {
    if (_cachedStaffId != null) return _cachedStaffId;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      Logger.warning('HrEssService.currentStaffId: no authenticated user');
      return null;
    }

    try {
      var query = _supabase
          .from('staffs')
          .select('id')
          .eq('profile_id', userId);

      // Tenant biliniyorsa kapsamı daralt (çok-tenant güvenliği).
      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.limit(1).maybeSingle();
      if (response == null) {
        Logger.warning(
            'HrEssService.currentStaffId: no staff row for profile $userId');
        return null;
      }

      _cachedStaffId = response['id'] as String?;
      return _cachedStaffId;
    } catch (e) {
      Logger.error('Error resolving current staff id: $e');
      rethrow;
    }
  }

  // ============================================
  // LEAVE
  // ============================================

  /// İzin bakiye özeti — `fn_leave_balance_summary(p_staff_id)`.
  Future<List<LeaveBalance>> leaveBalance() async {
    try {
      final staffId = await currentStaffId();
      if (staffId == null) return [];

      final response = await _supabase.rpc(
        'fn_leave_balance_summary',
        params: {'p_staff_id': staffId},
      );

      return (response as List)
          .map((e) => LeaveBalance.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching leave balance: $e');
      rethrow;
    }
  }

  /// Kullanıcının kendi izin talepleri — `leave_requests` (RLS owner-scoped).
  ///
  /// `leave_types` adları tek sorguda çözülür; çözülemezse [LeaveRequestRow]
  /// yalnızca `leaveTypeId` taşır.
  Future<List<LeaveRequestRow>> myLeaveRequests({int limit = 50}) async {
    try {
      final staffId = await currentStaffId();
      if (staffId == null) return [];

      final response = await _supabase
          .from('leave_requests')
          .select()
          .eq('staff_id', staffId)
          .order('created_at', ascending: false)
          .limit(limit);

      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return [];

      final typeNames = await _resolveLeaveTypeNames(rows);

      return rows
          .map((r) => LeaveRequestRow.fromJson(
                r,
                leaveTypeName: typeNames[r['leave_type_id'] as String?],
              ))
          .toList();
    } catch (e) {
      Logger.error('Error fetching leave requests: $e');
      rethrow;
    }
  }

  /// Verilen satırlardaki `leave_type_id`'ler için görünen adları çöz.
  Future<Map<String, String>> _resolveLeaveTypeNames(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = rows
        .map((r) => r['leave_type_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return {};

    try {
      final response = await _supabase
          .from('leave_types')
          .select('id, name')
          .inFilter('id', ids);
      final result = <String, String>{};
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final id = row['id'] as String?;
        final name = row['name'] as String?;
        if (id != null && name != null) result[id] = name;
      }
      return result;
    } catch (e) {
      // Ad çözümü kritik değil — boş dön, satırlar id ile gösterilir.
      Logger.warning('Failed to resolve leave type names: $e');
      return {};
    }
  }

  /// Yöneticinin bekleyen izin onay kuyruğu — `fn_hr_pending_leave_approvals()`
  /// (jsonb döner).
  ///
  /// NOT: Bu RPC yalnızca görüntüleme alanları döner (start_date, end_date,
  /// day_count, staff, leave_type) — **karar için bir id İÇERMEZ**. Onay/ret
  /// işlemi için ayrıca [decideLeave] kullanılır; approvalStepId başka bir
  /// kaynaktan (form_approval_steps) sağlanmalıdır.
  Future<List<Map<String, dynamic>>> pendingLeaveApprovals() async {
    try {
      final response = await _supabase
          .rpc('fn_hr_pending_leave_approvals');

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      }
      if (response is Map<String, dynamic>) {
        final data = response['data'];
        if (data is List) return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      Logger.error('Error fetching pending leave approvals: $e');
      rethrow;
    }
  }

  /// İzin/onay adımına karar ver — `approval-decision` Edge Function.
  ///
  /// EF gövdesi canlı EF kaynağından doğrulandı:
  ///   `{ approvalStepId, decision: 'approved' | 'rejected', note? }`
  /// (reddederken `note` zorunludur; EF `ERR_VALIDATION` döner). Zarf:
  /// başarı → `{ success: true, data }`, hata → non-2xx +
  /// `{ error: { code, message } }`.
  Future<void> decideLeave({
    required String approvalId,
    required bool approve,
    String? note,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'approval-decision',
        body: {
          'approvalStepId': approvalId,
          'decision': approve ? 'approved' : 'rejected',
          'note': note,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['success'] == false || data['error'] != null) {
          final error = data['error'];
          final message =
              error is Map ? error['message'] : (error ?? 'unknown error');
          throw Exception('approval-decision failed: $message');
        }
        return;
      }
      // Beklenmeyen ama non-throwing gövde — başarı say (2xx döndü).
    } catch (e) {
      Logger.error('Error deciding leave approval: $e');
      rethrow;
    }
  }

  // ============================================
  // PAYROLL
  // ============================================

  /// Kullanıcının bordroları — `payslips` (RLS owner-scoped).
  Future<List<Payslip>> myPayslips({int limit = 24}) async {
    try {
      final staffId = await currentStaffId();
      if (staffId == null) return [];

      final response = await _supabase
          .from('payslips')
          .select()
          .eq('staff_id', staffId)
          .order('period_year', ascending: false)
          .order('period_month', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => Payslip.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching payslips: $e');
      rethrow;
    }
  }

  // ============================================
  // ATTENDANCE (PDKS)
  // ============================================

  /// Puantaj aralığı — `fn_pdks_range(p_tenant, p_staff, p_from, p_to)`.
  Future<List<PdksDay>> pdksRange(DateTime from, DateTime to) async {
    try {
      final staffId = await currentStaffId();
      final tenantId = _tenant.currentTenantId;
      if (staffId == null || tenantId == null) return [];

      final response = await _supabase.rpc(
        'fn_pdks_range',
        params: {
          'p_tenant': tenantId,
          'p_staff': staffId,
          'p_from': _fmtDate(from),
          'p_to': _fmtDate(to),
        },
      );

      return (response as List)
          .map((e) => PdksDay.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching pdks range: $e');
      rethrow;
    }
  }

  /// `yyyy-MM-dd` biçimi (RPC date parametreleri için).
  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  // ============================================
  // PERFORMANCE (self-service, salt-okuma v1)
  // ============================================

  /// Kullanıcının kendi performans hedefleri — `employee_goals`
  /// (RLS + `staff_id` ile sahibi-kapsamlı). Web `PerformanceService.getMyGoals`
  /// ile birebir aynı okuma: `staff_id = benim staff'ım`, `performance_cycles(name)`
  /// embed'i dönem adını taşır.
  ///
  /// Web okuma davranışıyla tutarlı olarak **hata durumunda `[]` döner**
  /// (UI'a asla fırlatmaz).
  Future<List<EmployeeGoal>> myGoals({int limit = 100}) async {
    try {
      final staffId = await currentStaffId();
      if (staffId == null) return [];

      var query = _supabase
          .from('employee_goals')
          .select(
            'id,tenant_id,cycle_id,staff_id,organization_id,manager_staff_id,'
            'title,description,weight,progress,status,active,'
            'performance_cycles(name)',
          )
          .eq('staff_id', staffId);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((e) => EmployeeGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching my goals: $e');
      return [];
    }
  }

  /// Kullanıcının kendi performans değerlendirmeleri — `performance_reviews`
  /// (RLS + `staff_id` ile değerlendirilen=ben kapsamı). Web
  /// `PerformanceService.getMyReviews` ile birebir aynı okuma; embed'ler dönem
  /// adını ve değerlendiren (yönetici) adını taşır.
  ///
  /// Web okuma davranışıyla tutarlı olarak **hata durumunda `[]` döner**.
  Future<List<PerformanceReview>> myReviews({int limit = 100}) async {
    try {
      final staffId = await currentStaffId();
      if (staffId == null) return [];

      var query = _supabase
          .from('performance_reviews')
          .select(
            'id,tenant_id,cycle_id,staff_id,reviewer_staff_id,organization_id,'
            'self_rating,manager_rating,overall_rating,self_comments,'
            'manager_comments,status,decided_at,active,created_at,'
            'performance_cycles(name),'
            'reviewer:staffs!performance_reviews_reviewer_staff_id_fkey('
            'name,first_name,last_name)',
          )
          .eq('staff_id', staffId);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return (response as List)
          .map((e) => PerformanceReview.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching my reviews: $e');
      return [];
    }
  }

  // ============================================
  // ONBOARDING
  // ============================================

  /// Kullanıcının oryantasyon görevleri — `fn_hr_my_onboarding_tasks()`.
  Future<List<OnboardingTask>> myOnboardingTasks() async {
    try {
      final response = await _supabase
          .rpc('fn_hr_my_onboarding_tasks');

      return (response as List)
          .map((e) => OnboardingTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('Error fetching onboarding tasks: $e');
      rethrow;
    }
  }

  /// Bir oryantasyon görevinin durumunu değiştirir (yaz).
  ///
  /// Web ESS "Oryantasyonum" ekranıyla **birebir** aynı backend sözleşmesi:
  ///   `fn_hr_onboarding_task_set_status(p_task_id, p_status, p_notes)`
  /// (web `my-onboarding.component.ts` — `client.rpc('fn_hr_onboarding_task_set_status', …)`).
  ///
  /// [taskId] `staff_onboarding_tasks.id` — okuma modelinde
  /// [OnboardingTask.taskId] alanı (dikkat: `instanceId` DEĞİL). RPC
  /// `auth.uid()` üzerinden kendi görevlerine kapsanır (RLS/SECDEF), bu yüzden
  /// doğrudan tablo yazımı yerine RPC kullanılır.
  ///
  /// [done] `true` → durum `'done'` (Tamamlandı); `false` → durum `'pending'`
  /// (geri al / yeniden aç) — web admin "reopen" akışıyla aynı `p_status`
  /// parametresi.
  ///
  /// Dönüş: RPC gövdesindeki `instance_completed` (bu görevle birlikte üst
  /// oryantasyon örneğinin de kapandığını gösterir); alan yoksa `false`.
  Future<bool> completeOnboardingTask(
    String taskId, {
    bool done = true,
  }) async {
    try {
      final response = await _supabase.rpc(
        'fn_hr_onboarding_task_set_status',
        params: {
          'p_task_id': taskId,
          'p_status': done ? 'done' : 'pending',
          'p_notes': null,
        },
      );

      if (response is Map<String, dynamic>) {
        return response['instance_completed'] as bool? ?? false;
      }
      return false;
    } catch (e) {
      Logger.error('Error setting onboarding task status: $e');
      rethrow;
    }
  }
}

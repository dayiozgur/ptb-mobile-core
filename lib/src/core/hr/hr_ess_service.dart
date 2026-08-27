import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/attendance_record_row.dart';
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

/// Offline kuyruğunda izin-talebi oluşturma işlemleri için op-tipi anahtarı
/// (OfflineSyncService handler'ı bununla kayıtlanır ve tetiklenir).
const String kLeaveRequestCreateOpType = 'leave_request_create';

/// Offline kuyruğunda PDKS giriş-punch'ı için op-tipi anahtarı. Çevrimdışı
/// yapılan giriş, client-timestamp korunarak kuyruğa alınır; online olunca
/// `attendance_records`'a INSERT edilir. (Çıkış ve geo-punch offline DEĞİL —
/// çıkış read-modify-write, geo-punch sunucu-taraflı mesafe doğrulaması ister.)
const String kPunchCreateOpType = 'attendance_punch_create';

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

  // Offline-queue erişimi (kayıtlı/başlatılmış değilse null → doğrudan ağ path).
  ConnectivityService? get _connectivityOrNull =>
      sl.isRegistered<ConnectivityService>()
          ? sl<ConnectivityService>()
          : null;

  OfflineSyncService? get _offlineSyncOrNull {
    if (!sl.isRegistered<OfflineSyncService>()) return null;
    final s = sl<OfflineSyncService>();
    return s.isInitialized ? s : null;
  }

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

  /// Yeni bir izin talebi oluştur (`leave_requests` INSERT).
  ///
  /// Web `LeaveService.insertRequest` ile **birebir** aynı sözleşme:
  /// `tenant_id`, `staff_id`, `leave_type_id`, `start_date`, `end_date`,
  /// `half_day_start`, `half_day_end`, `note`, `status='pending'`, `created_by`.
  /// `day_count` DB tarafında hesaplanır (client yazmaz). Onay/yetki/bakiye
  /// kontrolleri DB tetikleyicilerince yürütülür.
  ///
  /// OFFLINE fallback: bağlantı yoksa işlem kuyruğa alınır ve iyimser
  /// (optimistic) olarak `{queued:true, offline:true}` dönülür; online olunca
  /// OfflineSyncService bunu [replayCreateLeave] üzerinden yeniden oynatır.
  /// Online path DEĞİŞMEDİ.
  Future<Map<String, dynamic>> createLeaveRequest({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    bool halfDayStart = false,
    bool halfDayEnd = false,
    String? note,
  }) async {
    final staffId = await currentStaffId();
    if (staffId == null) {
      throw Exception('No staff row for current user; cannot create leave');
    }
    final tenantId = _tenant.currentTenantId;
    final userId = _supabase.auth.currentUser?.id;

    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'staff_id': staffId,
      'leave_type_id': leaveTypeId,
      'start_date': _fmtDate(startDate),
      'end_date': _fmtDate(endDate),
      'half_day_start': halfDayStart,
      'half_day_end': halfDayEnd,
      'note': note,
      'status': 'pending',
      'created_by': userId,
    };

    final sync = _offlineSyncOrNull;
    if (sync != null && (_connectivityOrNull?.isOffline ?? false)) {
      final op = await sync.addOperation(
        type: PendingOperationType.create,
        entityType: kLeaveRequestCreateOpType,
        data: payload,
      );
      Logger.info('Offline: leave request queued (${op.id})');
      return {'queued': true, 'offline': true, 'opId': op.id};
    }

    return _insertLeaveRequest(payload);
  }

  /// Gerçek ağ yazımı (`leave_requests` INSERT). Online path burada; offline
  /// kuyruk replay'i de doğrudan bunu çağırır.
  Future<Map<String, dynamic>> _insertLeaveRequest(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _supabase
          .from('leave_requests')
          .insert(payload)
          .select()
          .single();
      return response;
    } catch (e) {
      Logger.error('Error creating leave request: $e');
      rethrow;
    }
  }

  /// Offline kuyruk replay handler'ı: kaydedilmiş payload ile izin talebini
  /// yeniden oynatır. Başarıda `true` döner; hata fırlatırsa retry/dead-letter
  /// mantığı devreye girer.
  ///
  /// Idempotency notu: `leave_requests` için backend'de kalıcı bir dedupe
  /// anahtarı YOK (şema değişikliği kapsam dışı); ağ yazımı başarılı olup
  /// yanıt kaybolursa (kuyruktan silinmeden önce) gecikmiş bir replay KOPYA
  /// talep yaratabilir. Birincil koruma kuyruğun başarı→sil davranışıdır.
  Future<bool> replayCreateLeave(PendingOperation op) async {
    await _insertLeaveRequest(Map<String, dynamic>.from(op.data));
    return true;
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
  /// Dönen her satır artık `id` (=`leave_requests.id`) taşır; bu id [decideLeave]
  /// için doğrudan karar anahtarıdır. Diğer alanlar salt-görüntüleme: start_date,
  /// end_date, day_count, staff, leave_type.
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

  /// Bir izin talebine onay/ret kararı ver.
  ///
  /// Web `LeaveService.decide` ile **birebir** aynı sözleşme: `leave_requests`
  /// tablosuna doğrudan UPDATE (`status='approved'|'rejected'`, `updated_at`,
  /// reddederken `decision_note`). Onay yetkisi (yalnızca atanmış onaylayan /
  /// yöneticinin karar verebilmesi), `approver_staff_id` + `decided_at` dolumu ve
  /// bakiye/çakışma kontrolleri DB tetikleyicilerince (`fn_leave_on_decision`,
  /// `fn_leave_guard_update`) yetkeyle yürütülür; bu yüzden EF/RPC gerekmez —
  /// web ile aynı yolu izleriz. (Not: `approval-decision` EF `form_approval_steps`
  /// üzerinde çalışır ve izin taleplerinde böyle bir adım OLUŞMAZ; leave o kapıyı
  /// kullanmaz.)
  ///
  /// [leaveRequestId] `leave_requests.id` — `pendingLeaveApprovals()` satırındaki
  /// `id`. Reddederken [note] zorunludur (web: min 3 karakter). Hata durumunda
  /// tetikleyicinin RAISE mesajı (yetki/bakiye) yukarı fırlatılır.
  Future<void> decideLeave({
    required String leaveRequestId,
    required bool approve,
    String? note,
  }) async {
    try {
      final patch = <String, dynamic>{
        'status': approve ? 'approved' : 'rejected',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // Karar/ret notunu AYRI kolona yaz — talep sahibinin kendi notunu ASLA
      // ezmez (web ile aynı davranış).
      if (note != null) patch['decision_note'] = note;

      await _supabase
          .from('leave_requests')
          .update(patch)
          .eq('id', leaveRequestId);
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

  /// **Manuel PDKS giriş/çıkış** — bugünün `attendance_records` satırını bulur:
  /// yoksa `entry_time` yazar (giriş), varsa+`exit_time` boşsa `exit_time`
  /// yazar (çıkış). `source='manual'` (RLS own-staff için bunu pin'ler;
  /// geofence source='geo' SECDEF RPC gerektirir). Geofence kullanılamadığında
  /// (izin yok/menzil dışı) ESS-fallback.
  ///
  /// Döner: `'in'` (giriş) · `'out'` (çıkış) · `'done'` (bugün zaten tamam).
  Future<String> manualPunch() async {
    final staffId = await currentStaffId();
    if (staffId == null) throw Exception('Personel kaydı bulunamadı');
    final tenantId = _tenant.currentTenantId;
    final uid = _supabase.auth.currentUser?.id;
    final now = DateTime.now();
    final workDate = _fmtDate(now);
    final nowUtc = now.toUtc().toIso8601String();

    // OFFLINE: bağlantı yoksa GİRİŞ punch'ını kuyruğa al (client-timestamp =
    // çevrimdışı-an korunur). Read-modify-write burada yapılamaz (canlı okuma
    // yok) → koşulsuz INSERT modeli: yeni entry satırı. Çıkış için online şart
    // (fn_pdks_range çoklu-döngü topladığından ekstra satır zararsız). Online
    // olunca [replayPunch] payload'ı aynen INSERT eder.
    final sync = _offlineSyncOrNull;
    if (sync != null && (_connectivityOrNull?.isOffline ?? false)) {
      final payload = <String, dynamic>{
        'tenant_id': tenantId,
        'staff_id': staffId,
        'work_date': workDate,
        'entry_time': nowUtc,
        'source': 'manual',
        'created_by': uid,
      };
      final op = await sync.addOperation(
        type: PendingOperationType.create,
        entityType: kPunchCreateOpType,
        entityId: staffId,
        data: payload,
      );
      Logger.info('Offline: punch (giriş) queued (${op.id})');
      return 'queued_in';
    }

    final existing = await _supabase
        .from('attendance_records')
        .select('id, entry_time, exit_time')
        .eq('staff_id', staffId)
        .eq('work_date', workDate)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('attendance_records').insert({
        'tenant_id': tenantId,
        'staff_id': staffId,
        'work_date': workDate,
        'entry_time': nowUtc,
        'source': 'manual',
        'created_by': uid,
      });
      return 'in';
    }
    if (existing['entry_time'] == null) {
      await _supabase.from('attendance_records').update(
          {'entry_time': nowUtc, 'updated_by': uid}).eq('id', existing['id']);
      return 'in';
    }
    if (existing['exit_time'] == null) {
      final entry = DateTime.tryParse(existing['entry_time'].toString());
      final worked = entry != null
          ? now.toUtc().difference(entry.toUtc()).inMinutes
          : null;
      await _supabase.from('attendance_records').update({
        'exit_time': nowUtc,
        if (worked != null && worked >= 0) 'worked_minutes': worked,
        'updated_by': uid,
      }).eq('id', existing['id']);
      return 'out';
    }
    return 'done';
  }

  /// Gerçek ağ yazımı (`attendance_records` INSERT) — offline punch replay'i
  /// buraya düşer. Saf INSERT (read-modify-write DEĞİL): kuyruğa alınmış
  /// giriş satırını olduğu gibi yazar.
  Future<void> _insertPunchToNetwork(Map<String, dynamic> payload) async {
    await _supabase.from('attendance_records').insert(payload);
  }

  /// Offline kuyruk replay handler'ı: çevrimdışı yapılmış giriş-punch'ını
  /// (client-timestamp korunarak) yeniden oynatır. Başarıda `true`.
  ///
  /// Idempotency notu: `attendance_records` için kalıcı dedupe anahtarı YOK;
  /// yanıt kaybolursa gecikmiş replay kopya satır yaratabilir — fn_pdks_range
  /// çoklu-döngü topladığından zararsız, birincil koruma kuyruğun başarı→sil'i.
  Future<bool> replayPunch(PendingOperation op) async {
    await _insertPunchToNetwork(Map<String, dynamic>.from(op.data));
    return true;
  }

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

  /// Belirli bir **günün** ham giriş/çıkış hareketleri (attendance_records) —
  /// gün detayında birden fazla giriş/çıkış döngüsünü tek tek listelemek için.
  /// RLS ile sahibi-kapsamlı; hata durumunda `[]` (UI'a fırlatmaz).
  Future<List<AttendanceRecordRow>> pdksDayPunches(DateTime? day) async {
    try {
      if (day == null) return [];
      final staffId = await currentStaffId();
      if (staffId == null) return [];
      final d = _fmtDate(day);
      final rows = await _supabase
          .from('attendance_records')
          .select(
              'id, staff_id, work_date, entry_time, exit_time, worked_minutes, source, location, note')
          .eq('staff_id', staffId)
          .eq('work_date', d)
          .order('entry_time', ascending: true);
      return (rows as List)
          .map((e) => AttendanceRecordRow.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      Logger.error('pdksDayPunches: $e');
      return [];
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

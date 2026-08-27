import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/payroll_adjustment.dart';
import 'models/payroll_cost_row.dart';
import 'models/payroll_helpers.dart';
import 'models/payroll_parameter.dart';
import 'models/payroll_run.dart';
import 'models/payroll_run_payslip.dart';
import 'models/payroll_salary.dart';
import 'models/pushable_submission.dart';

/// Admin Bordro (Payroll) yönetim ekranları için salt-okuma veri servisi.
///
/// Web `PayrollService` (libs/@ptb/hr-management/.../payroll/services) okuma
/// yollarını birebir aynalar (aynı Supabase projesi). Yazma / çalıştırma
/// (fn_calculate_payroll_run vb.) mobil v1 KAPSAM DIŞI — yalnız görüntüleyici.
///
/// Tenant kapsamı RLS ile sağlanır; ek olarak elde `tenant_id` varsa
/// sorgu `tenant_id` eşitliği ile daraltılır (web ile aynı davranış). Tüm
/// metodlar hata durumunda **rethrow** eder (sessiz-boş DÖNMEZ) — böylece
/// ekranlar gerçek hatayı gösterebilir.
///
/// Personel adları PostgREST FK-hint embed ile açık constraint adı üzerinden
/// çözülür (`staffs!payroll_salaries_staff_id_fkey` vb.), web select'leriyle
/// aynı — `staffs`'taki ikili FK belirsizliğinden kaçınmak için.
class AdminPayrollService {
  final SupabaseClient _supabase;

  AdminPayrollService({required SupabaseClient supabase})
      : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  // Web select sabitlerinin aynası (yalnızca okunan kolonlar).
  static const String _runSelect =
      'id,tenant_id,period_year,period_month,label,status,'
      'calculated_at,approved_at,active';

  static const String _runPayslipSelect =
      'id,tenant_id,run_id,staff_id,period_year,period_month,'
      'gross_salary,net_salary,net_payable,'
      'staffs!payslips_staff_id_fkey(name,first_name,last_name)';

  static const String _salarySelect =
      'id,tenant_id,staff_id,gross_monthly,currency,active,'
      'staffs!payroll_salaries_staff_id_fkey(name,first_name,last_name)';

  static const String _parameterSelect =
      'id,tenant_id,year,sgk_employee_rate,unemployment_employee_rate,'
      'sgk_employer_rate,unemployment_employer_rate,stamp_tax_rate,'
      'sgk_floor,sgk_ceiling,minimum_wage_gross,income_tax_brackets,notes,active';

  static const String _adjustmentSelect =
      'id,tenant_id,staff_id,run_id,period_year,period_month,source_type,'
      'source_ref,kind,amount,source_total,installment_amount,installment_no,'
      'status,description,created_at,applied_at,'
      'staffs!payroll_adjustments_staff_id_fkey(name,first_name,last_name)';

  // ============================================
  // RUNS
  // ============================================

  /// Bordro çalıştırmaları (`payroll_runs`) — tenant-kapsamlı, dönem azalan.
  /// Web `PayrollService.getRuns` aynası.
  Future<List<PayrollRun>> runs() async {
    try {
      var query = _supabase.from('payroll_runs').select(_runSelect);
      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);

      final response = await query
          .order('period_year', ascending: false)
          .order('period_month', ascending: false);

      return (response as List)
          .map((e) => PayrollRun.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPayrollService.runs hata: $e');
      rethrow;
    }
  }

  /// Bir çalıştırmanın bordro satırları (`payslips`, personel adı embed).
  /// Web `PayrollService.getPayslips` aynası. Salt-okuma detay listesi.
  Future<List<PayrollRunPayslip>> runPayslips(String runId) async {
    try {
      var query = _supabase
          .from('payslips')
          .select(_runPayslipSelect)
          .eq('run_id', runId);
      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);

      final response = await query.order('created_at', ascending: true);

      return (response as List)
          .map((e) => PayrollRunPayslip.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPayrollService.runPayslips hata: $e');
      rethrow;
    }
  }

  // ============================================
  // SALARIES
  // ============================================

  /// Maaş tanımları (`payroll_salaries`, personel adı embed) — tenant-kapsamlı.
  /// Web `PayrollService.getSalaries` aynası.
  ///
  /// HASSAS: brüt maaş rakamı yalnız RLS/grants ile yetkilendirilen (admin)
  /// kullanıcıya döner; tablonun `authenticated`'a açtığı kolonlar okunur.
  Future<List<PayrollSalary>> salaries() async {
    try {
      var query = _supabase.from('payroll_salaries').select(_salarySelect);
      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((e) => PayrollSalary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPayrollService.salaries hata: $e');
      rethrow;
    }
  }

  // ============================================
  // PARAMETERS
  // ============================================

  /// Bordro parametreleri (`payroll_parameters`) — kendi tenant satırları VE
  /// paylaşımlı global varsayılan (tenant_id null). Yıl azalan.
  /// Web `PayrollService.getParameters` aynası.
  Future<List<PayrollParameter>> parameters() async {
    try {
      var query = _supabase.from('payroll_parameters').select(_parameterSelect);
      final tenantId = _tenant.currentTenantId;
      // Kendi tenant satırları VEYA global varsayılan (tenant_id null).
      if (tenantId != null) {
        query = query.or('tenant_id.eq.$tenantId,tenant_id.is.null');
      }

      final response = await query.order('year', ascending: false);

      return (response as List)
          .map((e) => PayrollParameter.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPayrollService.parameters hata: $e');
      rethrow;
    }
  }

  // ============================================
  // ADJUSTMENTS
  // ============================================

  /// Bordro ek/kesintileri (`payroll_adjustments`, personel adı embed) —
  /// tenant-kapsamlı, oluşturma azalan. Web `PayrollService.getAdjustments`
  /// aynası.
  Future<List<PayrollAdjustment>> adjustments() async {
    try {
      var query =
          _supabase.from('payroll_adjustments').select(_adjustmentSelect);
      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((e) => PayrollAdjustment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminPayrollService.adjustments hata: $e');
      rethrow;
    }
  }

  // ============================================
  // PUSHABLE SUBMISSIONS (bordroya bekleyenler)
  // ============================================

  /// Bordroya itilebilir (onaylı) avans/masraf başvuruları. Web
  /// `PayrollService.getPushableSubmissions` istemci-okumasının **birebir**
  /// aynası (3 sorgu + eleme):
  ///   1. `form_submissions` (entity_type `hr_advance`/`hr_expense`, active).
  ///   2. `payroll_adjustments` (`status <> 'cancelled'`) → `source_ref` seti;
  ///      bir başvuru zaten itilmişse listeden ELENİR (çift-itme guard'ı).
  ///   3. `staffs` (`profile_id in submitted_by`) → başvuran adı eşlemesi.
  ///
  /// Statü literaline göre filtre YOK — statü rozet olarak gösterilir, itme
  /// kararını admin verir. Hata → `[]` (inbox'ı çökertmemek için sessiz-boş;
  /// diğer salt-okuma metodlarının rethrow deseninden bilinçli ayrılır).
  Future<List<PushableSubmission>> getPushableSubmissions() async {
    try {
      final tenantId = _tenant.currentTenantId;

      // 1) Aday başvurular.
      var subQuery = _supabase
          .from('form_submissions')
          .select(
              'id,entity_type,status,code,subject,metadata,submitted_by,active')
          .inFilter('entity_type', const ['hr_advance', 'hr_expense'])
          .eq('active', true);
      if (tenantId != null) subQuery = subQuery.eq('tenant_id', tenantId);
      final subs = await subQuery.order('created_at', ascending: false);

      // 2) Zaten itilmiş (iptal edilmemiş) başvuru referansları.
      var adjQuery = _supabase
          .from('payroll_adjustments')
          .select('source_ref,status')
          .neq('status', 'cancelled');
      if (tenantId != null) adjQuery = adjQuery.eq('tenant_id', tenantId);
      final adjs = await adjQuery;

      // 3) Başvuran adları (submitted_by → staffs.profile_id).
      final submitterIds = <String>{
        for (final r in (subs as List))
          if ((r as Map)['submitted_by'] != null)
            r['submitted_by'].toString(),
      }.toList();

      List<dynamic> staffRows = const [];
      if (submitterIds.isNotEmpty) {
        var staffQuery = _supabase
            .from('staffs')
            .select('profile_id,name,first_name,last_name')
            .inFilter('profile_id', submitterIds);
        if (tenantId != null) staffQuery = staffQuery.eq('tenant_id', tenantId);
        staffRows = await staffQuery as List;
      }

      return mapPushableSubmissions(
        submissions: subs,
        adjustments: adjs as List,
        staffs: staffRows,
      );
    } catch (e) {
      Logger.error('AdminPayrollService.getPushableSubmissions hata: $e');
      return const [];
    }
  }

  /// Saf mapper — 3 ham sorgu sonucundan itilebilir başvuru listesini üretir.
  /// Test-edilebilir (Supabase'e bağımsız). Web mantığının aynası: itilmiş
  /// (`source_ref` ∈ taken) başvurular elenir; `submitterName` staffs'tan
  /// (`name ?? '<first> <last>'`); `amount` = `metadata.amount`.
  static List<PushableSubmission> mapPushableSubmissions({
    required List<dynamic> submissions,
    required List<dynamic> adjustments,
    required List<dynamic> staffs,
  }) {
    final taken = <String>{
      for (final a in adjustments)
        if ((a as Map)['source_ref'] != null) a['source_ref'].toString(),
    };

    final nameByProfile = <String, String>{};
    for (final s in staffs) {
      if (s is! Map) continue;
      final pid = s['profile_id']?.toString();
      if (pid == null) continue;
      final full = _staffFullName(s);
      if (full != null) nameByProfile[pid] = full;
    }

    final result = <PushableSubmission>[];
    for (final r in submissions) {
      if (r is! Map) continue;
      final id = r['id']?.toString();
      if (id == null) continue;
      final ref = id; // adjustment.source_ref = form_submission.id
      if (taken.contains(ref)) continue;

      final meta = r['metadata'];
      final amount =
          meta is Map ? payrollNum(meta['amount']) : payrollNum(null);
      final submittedBy = r['submitted_by']?.toString();

      result.add(PushableSubmission(
        id: id,
        entityType: (r['entity_type'] as String?) ?? 'hr_advance',
        status: (r['status'] as String?) ?? 'pending',
        code: r['code'] as String?,
        subject: r['subject'] as String?,
        amount: amount,
        submitterName:
            submittedBy == null ? null : nameByProfile[submittedBy],
      ));
    }
    return result;
  }

  /// Başvuran görünen adı — web `getPushableSubmissions` önceliği:
  /// `name ?? '<first> <last>'` (name önce; boşsa ad+soyad).
  static String? _staffFullName(Map s) {
    final name = (s['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final first = (s['first_name'] as String?)?.trim() ?? '';
    final last = (s['last_name'] as String?)?.trim() ?? '';
    final full = [first, last].where((e) => e.isNotEmpty).join(' ');
    return full.isEmpty ? null : full;
  }

  // ============================================
  // COST SUMMARY
  // ============================================

  /// Maliyet özeti — sunucu-taraflı boyutsal RPC `fn_payroll_cost_rollup`
  /// (SECURITY INVOKER; RLS ile admin=tüm tenant). Web
  /// `PayrollService.getCostRollup` aynası — client tarafında toplama YOK,
  /// döküm satırları sunucudan gelir.
  ///
  /// Varsayılan aralık web ekranıyla aynı: [fromDate] = yılın 1 Ocak'ı,
  /// [toDate] = bugün; [dimension] `month` (aylık) | `department` (departman).
  Future<PayrollCostSummary> costSummary({
    String? fromDate,
    String? toDate,
    String dimension = 'month',
  }) async {
    final now = DateTime.now();
    final from = fromDate ?? '${now.year}-01-01';
    final to = toDate ?? _fmtDate(now);

    try {
      final response = await _supabase.rpc(
        'fn_payroll_cost_rollup',
        params: {
          'p_from': from,
          'p_to': to,
          'p_dimension': dimension,
        },
      );

      final rows = (response as List)
          .map((e) => PayrollCostRow.fromJson(e as Map<String, dynamic>))
          .toList();

      return PayrollCostSummary(
        rows: rows,
        fromDate: from,
        toDate: to,
        dimension: dimension,
      );
    } catch (e) {
      Logger.error('AdminPayrollService.costSummary hata: $e');
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
}

/// DI erişim kısayolu — kayıt `service_locator.dart` içinde yapılır.
AdminPayrollService get adminPayrollService => sl<AdminPayrollService>();

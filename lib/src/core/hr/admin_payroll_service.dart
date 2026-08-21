import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/payroll_adjustment.dart';
import 'models/payroll_cost_row.dart';
import 'models/payroll_parameter.dart';
import 'models/payroll_run.dart';
import 'models/payroll_run_payslip.dart';
import 'models/payroll_salary.dart';

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

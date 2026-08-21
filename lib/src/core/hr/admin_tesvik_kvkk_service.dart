import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/arge_report_row.dart';
import 'models/kvkk_overview_row.dart';
import 'models/tesvik_accrual_row.dart';
import 'models/tesvik_rule_row.dart';

/// PHR yönetim (admin) teşvik / Ar-Ge / KVKK **salt-okuma** veri katmanı.
///
/// PHR mobil yönetim ekranlarını besler:
///   • [tesvikRecords] → `/admin/tesvik`         (Teşvikler — SGK/Ar-Ge)
///   • [tesvikRules]   → `/admin/tesvik/rules`   (Teşvik Kuralları)
///   • [argeReports]   → `/admin/arge-reports`   (Ar-Ge Raporları)
///   • [kvkkOverview]  → `/admin/kvkk`           (KVKK Yönetimi — org-geneli)
///
/// Web okuma sözleşmeleri (aynı Supabase projesi):
///   • [tesvikRecords] ↔ `TesvikService.getAccruals` (`ACCRUAL_SELECT`,
///     `tesvik_accruals` + `staffs` embed) — dönem zorlanmaz, en yeni dönem önce.
///   • [tesvikRules]   ↔ `TesvikService.listRules` (`RULE_SELECT`,
///     `tesvik_rules`) — tenant satırları + global (`tenant_id` null) kurallar.
///   • [argeReports]   ↔ `dr_data_sources.code = 'arge-puantaj-summary'`
///     (Ar-Ge B6): Ar-Ge personelinin (`staffs.is_arge_personnel`) aylık
///     `puantaj_sheets` Ar-Ge/toplam saat icmali; rapor motoru yerine tablo
///     doğrudan okunur (inner-join filtresi).
///   • [kvkkOverview]  ↔ `KvkkService` / `KvkkAdminService`: rıza kataloğu
///     (`kvkk_consent_types`) + tip başına rıza veren (granted) tekil personel
///     sayısı (`kvkk_consents`), toplam aktif personele (`staffs`) oranlanır.
///
/// Tenant kapsamı RLS ile sağlanır; ek olarak `TenantService.currentTenantId`
/// biliniyorsa sorgu `tenant_id` ile daraltılır (web ile aynı davranış).
/// Hata durumunda [Logger.error] + `rethrow` — ekran gerçek hatayı gösterir.
///
/// Yazma YOK — v1 salt-okuma viewer.
class AdminTesvikKvkkService {
  final SupabaseClient _supabase;

  AdminTesvikKvkkService({required SupabaseClient supabase})
      : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  /// Web `TesvikService.ACCRUAL_SELECT` — personel adı için `staffs` FK-embed.
  static const String _accrualSelect =
      'id,tenant_id,regime,staff_id,organization_id,period_year,period_month,'
      'rule_code,title_category,arge_hours,fte,base_amount,incentive_amount,'
      'rule_id,source_sheet_id,status,calculated_at,'
      'staffs!tesvik_accruals_staff_id_fkey(name,first_name,last_name)';

  /// Web `TesvikService.RULE_SELECT`.
  static const String _ruleSelect =
      'id,tenant_id,regime,rule_code,title_category,effective_from,effective_to,'
      'rate,cap_pct,params,active,created_at,updated_at';

  // ============================================
  // TEŞVİKLER — tahakkuklar (tesvik_accruals)
  // ============================================

  /// Teşvik tahakkuk kayıtları (SGK/Ar-Ge) — `tesvik_accruals`, en yeni dönem
  /// önce (`period_year` ↓, `period_month` ↓, `rule_code`). Web
  /// `TesvikService.getAccruals` ile aynı okuma; mobil v1 dönem seçmez, son
  /// kayıtları listeler.
  Future<List<TesvikAccrualRow>> tesvikRecords({int limit = 200}) async {
    try {
      var query = _supabase.from('tesvik_accruals').select(_accrualSelect);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query
          .order('period_year', ascending: false)
          .order('period_month', ascending: false)
          .order('rule_code')
          .limit(limit);

      return (response as List)
          .map((e) => TesvikAccrualRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminTesvikKvkkService.tesvikRecords hata: $e');
      rethrow;
    }
  }

  // ============================================
  // TEŞVİK KURALLARI (tesvik_rules)
  // ============================================

  /// Teşvik oran kuralları — tenant satırları + global (`tenant_id` null)
  /// paylaşımlı kurallar; `rule_code`, `title_category`, `effective_from` ↓
  /// sıralı. Web `TesvikService.listRules` okumasının global'i de kapsayan
  /// mobil karşılığı.
  Future<List<TesvikRuleRow>> tesvikRules() async {
    try {
      var query = _supabase.from('tesvik_rules').select(_ruleSelect);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.or('tenant_id.eq.$tenantId,tenant_id.is.null');
      }

      final response = await query
          .order('rule_code')
          .order('title_category')
          .order('effective_from', ascending: false);

      return (response as List)
          .map((e) => TesvikRuleRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminTesvikKvkkService.tesvikRules hata: $e');
      rethrow;
    }
  }

  // ============================================
  // AR-GE RAPORLARI (arge-puantaj-summary)
  // ============================================

  /// Ar-Ge Puantaj İcmal — Ar-Ge personelinin (`staffs.is_arge_personnel`)
  /// aylık `puantaj_sheets` Ar-Ge / toplam saat icmali; en yeni dönem önce.
  /// Web `dr_data_sources 'arge-puantaj-summary'` içeriğiyle aynı; mobil v1
  /// rapor motoru yerine tabloyu doğrudan (inner-join filtresi) okur.
  Future<List<ArgeReportRow>> argeReports({int limit = 200}) async {
    try {
      var query = _supabase
          .from('puantaj_sheets')
          .select(
            'id,staff_id,period_year,period_month,total_arge_hours,total_hours,'
            'staffs!inner(name,first_name,last_name,is_arge_personnel)',
          )
          .eq('active', true)
          .eq('staffs.is_arge_personnel', true);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query
          .order('period_year', ascending: false)
          .order('period_month', ascending: false)
          .limit(limit);

      return (response as List)
          .map((e) => ArgeReportRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminTesvikKvkkService.argeReports hata: $e');
      rethrow;
    }
  }

  // ============================================
  // KVKK YÖNETİMİ — org-geneli rıza özeti
  // ============================================

  /// KVKK org-geneli rıza özeti — her aktif rıza tipi (`kvkk_consent_types`,
  /// global + tenant) için rıza veren (granted) tekil personel sayısı
  /// (`kvkk_consents`), toplam aktif personele (`staffs`) oranlanır.
  /// Web `KvkkService` / `KvkkAdminService` ile aynı tablolar; toplama serviste
  /// hesaplanır. Kod sırasına göre döner.
  Future<List<KvkkOverviewRow>> kvkkOverview() async {
    try {
      final tenantId = _tenant.currentTenantId;

      // 1) Rıza kataloğu (aktif) — global + tenant satırları.
      var typeQuery = _supabase
          .from('kvkk_consent_types')
          .select('id,code,name,description,required,version,active')
          .eq('active', true);
      if (tenantId != null) {
        typeQuery = typeQuery.or('tenant_id.eq.$tenantId,tenant_id.is.null');
      }
      final typeRows =
          (await typeQuery.order('code')) as List;

      // 2) Verilmiş (granted) rızalar — tip başına tekil personel say.
      var consentQuery = _supabase
          .from('kvkk_consents')
          .select('consent_type_id,staff_id')
          .eq('granted', true);
      if (tenantId != null) {
        consentQuery = consentQuery.eq('tenant_id', tenantId);
      }
      final consentRows = (await consentQuery) as List;

      final grantedStaffByType = <String, Set<String>>{};
      for (final raw in consentRows) {
        final row = raw as Map<String, dynamic>;
        final typeId = row['consent_type_id']?.toString();
        final staffId = row['staff_id']?.toString();
        if (typeId == null || staffId == null) continue;
        grantedStaffByType.putIfAbsent(typeId, () => <String>{}).add(staffId);
      }

      // 3) Toplam aktif personel (kapsam paydası).
      var staffQuery =
          _supabase.from('staffs').select('id').eq('active', true);
      if (tenantId != null) {
        staffQuery = staffQuery.eq('tenant_id', tenantId);
      }
      final totalStaff = ((await staffQuery) as List).length;

      return typeRows.map((raw) {
        final type = raw as Map<String, dynamic>;
        final typeId = type['id'].toString();
        return KvkkOverviewRow.fromType(
          type,
          grantedCount: grantedStaffByType[typeId]?.length ?? 0,
          totalStaff: totalStaff,
        );
      }).toList();
    } catch (e) {
      Logger.error('AdminTesvikKvkkService.kvkkOverview hata: $e');
      rethrow;
    }
  }
}

/// DI kısayolu — kayıtlı [AdminTesvikKvkkService] örneğini döndürür.
AdminTesvikKvkkService get adminTesvikKvkkService =>
    sl<AdminTesvikKvkkService>();

import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/hr_summary.dart';
import 'models/payslip.dart';
import 'models/staff_profile.dart';

// Yeni İK-profil self-servis modellerini barrel'a (protoolbag_core) aktar:
// barrel bu dosyayı export ettiğinden re-export transitif olarak taşınır.
export 'models/hr_summary.dart';
export 'models/staff_profile.dart';

/// HR Employee-Self-Service — profil + özet veri katmanı.
///
/// PHR mobil uygulamasının "İK Profilim" (`/hr/profile`) ve "İK Özetim"
/// (`/hr/my-hr`) ekranlarını besler. Web `StaffProfileService` +
/// `MyHrHubComponent` ile aynı DB/RPC sözleşmelerini taşır.
///
/// Salt-okuma metodları hata durumunda **rethrow** eder (ekranlar gerçek hatayı
/// gösterir). TEK istisna: [myHrSummary] — birden çok kaynağı toplar ve her
/// parçayı bağımsız yakalayarak nazikçe (0 / null) çöker.
class HrProfileService {
  final SupabaseClient _supabase;

  HrProfileService({required SupabaseClient supabase}) : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  // ============================================
  // PROFILE
  // ============================================

  /// Oturum açmış çalışanın kendi personel kaydı.
  ///
  /// Web `StaffProfileService.getMyProfile` ile birebir: `staffs`'tan
  /// hassas-olmayan kolonlar (positions/departments embed'li) + organizasyon &
  /// yönetici adı takip sorguları + `fn_staff_personnel_get` hassas bloğu.
  /// Kullanıcının staff satırı yoksa `null` döner.
  Future<StaffProfile?> myStaffProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        Logger.warning('HrProfileService.myStaffProfile: no authenticated user');
        return null;
      }

      var query = _supabase.from('staffs').select(
        'id,name,first_name,last_name,title,email,phone,address,town,hire_date,'
        'organization_id,manager_id,gender,marital_status,blood_type,'
        'emergency_contact_name,emergency_contact_phone,emergency_contact_relation,'
        'education_level,military_status,'
        'positions!staffs_position_id_fkey(name),'
        'departments!staffs_department_id_fkey(name)',
      ).eq('profile_id', userId);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);

      final row = await query.maybeSingle();
      if (row == null) {
        Logger.warning(
            'HrProfileService.myStaffProfile: no staff row for profile $userId');
        return null;
      }

      final staffId = row['id'] as String;
      final orgId = row['organization_id'] as String?;
      final managerId = row['manager_id'] as String?;

      // İsim çözümleri paralel; hassas blok ayrı (bağımsız hata toleransı).
      final names = await Future.wait<String?>([
        _lookupOrganizationName(orgId),
        _lookupStaffName(managerId),
      ]);
      final personnel = await _fetchPersonnel(staffId);

      return StaffProfile.fromJson(
        row,
        organizationName: names[0],
        managerName: names[1],
        personnel: personnel,
      );
    } catch (e) {
      Logger.error('Error fetching staff profile: $e');
      rethrow;
    }
  }

  /// Hassas personel bloğu — `fn_staff_personnel_get(p_staff_id)`.
  ///
  /// Web ile aynı sözleşme; RPC tablo döndürdüğü için PostgREST diziye sarar.
  /// GRACEFUL DEGRADE: erişim reddedilirse/hatalıysa `null` döner ki profilin
  /// geri kalanı yine gösterilsin (web'de de personnel ayrı, catchError→null).
  Future<PersonnelData?> _fetchPersonnel(String staffId) async {
    try {
      final data = await _supabase.rpc(
        'fn_staff_personnel_get',
        params: {'p_staff_id': staffId},
      );
      final row = data is List ? (data.isNotEmpty ? data.first : null) : data;
      if (row == null) return null;
      return PersonnelData.fromJson(row as Map<String, dynamic>);
    } catch (e) {
      Logger.error('Error fetching personnel (sensitive) block: $e');
      return null;
    }
  }

  Future<String?> _lookupOrganizationName(String? orgId) async {
    if (orgId == null) return null;
    try {
      final r = await _supabase
          .from('organizations')
          .select('name')
          .eq('id', orgId)
          .maybeSingle();
      return r?['name'] as String?;
    } catch (e) {
      Logger.warning('Failed to resolve organization name: $e');
      return null;
    }
  }

  Future<String?> _lookupStaffName(String? staffId) async {
    if (staffId == null) return null;
    try {
      final r = await _supabase
          .from('staffs')
          .select('name,first_name,last_name')
          .eq('id', staffId)
          .maybeSingle();
      if (r == null) return null;
      final full = [r['first_name'], r['last_name']]
          .where((e) => e != null && (e as String).trim().isNotEmpty)
          .join(' ');
      return full.isNotEmpty ? full : r['name'] as String?;
    } catch (e) {
      Logger.warning('Failed to resolve manager name: $e');
      return null;
    }
  }

  // ============================================
  // SUMMARY (ESS hub)
  // ============================================

  /// "İK Özetim" toplu özeti — mevcut ESS servis metodlarını yeniden kullanır.
  ///
  /// Her parça bağımsız try/catch ile toplanır; biri başarısız olsa da özet
  /// nazikçe (0 / null) döner (dashboard tek bir kaynak yüzünden boş kalmasın).
  Future<HrSummary> myHrSummary() async {
    num leaveRemaining = 0;
    int pendingLeave = 0;
    Payslip? latest;
    int onboardingTotal = 0;
    int onboardingDone = 0;

    try {
      final balances = await hrEssService.leaveBalance();
      for (final b in balances) {
        leaveRemaining += b.remaining;
      }
    } catch (e) {
      Logger.error('HrSummary: leaveBalance failed: $e');
    }

    try {
      final requests = await hrEssService.myLeaveRequests();
      pendingLeave = requests
          .where((r) => (r.status ?? '').toLowerCase() == 'pending')
          .length;
    } catch (e) {
      Logger.error('HrSummary: myLeaveRequests failed: $e');
    }

    try {
      final slips = await hrEssService.myPayslips(limit: 1);
      if (slips.isNotEmpty) latest = slips.first;
    } catch (e) {
      Logger.error('HrSummary: myPayslips failed: $e');
    }

    try {
      final tasks = await hrEssService.myOnboardingTasks();
      onboardingTotal = tasks.length;
      onboardingDone = tasks.where((t) {
        final s = (t.status ?? '').toLowerCase();
        return s == 'done' || s == 'completed';
      }).length;
    } catch (e) {
      Logger.error('HrSummary: myOnboardingTasks failed: $e');
    }

    return HrSummary(
      leaveRemainingDays: leaveRemaining,
      pendingLeaveRequests: pendingLeave,
      latestPayslip: latest,
      onboardingTotal: onboardingTotal,
      onboardingDone: onboardingDone,
    );
  }
}

/// Global erişim (barrel export sonrası ekranlardan `hrProfileService` ile).
HrProfileService get hrProfileService => sl<HrProfileService>();

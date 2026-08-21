import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/admin_leave_request_row.dart';
import 'models/holiday_row.dart';
import 'models/leave_type_row.dart';

/// PHR **admin** (İK yönetim) izin modülü salt-okuma data-layer'ı.
///
/// Web portalının `LeaveService` okuma-yollarını birebir aynalar (aynı Supabase
/// projesi, aynı tablolar): tüm-tenant izin talepleri, izin türleri ve resmi
/// tatiller. ESS `HrEssService` "kendi kayıtlarım" kapsamına karşın bu servis
/// yöneticinin **tüm tenant** görünümünü verir; kapsam RLS + açık `tenant_id`
/// eşitliği ile sağlanır.
///
/// YAZMA YOK — onay/ret kararı mevcut çekirdek metodu `HrEssService.decideLeave`
/// üzerinden verilir (web `LeaveService.decide` ile aynı yol); burada
/// tekrar-uygulanmaz. Her okuma try/catch + [Logger.error] + `rethrow` ile
/// sarılır (ekranlar gerçek hatayı gösterebilsin).
class AdminLeaveService {
  final SupabaseClient _supabase;

  AdminLeaveService({required SupabaseClient supabase}) : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  /// Web `LeaveService.REQUEST_SELECT` ile birebir alan+embed sözleşmesi.
  static const String _requestSelect =
      'id,tenant_id,staff_id,organization_id,leave_type_id,start_date,end_date,'
      'day_count,half_day_start,half_day_end,status,approver_staff_id,decided_at,'
      'note,decision_note,created_at,'
      'leave_types(name),'
      'staffs!leave_requests_staff_id_fkey(name,first_name,last_name)';

  /// Tenant'taki TÜM izin talepleri (yalnızca kendiminkiler değil).
  ///
  /// Web `LeaveService.fetchAllRequests` aynası: admin tüm org'ların taleplerini
  /// görür (org-switcher filtresi UYGULANMAZ); kapsam RLS + `tenant_id` ile.
  /// Yeni-eskiye sıralı (`created_at DESC`).
  Future<List<AdminLeaveRequestRow>> allLeaveRequests() async {
    try {
      var query = _supabase.from('leave_requests').select(_requestSelect);

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((e) => AdminLeaveRequestRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminLeaveService.allLeaveRequests hata: $e');
      rethrow;
    }
  }

  /// İzin türleri — tenant-kapsamlı + global (`tenant_id is null`) ortak türler.
  ///
  /// Web `LeaveService.fetchTypes` kolonları; ada göre sıralı.
  Future<List<LeaveTypeRow>> leaveTypes() async {
    try {
      var query = _supabase.from('leave_types').select(
            'id,tenant_id,code,name,description,default_days,is_paid,'
            'allows_half_day,active',
          );

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null && tenantId.isNotEmpty) {
        // Tenant'a özel + global (tenant_id null) ortak türleri birlikte getir.
        query = query.or('tenant_id.eq.$tenantId,tenant_id.is.null');
      }

      final response = await query.order('name');
      return (response as List)
          .map((e) => LeaveTypeRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminLeaveService.leaveTypes hata: $e');
      rethrow;
    }
  }

  /// Resmi/şirket tatilleri — tarihe göre sıralı.
  ///
  /// Web `LeaveService.fetchHolidays` kolonları; `holiday_date` artan.
  Future<List<HolidayRow>> holidays() async {
    try {
      var query = _supabase.from('holidays').select(
            'id,tenant_id,holiday_date,name,is_recurring,active',
          );

      final tenantId = _tenant.currentTenantId;
      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      final response = await query.order('holiday_date');
      return (response as List)
          .map((e) => HolidayRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.error('AdminLeaveService.holidays hata: $e');
      rethrow;
    }
  }
}

/// Barrel getter — `sl<AdminLeaveService>()` kısayolu (HrEssService deseniyle).
AdminLeaveService get adminLeaveService => sl<AdminLeaveService>();

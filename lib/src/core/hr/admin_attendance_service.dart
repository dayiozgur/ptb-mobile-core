import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/admin_pdks_row.dart';
import 'models/attendance_lock_row.dart';
import 'models/attendance_record_row.dart';
import 'models/puantaj_summary_row.dart';
import 'models/staff_shift_row.dart';
import 'models/work_shift_row.dart';

/// PHR **admin** (İK yönetim) devam/PDKS/puantaj salt-okuma data-layer'ı.
///
/// Web portalının `PdksService` okuma-yollarını birebir aynalar (aynı Supabase
/// projesi, aynı tablo/RPC'ler):
///   • Günlük PDKS panosu — `fn_pdks_range(p_tenant, NULL, date, date)` + `staffs`
///     adları (web `getBoard`).
///   • Vardiya tanımları — `work_shifts`; atamalar — `staff_shifts` (embed'li).
///   • Ham devam kayıtları — `attendance_records` (tenant-kapsamlı).
///   • Aylık puantaj — `fn_pdks_range(p_tenant, NULL, from, to)` client-tarafı
///     personel-başı toplama.
///   • Puantaj onayları — `attendance_locks` (dönem kilidi).
///
/// ESS `HrEssService` "kendi kayıtlarım" kapsamına karşın bu servis yöneticinin
/// **tüm tenant** görünümünü verir; kapsam RLS + açık `tenant_id` eşitliği ile.
/// Okumalar try/catch + [Logger.error] + `rethrow` (ekran gerçek hatayı gösterir).
///
/// YAZMA: yalnızca [approvePeriod] / [reopenPeriod] (dönem kilitle/aç) —
/// web `PdksService.lockMonth`/`unlockMonth` ile aynı sözleşme; RLS admin-gated
/// ve tersine çevrilebilir (düşük risk).
class AdminAttendanceService {
  final SupabaseClient _supabase;

  AdminAttendanceService({required SupabaseClient supabase})
      : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  String? get _tenantId {
    final t = _tenant.currentTenantId;
    return (t != null && t.isNotEmpty) ? t : null;
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  // ============================================
  // STAFF NAME MAP (görünen ad çözümü)
  // ============================================

  /// Tenant'ın aktif personeli için `id → görünen ad` haritası.
  /// Web `PdksService.listStaff` aynası (`name` yoksa `first_name last_name`).
  Future<Map<String, String>> _staffNameMap() async {
    var query = _supabase
        .from('staffs')
        .select('id,name,first_name,last_name')
        .eq('active', true);
    final tenantId = _tenantId;
    if (tenantId != null) query = query.eq('tenant_id', tenantId);

    final response = await query.order('name');
    final map = <String, String>{};
    for (final row in (response as List).cast<Map<String, dynamic>>()) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final full = (row['name'] as String?) ??
          [row['first_name'], row['last_name']]
              .where((e) => e != null && (e as String).isNotEmpty)
              .join(' ');
      map[id] = full.trim().isNotEmpty ? full : '—';
    }
    return map;
  }

  // ============================================
  // 1) /admin/pdks — GÜNLÜK PANO
  // ============================================

  /// Bir gün için tüm personelin uzlaştırılmış PDKS durumu.
  /// Web `getBoard(dateIso)` aynası: `fn_pdks_range(tenant, NULL, date, date)`
  /// + personel adları. Personel adına göre sıralı.
  Future<List<AdminPdksRow>> pdksBoard(DateTime date) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) return [];
      final iso = _fmtDate(date);

      final results = await Future.wait<Object?>([
        _supabase.rpc('fn_pdks_range', params: {
          'p_tenant': tenantId,
          'p_staff': null,
          'p_from': iso,
          'p_to': iso,
        }),
        _staffNameMap(),
      ]);

      final rows = (results[0] as List).cast<Map<String, dynamic>>();
      final names = results[1] as Map<String, String>;

      final list = rows
          .map((r) => AdminPdksRow.fromJson(
                r,
                staffName: names[r['staff_id'] as String?] ?? '—',
              ))
          .toList();
      list.sort((a, b) =>
          a.staffName.toLowerCase().compareTo(b.staffName.toLowerCase()));
      return list;
    } catch (e) {
      Logger.error('AdminAttendanceService.pdksBoard hata: $e');
      rethrow;
    }
  }

  // ============================================
  // 2) /admin/pdks/shifts — VARDİYALAR
  // ============================================

  /// Vardiya tanımları — `work_shifts` (tenant-kapsamlı, ada göre sıralı).
  /// Web `PdksService.listShifts` aynası (pasifler dahil; ekran filtreleyebilir).
  Future<List<WorkShiftRow>> listShifts() async {
    try {
      var query = _supabase.from('work_shifts').select(
          'id,tenant_id,name,code,start_time,end_time,break_minutes,days_of_week,active');
      final tenantId = _tenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);

      final response = await query.order('name');
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map(WorkShiftRow.fromJson)
          .toList();
    } catch (e) {
      Logger.error('AdminAttendanceService.listShifts hata: $e');
      rethrow;
    }
  }

  /// Aktif personel-vardiya atamaları — `staff_shifts` (embed'li ad/vardiya).
  /// Web `PdksService.listAssignments` aynası (`effective_from DESC`).
  Future<List<StaffShiftRow>> listShiftAssignments() async {
    try {
      var query = _supabase
          .from('staff_shifts')
          .select(
              'id,staff_id,shift_id,effective_from,effective_to,active,'
              'staffs(name,first_name,last_name),work_shifts(name)')
          .eq('active', true);
      final tenantId = _tenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);

      final response = await query.order('effective_from', ascending: false);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map(StaffShiftRow.fromJson)
          .toList();
    } catch (e) {
      Logger.error('AdminAttendanceService.listShiftAssignments hata: $e');
      rethrow;
    }
  }

  // ============================================
  // 3) /admin/attendance — DEVAM / GİRİŞ-ÇIKIŞ
  // ============================================

  /// Ham devam kayıtları — `attendance_records` (tenant-kapsamlı).
  /// [from]/[to] verilmezse içinde bulunulan ay. Personel adları çözülür.
  /// En yeni tarih önce (`work_date DESC, entry_time DESC`).
  Future<List<AttendanceRecordRow>> attendanceRecords({
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) return [];

      final now = DateTime.now();
      final f = from ?? DateTime(now.year, now.month, 1);
      final t = to ?? DateTime(now.year, now.month + 1, 0);

      final results = await Future.wait<Object?>([
        _supabase
            .from('attendance_records')
            .select(
                'id,staff_id,work_date,entry_time,exit_time,worked_minutes,source,location,note')
            .eq('tenant_id', tenantId)
            .gte('work_date', _fmtDate(f))
            .lte('work_date', _fmtDate(t))
            .order('work_date', ascending: false)
            .order('entry_time', ascending: false)
            .limit(limit),
        _staffNameMap(),
      ]);

      final rows = (results[0] as List).cast<Map<String, dynamic>>();
      final names = results[1] as Map<String, String>;

      return rows
          .map((r) => AttendanceRecordRow.fromJson(
                r,
                staffName: names[r['staff_id'] as String?] ?? '—',
              ))
          .toList();
    } catch (e) {
      Logger.error('AdminAttendanceService.attendanceRecords hata: $e');
      rethrow;
    }
  }

  // ============================================
  // 4) /admin/puantaj — AYLIK PUANTAJ ÖZETİ
  // ============================================

  /// Bir ay için personel-başı puantaj özeti — `fn_pdks_range(tenant, NULL,
  /// from, to)` günlerinin client-tarafında toplanması. Personel adına göre
  /// sıralı. Durum sayımları: present/absent/leave/(off|holiday).
  Future<List<PuantajSummaryRow>> puantajSummary(int year, int month) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) return [];

      final from = DateTime(year, month, 1);
      final to = DateTime(year, month + 1, 0);

      final results = await Future.wait<Object?>([
        _supabase.rpc('fn_pdks_range', params: {
          'p_tenant': tenantId,
          'p_staff': null,
          'p_from': _fmtDate(from),
          'p_to': _fmtDate(to),
        }),
        _staffNameMap(),
      ]);

      final rows = (results[0] as List).cast<Map<String, dynamic>>();
      final names = results[1] as Map<String, String>;

      final byStaff = <String, PuantajSummaryRow>{};
      for (final r in rows) {
        final staffId = r['staff_id'] as String?;
        if (staffId == null) continue;
        final status = (r['status'] as String?)?.toLowerCase();
        final isLeave = (r['is_leave'] as bool? ?? false) || status == 'leave';
        final isHoliday =
            (r['is_holiday'] as bool? ?? false) || status == 'holiday';

        final acc = byStaff[staffId] ??
            PuantajSummaryRow(
              staffId: staffId,
              staffName: names[staffId] ?? '—',
            );
        byStaff[staffId] = acc.copyAdd(
          worked: (r['worked_minutes'] as num?)?.toInt() ?? 0,
          expected: (r['expected_minutes'] as num?)?.toInt() ?? 0,
          overtime: (r['overtime_minutes'] as num?)?.toInt() ?? 0,
          missing: (r['missing_minutes'] as num?)?.toInt() ?? 0,
          late: (r['late_minutes'] as num?)?.toInt() ?? 0,
          present: status == 'present' ? 1 : 0,
          absent: status == 'absent' ? 1 : 0,
          leave: isLeave ? 1 : 0,
          holidayOff: (isHoliday || status == 'off') ? 1 : 0,
        );
      }

      final list = byStaff.values.toList();
      list.sort((a, b) =>
          a.staffName.toLowerCase().compareTo(b.staffName.toLowerCase()));
      return list;
    } catch (e) {
      Logger.error('AdminAttendanceService.puantajSummary hata: $e');
      rethrow;
    }
  }

  // ============================================
  // 5) /admin/puantaj/approvals — PUANTAJ ONAYLARI
  // ============================================

  /// Son [months] dönemin (içinde bulunulan aydan geriye) puantaj-onay durumu.
  /// `attendance_locks` sorgulanır; kilitli dönemler "onaylandı", diğerleri
  /// "onay bekliyor". En yeni dönem önce.
  Future<List<AttendanceLockRow>> puantajApprovals({int months = 6}) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) return [];

      // Görüntülenecek dönem aralığını üret (yeni → eski).
      final now = DateTime.now();
      final periods = <DateTime>[];
      for (int i = 0; i < months; i++) {
        periods.add(DateTime(now.year, now.month - i, 1));
      }
      final oldest = periods.last;

      final response = await _supabase
          .from('attendance_locks')
          .select('id,period_year,period_month,locked_by,locked_at')
          .eq('tenant_id', tenantId)
          .gte('period_year', oldest.year);

      final locks = <String, AttendanceLockRow>{};
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final lock = AttendanceLockRow.fromJson(row);
        locks['${lock.periodYear}-${lock.periodMonth}'] = lock;
      }

      return periods.map((p) {
        final key = '${p.year}-${p.month}';
        return locks[key] ??
            AttendanceLockRow(
              periodYear: p.year,
              periodMonth: p.month,
              locked: false,
            );
      }).toList();
    } catch (e) {
      Logger.error('AdminAttendanceService.puantajApprovals hata: $e');
      rethrow;
    }
  }

  /// Dönemi onayla (kilitle) — `attendance_locks` INSERT. Web
  /// `PdksService.lockMonth` ile aynı sözleşme. RLS admin-gated ve
  /// [reopenPeriod] ile tersine çevrilebilir.
  Future<void> approvePeriod(int year, int month) async {
    try {
      final tenantId = _tenantId;
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('attendance_locks').insert({
        'tenant_id': tenantId,
        'period_year': year,
        'period_month': month,
        'locked_by': userId,
      });
    } catch (e) {
      Logger.error('AdminAttendanceService.approvePeriod hata: $e');
      rethrow;
    }
  }

  /// Dönemi yeniden aç (kilit sil) — `attendance_locks` DELETE. Web
  /// `PdksService.unlockMonth` ile aynı sözleşme.
  Future<void> reopenPeriod(int year, int month) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) return;
      await _supabase
          .from('attendance_locks')
          .delete()
          .eq('tenant_id', tenantId)
          .eq('period_year', year)
          .eq('period_month', month);
    } catch (e) {
      Logger.error('AdminAttendanceService.reopenPeriod hata: $e');
      rethrow;
    }
  }
}

/// Kısayol getter — `sl<AdminAttendanceService>()`.
AdminAttendanceService get adminAttendanceService => sl<AdminAttendanceService>();

import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../utils/logger.dart';

/// PHR **admin** bordro ek/kesinti (avans / masraf) yazma-akışları.
///
/// Web `PayrollService` (libs/@ptb/hr-management/.../payroll/services) yönetici
/// yazma-yollarının mobil aynası. Mobil `AdminPayrollService` yalnızca OKUR
/// (`adjustments()` vb.); karar/işleme aksiyonları web'de vardı ama mobilde
/// YOKTU — bu servis o boşluğu kapatır. Okuma-servisinden AYRI tutulur: okuma
/// hatayı `rethrow` eder (ekran gerçek hatayı gösterir), yazma ise inbox'ı
/// çökertmemek için `false`/`null` döner (worklog_service deseni).
///
/// RPC sözleşmeleri web kullanımından **birebir** türetildi (DB'den değil):
///   * `fn_hr_push_to_payroll(p_submission_id uuid) -> uuid`  — onaylı avans/
///     masraf başvurusunu bordroya it (yeni `payroll_adjustments` satırı; id döner).
///   * `fn_payroll_apply_adjustments(p_run_id uuid) -> int`   — bekleyen
///     ek/kesintileri bir çalıştırmanın bordro satırlarına işle (#işlenen döner).
///   * `payroll_adjustments` UPDATE `status='cancelled'` WHERE `id` AND
///     `status='pending'` — henüz işlenmemiş bekleyen bir ek/kesintiyi iptal et
///     (web `PayrollService.cancelAdjustment`). Yetki + guard RLS/tetikleyicide.
///
/// NOT (gerekçe alanı): web `cancelAdjustment` bir "red gerekçesi" almaz —
/// backend'de böyle bir kolon sözleşmesi yok — bu yüzden spekülatif bir `reason`
/// parametresi EKLENMEDİ. Bunun yerine geçersiz-girdi guard'ı (boş id) yazmayı
/// engeller ve `false` döner.
///
/// Ctor-inject (test için `sl` gerekmez); DI'da lazy-singleton kayıtlı.
class AdminPayrollAdjustmentService {
  final SupabaseClient _supabase;

  AdminPayrollAdjustmentService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Onaylı bir avans/masraf başvurusunu bordroya it (`fn_hr_push_to_payroll`).
  ///
  /// [submissionId] boşsa RPC çağrılmaz, `null` döner (geçersiz girdi guard'ı).
  /// Başarı → oluşturulan `payroll_adjustments` satırının id'si (boş string
  /// dönebilir — web `String(data ?? '')` ile aynı). Hata → `null` (fırlatmaz).
  Future<String?> pushToPayroll(String submissionId) async {
    if (submissionId.trim().isEmpty) return null;
    try {
      final data = await _supabase.rpc(
        'fn_hr_push_to_payroll',
        params: {'p_submission_id': submissionId},
      );
      return (data ?? '').toString();
    } catch (e) {
      Logger.error('AdminPayrollAdjustmentService.pushToPayroll hata: $e');
      return null;
    }
  }

  /// Bekleyen ek/kesintileri bir çalıştırmanın bordrosuna işle
  /// (`fn_payroll_apply_adjustments`). İşlenen satır sayısını döner.
  ///
  /// [runId] boşsa RPC çağrılmaz, `null` döner. Başarı → işlenen adet
  /// (web `Number(data ?? 0)` aynası; `int`'e çevrilir). Hata → `null`.
  Future<int?> applyAdjustments(String runId) async {
    if (runId.trim().isEmpty) return null;
    try {
      final data = await _supabase.rpc(
        'fn_payroll_apply_adjustments',
        params: {'p_run_id': runId},
      );
      if (data == null) return 0;
      if (data is int) return data;
      if (data is num) return data.toInt();
      return int.tryParse(data.toString()) ?? 0;
    } catch (e) {
      Logger.error('AdminPayrollAdjustmentService.applyAdjustments hata: $e');
      return null;
    }
  }

  /// Henüz işlenmemiş **bekleyen** bir ek/kesintiyi iptal et (reddet).
  ///
  /// Web `PayrollService.cancelAdjustment` aynası: `payroll_adjustments` üstünde
  /// doğrudan UPDATE `status='cancelled'` + `updated_at` (+ elde varsa
  /// `updated_by`), `WHERE id = [id] AND status = 'pending'` — zaten işlenmiş /
  /// iptal edilmiş satır sessizce ETKİLENMEZ. [id] boşsa yazma yapılmaz.
  /// Başarı → `true`; hata → `false` (fırlatmaz).
  Future<bool> cancelAdjustment(String id) async {
    if (id.trim().isEmpty) return false;
    try {
      final patch = <String, dynamic>{
        'status': 'cancelled',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final uid = _supabase.auth.currentUser?.id;
      if (uid != null) patch['updated_by'] = uid;

      await _supabase
          .from('payroll_adjustments')
          .update(patch)
          .eq('id', id)
          .eq('status', 'pending');
      return true;
    } catch (e) {
      Logger.error('AdminPayrollAdjustmentService.cancelAdjustment hata: $e');
      return false;
    }
  }
}

/// DI erişim kısayolu — kayıt `service_locator.dart` içinde yapılır.
AdminPayrollAdjustmentService get adminPayrollAdjustmentService =>
    sl<AdminPayrollAdjustmentService>();

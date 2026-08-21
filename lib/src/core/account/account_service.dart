import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';
import 'models/credit_balance.dart';
import 'models/credit_transaction.dart';
import 'models/invoice.dart';
import 'models/invoice_summary.dart';
import 'models/storage_quota.dart';

/// Hesap (Hesabım) — kredi / fatura / depolama / AI kullanım görüntüleyici
/// servisi (salt-okuma). Web `BillingService` + `TenantCreditService` +
/// `StorageService` + `AiAssistantService` okuma yollarını aynalar (aynı
/// Supabase projesi, RLS/JWT ile tenant-scoped).
///
/// **Yazma / satın alma YOK** (mobilde yasak). Her metod try/catch ile
/// sarılıdır ve hata durumunda boş/null döner — hub çökmez, görüntüleyiciler
/// boş-durum gösterir.
class AccountService {
  final SupabaseClient _supabase;

  AccountService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Geçerli tenant kimliği (yoksa null).
  String? get _tenantId => sl<TenantService>().currentTenantId;

  /// Kredi bakiyesi — `tenant_credits` (tek satır). Yoksa/hata → null.
  Future<CreditBalance?> creditBalance() async {
    try {
      final t = _tenantId;
      if (t == null || t.isEmpty) return null;
      final row = await _supabase
          .from('tenant_credits')
          .select('*')
          .eq('tenant_id', t)
          .maybeSingle();
      if (row == null) return null;
      return CreditBalance.fromJson(row);
    } catch (e, st) {
      Logger.error('AccountService.creditBalance hata', e, st);
      return null;
    }
  }

  /// Kredi hareketleri — `tenant_credit_transactions` (yeni → eski). Hata → [].
  Future<List<CreditTransaction>> creditTransactions({int limit = 50}) async {
    try {
      final t = _tenantId;
      if (t == null || t.isEmpty) return const [];
      final rows = await _supabase
          .from('tenant_credit_transactions')
          .select('*')
          .eq('tenant_id', t)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((e) => CreditTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      Logger.error('AccountService.creditTransactions hata', e, st);
      return const [];
    }
  }

  /// Faturalar — `tenant_invoices` (yeni → eski). Hata → [].
  Future<List<Invoice>> invoices({int limit = 50}) async {
    try {
      final t = _tenantId;
      if (t == null || t.isEmpty) return const [];
      final rows = await _supabase
          .from('tenant_invoices')
          .select('*')
          .eq('tenant_id', t)
          .order('invoice_date', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      Logger.error('AccountService.invoices hata', e, st);
      return const [];
    }
  }

  /// Fatura özeti — faturalardan türetilir (void atlanır). Hata → boş özet.
  Future<InvoiceSummary> invoiceSummary() async {
    try {
      final list = await invoices(limit: 200);
      return InvoiceSummary.fromInvoices(list);
    } catch (e, st) {
      Logger.error('AccountService.invoiceSummary hata', e, st);
      return const InvoiceSummary();
    }
  }

  /// Depolama kotası — `get_storage_quota_info(p_tenant_id)` RPC.
  /// RPC tek-obje veya liste dönebilir; her iki durum ele alınır. Hata → null.
  Future<StorageQuota?> storageQuota() async {
    try {
      final t = _tenantId;
      if (t == null || t.isEmpty) return null;
      final data = await _supabase
          .rpc('get_storage_quota_info', params: {'p_tenant_id': t});
      final Map<String, dynamic>? row = _firstRow(data);
      if (row == null) return null;
      return StorageQuota.fromJson(row);
    } catch (e, st) {
      Logger.error('AccountService.storageQuota hata', e, st);
      return null;
    }
  }

  /// AI kullanım özeti (bu ay) — `fn_ai_usage_summary(p_tenant_id, p_month)`.
  /// Best-effort: ham Map döner, hata/erişim-yok → null (kart sessiz kalır).
  Future<Map<String, dynamic>?> aiUsage() async {
    try {
      final t = _tenantId;
      if (t == null || t.isEmpty) return null;
      final now = DateTime.now();
      final month =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
      final data = await _supabase.rpc(
        'fn_ai_usage_summary',
        params: {'p_tenant_id': t, 'p_month': month},
      );
      return _firstRow(data);
    } catch (e, st) {
      Logger.error('AccountService.aiUsage hata', e, st);
      return null;
    }
  }

  /// RPC sonucu tek-obje ya da liste olabilir — ilk satırı `Map` olarak döndürür.
  Map<String, dynamic>? _firstRow(dynamic data) {
    if (data == null) return null;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is List) {
      if (data.isEmpty) return null;
      final first = data.first;
      if (first is Map) return first.cast<String, dynamic>();
    }
    return null;
  }
}

/// Global erişim — `sl<AccountService>()`.
AccountService get accountService => sl<AccountService>();

import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../utils/logger.dart';

/// **Aggregate/rollup servisi** — özet ekranlarını besleyen ince RPC sarmalayıcı.
///
/// Sunucu tarafındaki `fn_*_rollup` / `fn_*_summary` fonksiyonları ya `TABLE(...)`
/// (satır listesi) ya da `json`/`jsonb` (tek gövde) döner. Bu servis ikisini de
/// normalize eder; dönen satır-map şekli doğrudan `DynChartWidget` /
/// `DynStatWidget` primitiflerinin beklediği `List<Map<String,dynamic>>`'e uyar.
///
/// Güvenlik: SECDEF rollup'lar zaten `get_my_tenant_id()`/`auth.uid()` ile
/// kapsanır; tenant/org parametresi isteyenlere ASLA caller-tipli tenant geçme,
/// [TenantContextService]/[OrganizationService]'ten al.
class AggregateService {
  SupabaseClient get _sb => sl<SupabaseClient>();

  /// `TABLE(...)` dönen bir rollup'ı satır listesine çevir.
  Future<List<Map<String, dynamic>>> rows(
    String rpc, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final res = await _sb.rpc(rpc, params: params ?? const {});
      return _asRows(res);
    } catch (e) {
      Logger.warning('aggregate rows hata ($rpc): $e');
      rethrow;
    }
  }

  /// `json`/`jsonb` dönen bir rollup'ı ham olarak getir (Map ya da List).
  Future<dynamic> json(
    String rpc, {
    Map<String, dynamic>? params,
  }) async {
    try {
      return await _sb.rpc(rpc, params: params ?? const {});
    } catch (e) {
      Logger.warning('aggregate json hata ($rpc): $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _asRows(dynamic res) {
    if (res is List) {
      return res
          .whereType<Object>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    // Tek json gövde → tek satır (KPI kartları için elverişli).
    if (res is Map) return [Map<String, dynamic>.from(res)];
    return const [];
  }
}

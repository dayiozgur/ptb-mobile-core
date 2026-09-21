import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Yinelenen-kayıt tipi (contacts / companies) — merge RPC'sini seçer.
enum DupKind { contact, company }

/// Bir aday yinelenen-çift — web `DuplicatesComponent` (`fn_crm_find_duplicate_*`)
/// çıktısının mobil, tip-nötr karşılığı. İki taraf (A/B) + eşleşme-nedeni + güven.
class DuplicatePair {
  final DupKind kind;
  final String aId;
  final String aTitle;
  final String aSubtitle;
  final String bId;
  final String bTitle;
  final String bSubtitle;
  final String? reason;
  final double confidence;

  const DuplicatePair({
    required this.kind,
    required this.aId,
    required this.aTitle,
    required this.aSubtitle,
    required this.bId,
    required this.bTitle,
    required this.bSubtitle,
    this.reason,
    this.confidence = 0,
  });

  static double _d(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
  static String _s(Object? v) => (v as String?)?.trim() ?? '';
  static String _join(List<String?> parts) =>
      parts.map((p) => p?.trim() ?? '').where((p) => p.isNotEmpty).join(' · ');

  factory DuplicatePair.contact(Map<String, dynamic> j) => DuplicatePair(
        kind: DupKind.contact,
        aId: _s(j['contact_a_id']),
        aTitle: _s(j['a_name']).isEmpty ? '—' : _s(j['a_name']),
        aSubtitle: _join([j['a_email'] as String?, j['a_phone'] as String?]),
        bId: _s(j['contact_b_id']),
        bTitle: _s(j['b_name']).isEmpty ? '—' : _s(j['b_name']),
        bSubtitle: _join([j['b_email'] as String?, j['b_phone'] as String?]),
        reason: j['match_reason'] as String?,
        confidence: _d(j['confidence']),
      );

  factory DuplicatePair.company(Map<String, dynamic> j) => DuplicatePair(
        kind: DupKind.company,
        aId: _s(j['company_a_id']),
        aTitle: _s(j['a_name']).isEmpty ? '—' : _s(j['a_name']),
        aSubtitle: _s(j['a_domain']),
        bId: _s(j['company_b_id']),
        bTitle: _s(j['b_name']).isEmpty ? '—' : _s(j['b_name']),
        bSubtitle: _s(j['b_domain']),
        reason: j['match_reason'] as String?,
        confidence: _d(j['confidence']),
      );
}

/// **CRM Yinelenen-kayıt servisi** — web `DuplicateService` paritesi. Aday
/// çiftleri listeler ve iki kaydı birleştirir (`fn_crm_merge_*`, survivor+duplicate;
/// birleştirme kararı SUNUCUDA — alan-seviye conflict-UI yok). Tenant RLS'e bırakılır.
///
/// Yazma sözleşmesi: hata → [] / false (UI'a fırlatmaz).
class CrmDuplicateService {
  final SupabaseClient _supabase;

  CrmDuplicateService({required SupabaseClient supabase}) : _supabase = supabase;

  Future<List<DuplicatePair>> findContactDuplicates() =>
      _find('fn_crm_find_duplicate_contacts', DuplicatePair.contact);

  Future<List<DuplicatePair>> findCompanyDuplicates() =>
      _find('fn_crm_find_duplicate_companies', DuplicatePair.company);

  Future<List<DuplicatePair>> _find(
      String rpc, DuplicatePair Function(Map<String, dynamic>) map) async {
    try {
      final res = await _supabase.rpc(rpc);
      return (res as List)
          .map((r) => map(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('crm $rpc hata', e);
      return const [];
    }
  }

  /// [survivor] kalır, [duplicate] onun içine birleşir. Hata / geçersiz → false.
  Future<bool> merge(DupKind kind, String survivor, String duplicate) async {
    final s = survivor.trim(), d = duplicate.trim();
    if (s.isEmpty || d.isEmpty || s == d) return false;
    final rpc = kind == DupKind.company ? 'fn_crm_merge_companies' : 'fn_crm_merge_contacts';
    try {
      await _supabase.rpc(rpc, params: {'p_survivor': s, 'p_duplicate': d});
      return true;
    } catch (e) {
      Logger.error('crm $rpc hata', e);
      return false;
    }
  }
}

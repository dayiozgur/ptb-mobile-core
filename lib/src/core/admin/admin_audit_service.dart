import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Admin — Denetim İzi (audit trail) görüntüleyici (salt-okuma) servis.
///
/// Web portal `/admin/audit-log` okuma-yolunu aynalar. Kanonik kaynak
/// `audit_logs` tablosudur (`log_audit_change()` trigger'ının yazdığı tablo;
/// web `AuditLogService` ile aynı). Yazma YOK — v1 salt-okuma liste.
///
/// NOT: `audit_logs.actor_id → profiles` için TANIMLI bir FK YOKTUR, bu yüzden
/// PostgREST embed kullanılamaz. Ayrıca `actor_name` kolonu satırların büyük
/// çoğunluğunda NULL'dur; web gibi burada da `actor_id` değerleri ayrı bir
/// `profiles` sorgusu ile isimlere çözülür.
///
/// Tenant kapsamı **RLS** ile sağlanır; en yeni önce sıralanır.
class AdminAuditService {
  final SupabaseClient _supabase;

  static const String _table = 'audit_logs';

  AdminAuditService({required SupabaseClient supabase})
      : _supabase = supabase;

  /// Son denetim kayıtlarını (en yeni önce) getirir. RLS-scoped.
  Future<List<AuditEntryRow>> listAuditEntries({int limit = 100}) async {
    try {
      final rows = await _supabase
          .from(_table)
          .select(
            'id, entity_type, entity_id, action, actor_id, actor_name, '
            'old_values, new_values, changes, created_at',
          )
          .order('created_at', ascending: false)
          .limit(limit);

      final list = (rows as List).cast<Map<String, dynamic>>();

      // actor_name NULL olan satırlar için actor_id → görünen ad çöz.
      final unresolvedIds = <String>{
        for (final r in list)
          if ((r['actor_name'] as String?)?.trim().isEmpty ?? true)
            if (r['actor_id'] is String) r['actor_id'] as String,
      };
      final names = unresolvedIds.isEmpty
          ? <String, String>{}
          : await _resolveActorNames(unresolvedIds.toList());

      final result = list
          .map((e) => AuditEntryRow.fromJson(e, resolvedNames: names))
          .toList();

      Logger.debug('AdminAuditService.listAuditEntries → ${result.length}');
      return result;
    } catch (e, st) {
      Logger.error('AdminAuditService.listAuditEntries hata', e, st);
      rethrow;
    }
  }

  /// actor_id kümesini `profiles` üzerinden görünen isimlere çözer.
  Future<Map<String, String>> _resolveActorNames(List<String> ids) async {
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, full_name, username, email')
          .inFilter('id', ids);

      final map = <String, String>{};
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final id = r['id'] as String?;
        if (id == null) continue;
        final name = _pickName(r);
        if (name != null) map[id] = name;
      }
      return map;
    } catch (e) {
      Logger.warning('AdminAuditService._resolveActorNames hata: $e');
      return {};
    }
  }

  static String? _pickName(Map<String, dynamic> m) {
    final full = (m['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    final username = (m['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    final email = (m['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }
}

/// Denetim izi satırı görüntü-modeli (salt-okuma).
class AuditEntryRow {
  final String id;

  /// Etkilenen tablo/varlık (`work_orders | staffs | ...`).
  final String? entityType;
  final String? entityId;

  /// `create | update | delete | status_change | export`.
  final String? action;

  /// İşlemi yapan kişinin görünen adı (çözülmüş).
  final String? actorName;

  /// Değişen alanlar diff'i (varsa) — `{field: {old, new}}` benzeri jsonb.
  final Map<String, dynamic>? changes;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;

  final DateTime? changedAt;

  const AuditEntryRow({
    required this.id,
    this.entityType,
    this.entityId,
    this.action,
    this.actorName,
    this.changes,
    this.oldValues,
    this.newValues,
    this.changedAt,
  });

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  factory AuditEntryRow.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> resolvedNames = const {},
  }) {
    final rawName = (json['actor_name'] as String?)?.trim();
    final actorId = json['actor_id'] as String?;
    final actorName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (actorId != null ? resolvedNames[actorId] : null);

    return AuditEntryRow(
      id: json['id'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      action: json['action'] as String?,
      actorName: actorName,
      changes: _asMap(json['changes']),
      oldValues: _asMap(json['old_values']),
      newValues: _asMap(json['new_values']),
      changedAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
    );
  }
}

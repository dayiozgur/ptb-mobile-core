import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../localization/localization_service.dart';
import '../platform/builder_platform_filter.dart';
import '../utils/logger.dart';
import 'fixflow_models.dart';
import 'fixflow_session.dart';

/// FixFlow durum motoru istemcisi — web `PtbStatusService` ile aynı sözleşme:
///
/// - Tanımlar: `status_definitions` (entity_type + active), FixFlow platform
///   görünürlüğü ([BuilderPlatformFilter], web `applyPlatformFilter`),
///   `sort_order` sıralı; aynı `code` için tenant satırı (`is_system=false`)
///   sistem satırını yener. Ad, `metadata.i18n.name` anahtarı (yoksa sistem
///   satırında `status.<code>`) ile çevrilir. Durum ASLA sabit kodlanmaz.
/// - Geçişler: `status_transitions` (from-code'a göre, rol filtresi, hedefe
///   göre tekil). Form gerektiren geçişler mobilde sunulmaz.
/// - Yürütme: YALNIZ `status-transition` Edge Function. Durum kolonuna asla
///   doğrudan yazılmaz (trigger + kurallar + geçmiş + webhook EF'te).
class FixflowStatusService {
  final SupabaseClient _supabase;
  final FixflowSession _session;
  final String Function(String key)? _translate;

  FixflowStatusService({
    required SupabaseClient supabase,
    FixflowSession? session,
    String Function(String key)? translate,
  })  : _supabase = supabase,
        _session = session ?? AppFixflowSession(supabase),
        _translate = translate;

  final Map<String, Future<FixflowStatusCatalog>> _memo = {};

  String _tr(String key) {
    if (_translate != null) return _translate(key);
    if (sl.isRegistered<LocalizationService>()) {
      return sl<LocalizationService>().translate(key);
    }
    return key;
  }

  /// Bir entity tipinin durum kataloğu (memoize; hata/boş önbelleğe alınmaz).
  Future<FixflowStatusCatalog> catalog(String entityType) {
    // Anahtar tenant'ı taşır: tenant değişiminde başka tenant'ın tanımları
    // (RLS tenant-scoped) sunulmaz.
    final key = '${_session.tenantId ?? 'null'}:$entityType';
    final pending = _memo[key];
    if (pending != null) return pending;
    final f = _fetchCatalog(entityType).then((c) {
      if (c.statuses.isEmpty) _memo.remove(key);
      return c;
    });
    _memo[key] = f;
    return f;
  }

  /// Önbelleği temizle (dil değişimi / durum yönetimi düzenlemesi).
  void clearCache() => _memo.clear();

  Future<FixflowStatusCatalog> _fetchCatalog(String entityType) async {
    try {
      var query = _supabase
          .from('status_definitions')
          .select(
            'id, code, name, color, is_initial, is_final, sort_order, is_system, metadata',
          )
          .eq('entity_type', entityType)
          .eq('active', true);
      query = BuilderPlatformFilter.apply(query, FixflowConstants.platformId);
      final res = await query.order('sort_order', ascending: true);
      final rows = (res as List).cast<Map<String, dynamic>>();
      return FixflowStatusCatalog(_dedupAndMap(rows));
    } catch (e) {
      Logger.error('FixFlow status definitions ($entityType) failed', e);
      return FixflowStatusCatalog.empty;
    }
  }

  List<FixflowStatus> _dedupAndMap(List<Map<String, dynamic>> rows) {
    final byCode = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final code = row['code']?.toString();
      if (code == null || code.isEmpty) continue;
      final existing = byCode[code];
      if (existing == null || row['is_system'] != true) byCode[code] = row;
    }
    final list = byCode.values.map(_mapStatus).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// `metadata.i18n.name` → (sistem satırı ise) `status.<code>` → DB adı.
  String? _labelKey(Map<String, dynamic> row) {
    final meta = row['metadata'];
    if (meta is Map) {
      final i18n = meta['i18n'];
      if (i18n is Map && i18n['name'] is String) {
        final k = (i18n['name'] as String).trim();
        if (k.isNotEmpty) return k;
      }
    }
    if (row['is_system'] == true) return 'status.${row['code']}';
    return null;
  }

  FixflowStatus _mapStatus(Map<String, dynamic> row) {
    final code = row['code'].toString();
    var name = (row['name'] as String?)?.trim() ?? '';
    final key = _labelKey(row);
    if (key != null) {
      final t = _tr(key);
      if (t.isNotEmpty && t != key) name = t;
    }
    return FixflowStatus(
      code: code,
      name: name.isEmpty ? code : name,
      colorHex: row['color'] as String?,
      isInitial: row['is_initial'] == true,
      isFinal: row['is_final'] == true,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// [currentStatus]'tan kullanıcının yapabileceği geçişler (web
  /// `getAvailableTransitions` ile aynı filtreler; ek olarak form gerektiren
  /// geçişler elenir). Hata → boş liste.
  Future<List<FixflowTransition>> availableTransitions(
    String entityType,
    String currentStatus,
  ) async {
    try {
      final res = await _supabase
          .from('status_transitions')
          .select(
            'id, name, required_roles, requires_comment, requires_confirmation, '
            'required_form_template_id, sort_order, '
            'from_status:status_definitions!from_status_id(code), '
            'to_status:status_definitions!to_status_id(id, code, name, color, is_initial, is_final, sort_order, is_system, metadata)',
          )
          .eq('entity_type', entityType)
          .eq('active', true)
          .order('sort_order', ascending: true);
      final rows = (res as List).cast<Map<String, dynamic>>();
      final roles = await _session.roles();
      final seen = <String>{};
      final out = <FixflowTransition>[];
      for (final r in rows) {
        final from = r['from_status'];
        if (from is! Map || from['code'] != currentStatus) continue;
        final to = r['to_status'];
        if (to is! Map) continue;
        final toRow = Map<String, dynamic>.from(to);
        final toCode = toRow['code']?.toString();
        if (toCode == null || toCode.isEmpty || seen.contains(toCode)) continue;
        final required = ((r['required_roles'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();
        if (required.isNotEmpty &&
            !required.any((x) => roles.contains(normalizeFixflowRole(x)))) {
          continue;
        }
        if (r['required_form_template_id'] != null) continue;
        seen.add(toCode);
        out.add(FixflowTransition(
          id: r['id'].toString(),
          name: r['name'] as String?,
          toStatus: _mapStatus(toRow),
          requiredRoles: required,
          requiresComment: r['requires_comment'] == true,
          requiresConfirmation: r['requires_confirmation'] == true,
        ));
      }
      return out;
    } catch (e) {
      Logger.error('FixFlow transitions ($entityType/$currentStatus) failed', e);
      return const [];
    }
  }

  /// Durum geçişini `status-transition` EF ile yürüt (web
  /// `PtbStatusService.executeTransition`). Başarısızlıkta
  /// [FixflowTransitionException] fırlatır.
  Future<void> executeTransition({
    required String entityType,
    required String entityId,
    required String toStatus,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'entityType': entityType,
      'entityId': entityId,
      'toStatus': toStatus,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    };
    dynamic data;
    try {
      final res = await _supabase.functions.invoke('status-transition', body: body);
      data = res.data;
    } on FunctionException catch (e) {
      throw _fromBody(e.details) ??
          FixflowTransitionException(
            'EDGE_FUNCTION_ERROR',
            e.reasonPhrase ?? 'status-transition failed (${e.status})',
          );
    }
    if (data is Map) {
      if (data['success'] == false || (data['error'] != null && data['success'] != true)) {
        throw _fromBody(data) ??
            const FixflowTransitionException('ERR_UNKNOWN', 'status-transition failed');
      }
    }
    clearCache();
  }

  FixflowTransitionException? _fromBody(dynamic details) {
    if (details is Map) {
      final err = details['error'];
      if (err is Map) {
        return FixflowTransitionException(
          err['code']?.toString() ?? 'ERR_UNKNOWN',
          err['message']?.toString() ?? '',
        );
      }
      if (err is String) return FixflowTransitionException('ERR_UNKNOWN', err);
    }
    return null;
  }
}

import 'entity_status_labels.dart';

/// One transition the current user may start from a given status, as the
/// `status-transition` Edge Function would accept it.
class AllowedStatusTransition {
  /// `status_transitions.id` of the row the EF will pick for this from→to pair.
  final String id;

  /// Optional transition label (`status_transitions.name`).
  final String? name;
  final String fromCode;
  final String toCode;

  /// The embedded `to_status` row (whatever columns the caller selected).
  final Map<String, dynamic> toRow;
  final List<String> requiredRoles;
  final bool requiresComment;
  final bool requiresConfirmation;
  final String? requiredFormTemplateId;
  final int sortOrder;

  const AllowedStatusTransition({
    required this.id,
    required this.fromCode,
    required this.toCode,
    this.name,
    this.toRow = const {},
    this.requiredRoles = const [],
    this.requiresComment = false,
    this.requiresConfirmation = false,
    this.requiredFormTemplateId,
    this.sortOrder = 0,
  });

  /// The EF demands a form submission for this transition.
  bool get requiresForm => requiredFormTemplateId != null;
}

/// Pure (network-free) status-engine rules shared by the core entity screens,
/// the FixFlow module and the CRM app. Mirrors the `status-transition` Edge
/// Function and web `PtbStatusService`:
///
/// * **Labels** — `metadata.i18n.name` key → (system row) `status.<code>` →
///   DB `name` → humanized code.
/// * **Transitions** — for each from→to pair the EF picks ONE row: the
///   caller's own tenant first, then the lowest `sort_order`, then `id`. The
///   role check runs on that row only (`required_roles` empty = everyone;
///   `ROLE_ADMIN` ≙ `admin`). A pair whose winning row the user cannot pass is
///   not offered (a permissive duplicate would not save it on the server).
/// * Form-required transitions are hidden by default (mobile has no form
///   step) and wizard-only targets (lead→converted, owned by the convert
///   wizard) are never offered by generic status controls.
class StatusTransitionRules {
  StatusTransitionRules._();

  /// Global/system tenant id used by seeded rows.
  static const String systemTenantId = '00000000-0000-0000-0000-000000000000';

  /// Targets only a dedicated wizard may reach (web `lead-convert-route.ts`
  /// WIZARD_ONLY_TARGETS): lead→converted fires `crm-lead-to-deal-convert`
  /// and needs the amount the wizard collects.
  static const Map<String, List<String>> wizardOnlyTargets = {
    'lead': ['converted'],
  };

  static bool isWizardOnly(String entityType, String toStatus) =>
      wizardOnlyTargets[entityType]?.contains(toStatus) ?? false;

  /// `ROLE_ADMIN` → `admin` (EF `normalizeRole`).
  static String normalizeRole(String r) =>
      r.trim().replaceFirst(RegExp('^ROLE_', caseSensitive: false), '').toLowerCase();

  /// The role set the EF checks: JWT `app_metadata.roles` when present,
  /// otherwise the coarse role (EF `resolveTenantContext` fallback).
  static Set<String> effectiveRoles({
    Iterable<dynamic>? jwtRoles,
    String? coarseRole,
  }) {
    final out = <String>{
      for (final r in jwtRoles ?? const <dynamic>[])
        if (r != null && r.toString().trim().isNotEmpty) normalizeRole(r.toString()),
    };
    if (out.isEmpty && coarseRole != null && coarseRole.trim().isNotEmpty) {
      out.add(normalizeRole(coarseRole));
    }
    return out;
  }

  /// Translation key of a `status_definitions` row, or null.
  static String? labelKey(Map<String, dynamic> row) {
    final meta = row['metadata'];
    if (meta is Map) {
      final i18n = meta['i18n'];
      if (i18n is Map) {
        final k = i18n['name'];
        if (k is String && k.trim().isNotEmpty) return k.trim();
      }
    }
    if (row['is_system'] == true) {
      final code = row['code']?.toString() ?? '';
      if (code.isNotEmpty) return 'status.$code';
    }
    return null;
  }

  /// Display name of a `status_definitions` row (see class doc).
  static String localizedName(
    Map<String, dynamic> row,
    String Function(String key) translate,
  ) {
    final key = labelKey(row);
    if (key != null) {
      final t = translate(key);
      if (t.isNotEmpty && t != key) return t;
    }
    return EntityStatusLabels.rowName(row);
  }

  static String? _code(dynamic embedded) {
    if (embedded is! Map) return null;
    final c = embedded['code']?.toString();
    return (c == null || c.isEmpty) ? null : c;
  }

  /// The row the EF selects among several rows of the same from→to pair.
  static int _compareForEf(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    String? tenantId,
  ) {
    if (tenantId != null) {
      final at = a['tenant_id'] == tenantId ? 0 : 1;
      final bt = b['tenant_id'] == tenantId ? 0 : 1;
      if (at != bt) return at - bt;
    }
    final aso = (a['sort_order'] as num?)?.toInt() ?? 0;
    final bso = (b['sort_order'] as num?)?.toInt() ?? 0;
    if (aso != bso) return aso - bso;
    return (a['id']?.toString() ?? '').compareTo(b['id']?.toString() ?? '');
  }

  /// Transitions from [fromCode] the user may start (see class doc). [rows]
  /// are `status_transitions` rows with embedded `from_status{code}` /
  /// `to_status{code,…}`; [roles] may be raw or normalized.
  static List<AllowedStatusTransition> allowed(
    List<Map<String, dynamic>> rows, {
    required String entityType,
    required String fromCode,
    required Set<String> roles,
    String? tenantId,
    bool includeFormRequired = false,
    bool includeWizardOnly = false,
  }) {
    final userRoles = roles.map(normalizeRole).toSet();
    final winners = <String, Map<String, dynamic>>{};
    final order = <String>[];
    for (final r in rows) {
      if (_code(r['from_status']) != fromCode) continue;
      final to = _code(r['to_status']);
      if (to == null || to == fromCode) continue;
      final current = winners[to];
      if (current == null) {
        winners[to] = r;
        order.add(to);
      } else if (_compareForEf(r, current, tenantId) < 0) {
        winners[to] = r;
      }
    }

    final out = <AllowedStatusTransition>[];
    for (final to in order) {
      final r = winners[to]!;
      final required = ((r['required_roles'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (required.isNotEmpty &&
          !required.any((x) => userRoles.contains(normalizeRole(x)))) {
        continue;
      }
      final formId = r['required_form_template_id']?.toString();
      if (formId != null && formId.isNotEmpty && !includeFormRequired) continue;
      if (!includeWizardOnly && isWizardOnly(entityType, to)) continue;
      final toRow = r['to_status'] is Map
          ? Map<String, dynamic>.from(r['to_status'] as Map)
          : <String, dynamic>{'code': to};
      out.add(AllowedStatusTransition(
        id: r['id']?.toString() ?? '',
        name: r['name'] as String?,
        fromCode: fromCode,
        toCode: to,
        toRow: toRow,
        requiredRoles: required,
        requiresComment: r['requires_comment'] == true,
        requiresConfirmation: r['requires_confirmation'] == true,
        requiredFormTemplateId:
            (formId == null || formId.isEmpty) ? null : formId,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
      ));
    }
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return out;
  }

  /// Shortest chain of allowed status codes from [fromCode] to [toCode]
  /// (excluding [fromCode], ending with [toCode]); null when unreachable.
  /// Intermediate hops never pass through a code in [finalCodes]. Used by
  /// wizards that must walk a workflow without skips (web lead ladder), but
  /// driven by `status_transitions` rather than a hard-coded ladder.
  static List<String>? pathTo(
    List<Map<String, dynamic>> rows, {
    required String entityType,
    required String fromCode,
    required String toCode,
    required Set<String> roles,
    String? tenantId,
    Set<String> finalCodes = const {},
  }) {
    if (fromCode == toCode) return const [];
    final prev = <String, String>{};
    final queue = <String>[fromCode];
    final seen = <String>{fromCode};
    while (queue.isNotEmpty) {
      final at = queue.removeAt(0);
      final next = allowed(rows,
          entityType: entityType,
          fromCode: at,
          roles: roles,
          tenantId: tenantId,
          includeWizardOnly: true);
      for (final t in next) {
        if (seen.contains(t.toCode)) continue;
        seen.add(t.toCode);
        prev[t.toCode] = at;
        if (t.toCode == toCode) {
          final path = <String>[toCode];
          var c = at;
          while (c != fromCode) {
            path.insert(0, c);
            c = prev[c]!;
          }
          return path;
        }
        if (!finalCodes.contains(t.toCode)) queue.add(t.toCode);
      }
    }
    return null;
  }
}

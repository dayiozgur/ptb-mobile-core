import 'dart:ui' show Color;

import 'package:protoolbag_core/protoolbag_core.dart';

import '../shared/crm_backend.dart';

/// Bir durum/aşama tanımı (`status_definitions` satırı, dedup + çevrilmiş).
class CrmStage {
  final String code;
  final String name;
  final String? colorHex;
  final bool isInitial;
  final bool isFinal;
  final int sortOrder;

  const CrmStage({
    required this.code,
    required this.name,
    this.colorHex,
    this.isInitial = false,
    this.isFinal = false,
    this.sortOrder = 0,
  });

  Color? get color => EntityStatusLabels.parseHex(colorHex);
}

/// İzinli bir durum geçişi (`status_transitions`, rol süzgecinden geçmiş).
class CrmTransition {
  final String fromCode;
  final String toCode;
  final bool requiresComment;
  final bool requiresConfirmation;

  const CrmTransition({
    required this.fromCode,
    required this.toCode,
    this.requiresComment = false,
    this.requiresConfirmation = false,
  });
}

/// Saf (ağsız) aşama mantığı — web `PtbStatusService` ile birebir.
class CrmStageLogic {
  CrmStageLogic._();

  /// Yalnız sihirbazın yapabildiği hedefler — çekirdek
  /// [StatusTransitionRules.wizardOnlyTargets] (lead→converted).
  static bool isWizardOnly(String entityType, String toStatus) =>
      StatusTransitionRules.isWizardOnly(entityType, toStatus);

  /// Bir tanım satırının görünen adı — çekirdek
  /// [StatusTransitionRules.localizedName] (`metadata.i18n.name` → sistem
  /// satırında `status.<code>` → DB adı → okunur kod).
  static String labelOf(
          Map<String, dynamic> row, String Function(String key) translate) =>
      StatusTransitionRules.localizedName(row, translate);

  /// Tanım satırları → aşamalar: aynı kodda kiracı satırı (is_system=false)
  /// sistemi yener (web dedup), sort_order sıralı.
  static List<CrmStage> stagesFromRows(
    List<Map<String, dynamic>> rows,
    String Function(String key) translate,
  ) {
    final byCode = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      final code = r['code'] as String?;
      if (code == null || code.isEmpty) continue;
      final existing = byCode[code];
      if (existing == null || r['is_system'] != true) byCode[code] = r;
    }
    final stages = byCode.values
        .map((r) => CrmStage(
              code: r['code'] as String,
              name: labelOf(r, translate),
              colorHex: r['color'] as String?,
              isInitial: r['is_initial'] == true,
              isFinal: r['is_final'] == true,
              sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
            ))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return stages;
  }

  /// [fromCode]'dan izinli geçişler — çekirdek [StatusTransitionRules.allowed]
  /// (EF ile aynı satır seçimi: kendi kiracı → düşük sort_order → id; rol
  /// kontrolü seçilen satırda; form gerektiren ve sihirbaz-yalnız hedefler
  /// hariç).
  static List<CrmTransition> transitionsFrom(
    List<Map<String, dynamic>> rows, {
    required String entityType,
    required String fromCode,
    String? role,
    String? tenantId,
  }) {
    return [
      for (final t in StatusTransitionRules.allowed(
        rows,
        entityType: entityType,
        fromCode: fromCode,
        roles: {if (role != null && role.isNotEmpty) role},
        tenantId: tenantId,
      ))
        CrmTransition(
          fromCode: t.fromCode,
          toCode: t.toCode,
          requiresComment: t.requiresComment,
          requiresConfirmation: t.requiresConfirmation,
        ),
    ];
  }

  /// Hata metni geçersiz-geçiş mi? (EF `ERR_INVALID_TRANSITION`).
  static bool isInvalidTransitionError(Object e) {
    final s = e.toString();
    return s.contains('ERR_INVALID_TRANSITION') ||
        s.toLowerCase().contains('invalid transition');
  }
}

/// **CRM aşama servisi** — `status_definitions` (etiket/renk/sıra, DB'den;
/// sabit kod yok) + `status_transitions` (izinli geçişler) + geçiş yürütme
/// (`status-transition` EF). Web `PtbStatusService` paritesi.
class CrmStageService {
  CrmStageService({CrmBackend? backend, String Function(String key)? translate})
      : _backend = backend ?? SupabaseCrmBackend(),
        _translate = translate;

  final CrmBackend _backend;
  final String Function(String key)? _translate;

  final Map<String, Future<List<Map<String, dynamic>>>> _txRows = {};
  Future<String?>? _role;

  String _tr(String key) {
    final t = _translate;
    if (t != null) return t(key);
    return sl.isRegistered<LocalizationService>()
        ? sl<LocalizationService>().translate(key)
        : key;
  }

  /// Aşamalar (hata → boş liste; ekran boş durumu gösterir).
  Future<List<CrmStage>> loadStages(String entityType) async {
    try {
      final rows = await _backend.statusDefinitionRows(entityType);
      return CrmStageLogic.stagesFromRows(rows, _tr);
    } catch (e) {
      Logger.error('crm loadStages($entityType) hata', e);
      return const [];
    }
  }

  /// [fromCode]'dan izinli geçişler (tip başına satırlar bir kez çekilir).
  Future<List<CrmTransition>> availableTransitions(
      String entityType, String fromCode) async {
    try {
      final rows = await (_txRows[entityType] ??=
          _backend.statusTransitionRows(entityType));
      final role = await (_role ??= _backend.currentRole());
      return CrmStageLogic.transitionsFrom(rows,
          entityType: entityType,
          fromCode: fromCode,
          role: role,
          tenantId: TenantScope().tenantId);
    } catch (e) {
      _txRows.remove(entityType);
      Logger.error('crm transitions($entityType/$fromCode) hata', e);
      return const [];
    }
  }

  /// Geçişi yürüt — `status-transition` EF. Hata fırlatır (ekran mesajlar).
  /// Sihirbaz-yalnız hedef (lead→converted) burada da reddedilir.
  Future<void> move({
    required String entityType,
    required String entityId,
    required String toStatus,
    String? comment,
  }) async {
    if (CrmStageLogic.isWizardOnly(entityType, toStatus)) {
      throw StateError('wizard-only transition: $entityType→$toStatus');
    }
    await _backend.executeTransition(
      entityType: entityType,
      entityId: entityId,
      toStatus: toStatus,
      comment: comment,
    );
  }
}

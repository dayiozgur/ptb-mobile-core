import 'package:flutter/material.dart';

import '../../../core/entity/models/generic_entity.dart';
import '../../../core/entity/status_transition_rules.dart';

/// Entity detay ekranı için app-bar aksiyonları üreten fonksiyon.
typedef EntityActionsBuilder = List<Widget> Function(
  BuildContext context,
  GenericEntity entity,
  Future<void> Function() reload,
);

/// Entity detay gövdesine eklenecek bölümleri üreten fonksiyon
/// (form ile yorumlar arasına yerleşir).
typedef EntitySectionsBuilder = List<Widget> Function(
  BuildContext context,
  GenericEntity entity,
  Future<void> Function() reload,
);

/// A type-specific step around a status transition started from the entity
/// detail screen (e.g. CRM won/lost reason). Returned by an
/// [EntityTransitionHook] after the user picked the transition and BEFORE the
/// `status-transition` EF runs; [afterSuccess] runs only when the EF accepted
/// the move.
class EntityTransitionPlan {
  final Future<void> Function(BuildContext context)? afterSuccess;

  const EntityTransitionPlan({this.afterSuccess});

  /// Proceed without extra work.
  static const EntityTransitionPlan proceed = EntityTransitionPlan();
}

/// Called with the picked transition; returns the plan, or null to cancel the
/// transition (the user dismissed the domain prompt).
typedef EntityTransitionHook = Future<EntityTransitionPlan?> Function(
  BuildContext context,
  GenericEntity entity,
  AllowedStatusTransition transition,
);

/// **Entity detay eklenti kaydı** — generic [EntityDetailScreen]'i platforma/
/// tipe özel AKSİYON ve BÖLÜM'lerle genişletir; çekirdek platform-nötr kalır,
/// her app kendi domain-aksiyonlarını (CRM: sonraki-adım/aktivite-tamamla;
/// PPM: worklog; PHR: onay) `main()`'de kaydeder.
///
/// Anahtar = entity tip-kodu (ör. `'deal'`) ya da tüm tipler için `'*'`.
/// ```dart
/// EntityDetailExtensions.registerActions('deal', (ctx, e, reload) => [...]);
/// EntityDetailExtensions.registerSections('deal', (ctx, e, reload) => [...]);
/// ```
class EntityDetailExtensions {
  EntityDetailExtensions._();

  static const String all = '*';
  static final Map<String, EntityActionsBuilder> _actions = {};
  static final Map<String, EntitySectionsBuilder> _sections = {};
  static final Map<String, EntityTransitionHook> _transitionHooks = {};

  static void registerActions(String typeCode, EntityActionsBuilder builder) {
    _actions[typeCode] = builder;
  }

  static void registerSections(String typeCode, EntitySectionsBuilder builder) {
    _sections[typeCode] = builder;
  }

  /// [typeCode] için durum-geçişi kancası kaydet (tip başına bir tane).
  static void registerTransitionHook(String typeCode, EntityTransitionHook hook) {
    _transitionHooks[typeCode] = hook;
  }

  /// [typeCode] için kayıtlı geçiş planı; kanca yoksa [EntityTransitionPlan.proceed].
  /// null → kullanıcı vazgeçti, geçiş yürütülmez.
  static Future<EntityTransitionPlan?> planTransition(
    BuildContext context,
    String typeCode,
    GenericEntity entity,
    AllowedStatusTransition transition,
  ) async {
    final hook = _transitionHooks[typeCode];
    if (hook == null) return EntityTransitionPlan.proceed;
    return hook(context, entity, transition);
  }

  /// [typeCode] + `'*'` için kayıtlı tüm aksiyonları birleştirir.
  static List<Widget> actionsFor(
    BuildContext context,
    String typeCode,
    GenericEntity entity,
    Future<void> Function() reload,
  ) {
    final out = <Widget>[];
    final a = _actions[all];
    if (a != null) out.addAll(a(context, entity, reload));
    final t = _actions[typeCode];
    if (t != null) out.addAll(t(context, entity, reload));
    return out;
  }

  /// [typeCode] + `'*'` için kayıtlı tüm bölümleri birleştirir.
  static List<Widget> sectionsFor(
    BuildContext context,
    String typeCode,
    GenericEntity entity,
    Future<void> Function() reload,
  ) {
    final out = <Widget>[];
    final a = _sections[all];
    if (a != null) out.addAll(a(context, entity, reload));
    final t = _sections[typeCode];
    if (t != null) out.addAll(t(context, entity, reload));
    return out;
  }
}

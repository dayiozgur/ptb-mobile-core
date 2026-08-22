import 'package:flutter/material.dart';

import '../../../core/entity/models/generic_entity.dart';

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

  static void registerActions(String typeCode, EntityActionsBuilder builder) {
    _actions[typeCode] = builder;
  }

  static void registerSections(String typeCode, EntitySectionsBuilder builder) {
    _sections[typeCode] = builder;
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

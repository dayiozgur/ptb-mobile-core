import 'package:supabase_flutter/supabase_flutter.dart';

/// Builder tabloları (entity_type_configs, form_templates, pb_page_templates,
/// dr_report_templates, dr_data_sources, wf_workflow_templates,
/// status_definitions, tm_packages) için platform görünürlük filtresi.
///
/// Semantik (web ile birebir):
/// - `platform_id` dolu → yalnız o platform (exclusive)
/// - `platform_id` NULL ve `platform_ids` NULL → tüm platformlar
/// - `platform_id` NULL ve `platform_ids` dolu → yalnız listedekiler
///
/// DİKKAT: Entity veri tablolarında (`form_submissions` vb.) `platform_ids`
/// kolonu YOK — bu filtre orada 42703 verir; yalnız builder tablolarında kullan.
class BuilderPlatformFilter {
  BuilderPlatformFilter._();

  /// PostgREST `or=(...)` gövdesi: bilinen platform için görünürlük koşulu.
  static String orFilter(String platformId) =>
      'platform_id.eq.$platformId,'
      'and(platform_id.is.null,or(platform_ids.is.null,platform_ids.cs.{$platformId}))';

  /// Yalnız BU platforma kapsamlı satırlar (tüm-platform paylaşımlıları
  /// HARİÇ): `platform_id = X` veya `platform_id IS NULL AND platform_ids ∋ X`.
  /// Web `PtbEntityMenuProvider` `platformScopedOnly` (applyPlatformFilter +
  /// isPlatformScoped) ile birebir — PHR/PMS/CRM/PMP entity menüsü.
  static String scopedOnlyOrFilter(String platformId) =>
      'platform_id.eq.$platformId,'
      'and(platform_id.is.null,platform_ids.cs.{$platformId})';

  /// [query]'ye platform filtresini uygular. Bilinmeyen platform (null/boş)
  /// → yalnız tüm-platform paylaşımlı satırlar
  /// (`platform_id IS NULL AND platform_ids IS NULL`).
  static PostgrestFilterBuilder<T> apply<T>(
    PostgrestFilterBuilder<T> query,
    String? platformId,
  ) {
    if (platformId == null || platformId.isEmpty) {
      return query.isFilter('platform_id', null).isFilter('platform_ids', null);
    }
    return query.or(orFilter(platformId));
  }
}

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/page_viewer/models/page_template.dart';
import '../platform/platform_context.dart';
import '../reporting/page_service.dart';
import '../reporting/report_query_service.dart';
import '../storage/cache_manager.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';

/// Kaynak: widget kullanıcının EKLEDİĞİ mi yoksa temel şablondan mı geliyor?
///
/// - [base]: personal-dashboard builder şablonundaki (`pb_page_widgets`) widget.
///   Kaldırma → `customizations.hiddenWidgets`.
/// - [added]: kullanıcının katalogdan eklediği widget.
///   Kaldırma → listeden çıkarılır.
enum DashboardWidgetSource { base, added }

/// Herhangi bir değeri (Map | JSON String | diğer) `Map<String,dynamic>`'e çevirir.
Map<String, dynamic> _mapOf(dynamic value) {
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// Panodaki tek bir widget'ın düz, serileştirilebilir tanımı.
///
/// Web `PageWidget` + `pb_page_instances.customizations` sözleşmesiyle
/// uyumludur: eklenen widget'lar `addedWidgets` içine web ile AYNI camelCase
/// anahtarlarla yazılır (`widgetType`, `dataSourceId`, `queryConfig`,
/// `gridColumn` …), böylece web `<ptb-page-viewer>` ve mobil aynı satırı okur.
class DashboardWidgetDescriptor {
  /// Sıralama/kaldırma anahtarı (base = `pb_page_widgets.code`,
  /// added = `user-<benzersiz>`).
  final String id;

  /// Widget tipi (`stat_card`, `chart_widget`, `data_table`, `text_block`,
  /// `heading`, `divider`, `link_card` …).
  final String type;

  /// Kart başlığı (opsiyonel).
  final String? title;

  /// Kart alt başlığı (opsiyonel).
  final String? subtitle;

  /// Görsel + statik içerik yapılandırması.
  final Map<String, dynamic> config;

  /// Veri kaynağı UUID'i (data-backed widget'lar için — `report-query`).
  final String? dataSourceId;

  /// Sorgu yapılandırması (measures/dimensions/filters).
  final Map<String, dynamic> queryConfig;

  /// Grid kolon aralığı (ör. `'span 6'`). Mobilde tek kolon yığılır; web korur.
  final String gridColumn;

  /// Widget'ın kaynağı (kaldırma davranışını belirler).
  final DashboardWidgetSource source;

  const DashboardWidgetDescriptor({
    required this.id,
    required this.type,
    this.title,
    this.subtitle,
    this.config = const {},
    this.dataSourceId,
    this.queryConfig = const {},
    this.gridColumn = 'span 12',
    this.source = DashboardWidgetSource.added,
  });

  /// `report-query` ile veri çekilmesi gereken bir widget mı?
  bool get isDataBacked {
    final ds = dataSourceId;
    if (ds == null || ds.isEmpty) return false;
    switch (type) {
      case 'chart_widget':
      case 'data_table':
        return true;
      case 'stat_card':
        return config['value'] == null;
      default:
        return false;
    }
  }

  DashboardWidgetDescriptor copyWith({DashboardWidgetSource? source}) {
    return DashboardWidgetDescriptor(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      config: config,
      dataSourceId: dataSourceId,
      queryConfig: queryConfig,
      gridColumn: gridColumn,
      source: source ?? this.source,
    );
  }

  /// Temel şablon widget'ından (`pb_page_widgets`) tanım üretir.
  factory DashboardWidgetDescriptor.fromPageWidget(PageWidget w) {
    return DashboardWidgetDescriptor(
      id: w.code,
      type: w.widgetType,
      title: w.title,
      subtitle: w.subtitle,
      config: w.config,
      dataSourceId: w.dataSourceId,
      queryConfig: w.queryConfig,
      gridColumn: w.gridColumn,
      source: DashboardWidgetSource.base,
    );
  }

  /// `customizations.addedWidgets` (web camelCase) satırından çözer.
  factory DashboardWidgetDescriptor.fromAddedJson(Map<String, dynamic> json) {
    return DashboardWidgetDescriptor(
      id: (json['id'] ?? json['code'])?.toString() ?? '',
      type: json['widgetType']?.toString() ?? 'unknown',
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      config: _mapOf(json['config']),
      dataSourceId: json['dataSourceId']?.toString(),
      queryConfig: _mapOf(json['queryConfig']),
      gridColumn: json['gridColumn']?.toString() ?? 'span 12',
      source: DashboardWidgetSource.added,
    );
  }

  /// `customizations.addedWidgets` için web-uyumlu (camelCase) çıktı.
  Map<String, dynamic> toAddedJson() {
    return <String, dynamic>{
      'id': id,
      'code': id,
      'title': title,
      'subtitle': subtitle,
      'widgetType': type,
      'config': config,
      'dataSourceId': dataSourceId,
      'queryConfig': queryConfig,
      'gridColumn': gridColumn,
      'gridRow': 'auto',
      'sortOrder': 999,
    };
  }

  /// Yerel önbellek (backend şablon yoksa) için tam serileştirme.
  Map<String, dynamic> toLocalJson() {
    final map = toAddedJson();
    map['source'] = source.name;
    return map;
  }

  /// Yerel önbellek satırından çözer.
  factory DashboardWidgetDescriptor.fromLocalJson(Map<String, dynamic> json) {
    final base = DashboardWidgetDescriptor.fromAddedJson(json);
    final src = json['source']?.toString() == 'base'
        ? DashboardWidgetSource.base
        : DashboardWidgetSource.added;
    return base.copyWith(source: src);
  }
}

/// Kişisel pano ("Panom") kalıcılık + katalog servisi.
///
/// **Backend sözleşmesi (web ile birebir):** platforma göre bir kişisel-pano
/// şablonu (`pb_page_templates.code` = `my-dashboard-pms` | `my-dashboard-hr`
/// | `my-dashboard`) çözülür; kullanıcının seçimleri `pb_page_instances`
/// satırındaki `customizations` JSONB'sinde saklanır:
///   - `hiddenWidgets`  → kaldırılan temel widget kodları,
///   - `widgetOrder`    → görüntü sırası (id listesi),
///   - `addedWidgets`   → katalogdan eklenen widget'lar (camelCase).
/// Kullanıcı+şablon başına tek aktif satır (check-then-insert/update).
///
/// **Yerel geri düşüş:** platform için kişisel-pano şablonu YOKSA
/// (`pb_page_instances.page_template_id` NOT NULL olduğundan backend'e
/// yazılamaz), düzen kullanıcı kimliği + platform anahtarıyla [CacheManager]
/// içinde YEREL saklanır. Bu durumda bir backend deposu doğana kadar düzen
/// yalnız cihaz-yereldir (asla olmayan bir tabloya yazılmaz).
///
/// Widget içeriği, mobilde zaten kullanılan `report-query` yolu
/// ([ReportQueryService]) ile beslenir — ek veri katmanı gerekmez.
class PersonalDashboardService {
  final SupabaseClient _supabase;
  final PageService _pageService;
  final ReportQueryService _reportQueryService;
  final PlatformContext _platformContext;
  final TenantService _tenantService;
  final CacheManager _cacheManager;

  PersonalDashboardService({
    required SupabaseClient supabase,
    required PageService pageService,
    required ReportQueryService reportQueryService,
    required PlatformContext platformContext,
    required TenantService tenantService,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _pageService = pageService,
        _reportQueryService = reportQueryService,
        _platformContext = platformContext,
        _tenantService = tenantService,
        _cacheManager = cacheManager;

  static const String _instanceTable = 'pb_page_instances';

  /// Yerel-düzen önbelleği ~10 yıl (kalıcı sayılır; TTL süresi dolmasın).
  static const Duration _localTtl = Duration(days: 3650);

  /// Son çözülen temel şablon (katalog + kaydetme merge'i için).
  PageTemplate? _baseTemplate;

  /// Son okunan/ yazılan diğer customization alanları (kayıpsız güncelleme).
  Map<String, dynamic> _preservedCustomizations = <String, dynamic>{};

  /// Bu oturumdaki added-widget id sayaç ekseni (benzersiz id üretimi).
  int _idSeq = 0;

  // ─── Backend var mı? ────────────────────────────────────────────────────

  /// Aktif kimlik doğrulama kullanıcısı (yoksa yerel-mod bile anonim anahtar).
  String? get _userId => _supabase.auth.currentUser?.id;

  /// Platform koduna göre aday şablon kodları (özelden genele).
  List<String> _candidateCodes() {
    final code = (_platformContext.activePlatformCode ?? '').toUpperCase();
    switch (code) {
      case 'PMS':
        return const ['my-dashboard-pms', 'my-dashboard'];
      case 'PHR':
      case 'HR':
        return const ['my-dashboard-hr', 'my-dashboard'];
      default:
        return const ['my-dashboard'];
    }
  }

  /// İlk çözülebilen kişisel-pano şablonunu döner (yoksa null → yerel mod).
  Future<PageTemplate?> _resolveTemplate() async {
    for (final code in _candidateCodes()) {
      try {
        final tpl = await _pageService.getByCode(code);
        if (tpl != null) return tpl;
      } catch (e) {
        Logger.warning('Kişisel-pano şablonu çözülemedi: $code', e);
      }
    }
    return null;
  }

  // ─── loadLayout ─────────────────────────────────────────────────────────

  /// Kullanıcının seçili widget'larını SIRALI döner.
  ///
  /// Backend: temel şablon widget'ları (hiddenWidgets hariç) + addedWidgets,
  /// widgetOrder sırasında. İlk kez (instance yok) → temel şablonun tamamı.
  /// Şablon yoksa → yerel önbellekten okunan liste.
  Future<List<DashboardWidgetDescriptor>> loadLayout() async {
    final template = await _resolveTemplate();
    _baseTemplate = template;

    if (template == null) {
      return _loadLocal();
    }

    final custom = await _fetchCustomizations(template.id);
    _preservedCustomizations = <String, dynamic>{
      'widgetSizes': custom['widgetSizes'] ?? <String, dynamic>{},
      'activeTabStates': custom['activeTabStates'] ?? <String, dynamic>{},
      'templateVersion': custom['templateVersion'] ?? 1,
    };

    final hidden = _asStringList(custom['hiddenWidgets']).toSet();
    final order = _asStringList(custom['widgetOrder']);
    final added = _asMapList(custom['addedWidgets'])
        .map(DashboardWidgetDescriptor.fromAddedJson)
        .toList();

    final visibleBase = template.widgets
        .where((w) => !hidden.contains(w.code))
        .map(DashboardWidgetDescriptor.fromPageWidget)
        .toList();

    final merged = <DashboardWidgetDescriptor>[...visibleBase, ...added];
    _applyOrder(merged, order);
    return merged;
  }

  Future<List<DashboardWidgetDescriptor>> _loadLocal() async {
    try {
      final raw = await _cacheManager.get<dynamic>(_localKey());
      final list = _asMapList(raw)
          .map(DashboardWidgetDescriptor.fromLocalJson)
          .toList();
      return list;
    } catch (e) {
      Logger.warning('Yerel pano düzeni okunamadı', e);
      return const <DashboardWidgetDescriptor>[];
    }
  }

  // ─── saveLayout ─────────────────────────────────────────────────────────

  /// Güncel widget listesini (sıra + eklenen/kaldırılan) kalıcılaştırır.
  ///
  /// Backend: hiddenWidgets = listede OLMAYAN temel widget kodları,
  /// addedWidgets = kaynağı [DashboardWidgetSource.added] olanlar,
  /// widgetOrder = liste sırası. Şablon yoksa → yerel önbelleğe yazar.
  Future<void> saveLayout(List<DashboardWidgetDescriptor> widgets) async {
    final template = _baseTemplate;
    if (template == null) {
      await _saveLocal(widgets);
      return;
    }

    final baseCodes = template.widgets.map((w) => w.code).toSet();
    final presentIds = widgets.map((w) => w.id).toSet();

    final hiddenWidgets =
        baseCodes.where((c) => !presentIds.contains(c)).toList();
    final addedWidgets = widgets
        .where((w) => w.source == DashboardWidgetSource.added)
        .map((w) => w.toAddedJson())
        .toList();
    final widgetOrder = widgets.map((w) => w.id).toList();

    final customizations = <String, dynamic>{
      'hiddenWidgets': hiddenWidgets,
      'widgetOrder': widgetOrder,
      'addedWidgets': addedWidgets,
      'widgetSizes': _preservedCustomizations['widgetSizes'] ?? <String, dynamic>{},
      'activeTabStates':
          _preservedCustomizations['activeTabStates'] ?? <String, dynamic>{},
      'templateVersion': _preservedCustomizations['templateVersion'] ?? 1,
    };

    await _upsertInstance(template.id, customizations);
  }

  Future<void> _saveLocal(List<DashboardWidgetDescriptor> widgets) async {
    final payload = widgets.map((w) => w.toLocalJson()).toList();
    await _cacheManager.set(_localKey(), payload, ttl: _localTtl);
  }

  // ─── availableWidgets (katalog) ─────────────────────────────────────────

  /// Kullanıcının EKLEYEBİLECEĞİ widget kataloğu.
  ///
  /// (a) Çözülen temel şablonun kendi data-backed widget'ları — gerçek veriyle
  /// render olur; (b) her platformda render edilebilen statik hazır widget'lar
  /// (Not/Metin, Başlık, Ayraç). [loadLayout] çağrıldıktan sonra kullanın.
  List<DashboardWidgetDescriptor> availableWidgets() {
    final catalog = <DashboardWidgetDescriptor>[];
    final template = _baseTemplate;
    if (template != null) {
      catalog.addAll(
        template.widgets.map(DashboardWidgetDescriptor.fromPageWidget),
      );
    }
    catalog.addAll(_staticPresets());
    return catalog;
  }

  /// Statik (veri-kaynaksız) hazır widget'lar — mobilde birebir render edilir.
  List<DashboardWidgetDescriptor> _staticPresets() {
    return <DashboardWidgetDescriptor>[
      const DashboardWidgetDescriptor(
        id: '__preset_text',
        type: 'text_block',
        title: 'Not / Metin',
        config: {'text': 'Notunuzu buraya yazın…'},
        gridColumn: 'span 6',
      ),
      const DashboardWidgetDescriptor(
        id: '__preset_heading',
        type: 'heading',
        title: 'Başlık',
        config: {'text': 'Başlık'},
        gridColumn: 'span 12',
      ),
      const DashboardWidgetDescriptor(
        id: '__preset_divider',
        type: 'divider',
        title: 'Ayraç',
        config: {},
        gridColumn: 'span 12',
      ),
    ];
  }

  /// Katalog seçimini panoya eklenebilir benzersiz-id'li tanıma dönüştürür.
  ///
  /// Temel (base) widget'lar kimliklerini KORUR (hidden'dan geri gelmeleri için);
  /// statik hazır/eklenen widget'lar yeni `user-<benzersiz>` id alır.
  DashboardWidgetDescriptor instantiateForAdd(DashboardWidgetDescriptor c) {
    if (c.source == DashboardWidgetSource.base) return c;
    return DashboardWidgetDescriptor(
      id: _newAddedId(),
      type: c.type,
      title: c.title,
      subtitle: c.subtitle,
      config: c.config,
      dataSourceId: c.dataSourceId,
      queryConfig: c.queryConfig,
      gridColumn: c.gridColumn,
      source: DashboardWidgetSource.added,
    );
  }

  // ─── Widget verisi (report-query) ───────────────────────────────────────

  /// Data-backed bir widget için satırları getirir (mobil `report-query` yolu).
  Future<List<Map<String, dynamic>>> fetchWidgetData(
    DashboardWidgetDescriptor w,
  ) {
    return _reportQueryService.runWidget(
      dataSourceId: w.dataSourceId!,
      queryConfig: w.queryConfig,
    );
  }

  // ─── Backend pb_page_instances yardımcıları ─────────────────────────────

  Future<Map<String, dynamic>> _fetchCustomizations(
    String pageTemplateId,
  ) async {
    final data = await _supabase
        .from(_instanceTable)
        .select('customizations')
        .eq('page_template_id', pageTemplateId)
        .eq('active', true)
        .maybeSingle();
    if (data == null) return <String, dynamic>{};
    return _asMap(data['customizations']);
  }

  Future<void> _upsertInstance(
    String pageTemplateId,
    Map<String, dynamic> customizations,
  ) async {
    final userId = _userId;
    final existing = await _supabase
        .from(_instanceTable)
        .select('id')
        .eq('page_template_id', pageTemplateId)
        .eq('active', true)
        .maybeSingle();

    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (existing != null) {
      await _supabase.from(_instanceTable).update(<String, dynamic>{
        'customizations': customizations,
        'updated_by': userId,
        'updated_at': nowIso,
      }).eq('id', existing['id']);
      return;
    }

    await _supabase.from(_instanceTable).insert(<String, dynamic>{
      'tenant_id': _tenantService.currentTenantId,
      'page_template_id': pageTemplateId,
      'user_id': userId,
      'customizations': customizations,
      'active': true,
      'created_by': userId,
      'updated_by': userId,
    });
  }

  // ─── Küçük yardımcılar ──────────────────────────────────────────────────

  String _localKey() {
    final uid = _userId ?? 'anon';
    return 'personal_dashboard_layout_${uid}_${_platformContext.activePlatformId}';
  }

  String _newAddedId() {
    _idSeq++;
    return 'user-${DateTime.now().microsecondsSinceEpoch}-$_idSeq';
  }

  /// [merged] listesini [order] (id listesi) sırasına göre stabil sıralar.
  /// Order'da olmayanlar mevcut sıralarını koruyarak sona eklenir.
  void _applyOrder(List<DashboardWidgetDescriptor> merged, List<String> order) {
    if (order.isEmpty) return;
    final rank = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      rank[order[i]] = i;
    }
    final indexed = <MapEntry<int, DashboardWidgetDescriptor>>[];
    for (var i = 0; i < merged.length; i++) {
      indexed.add(MapEntry(i, merged[i]));
    }
    indexed.sort((a, b) {
      final ra = rank[a.value.id];
      final rb = rank[b.value.id];
      if (ra != null && rb != null) return ra.compareTo(rb);
      if (ra != null) return -1; // sıralı olanlar önce
      if (rb != null) return 1;
      return a.key.compareTo(b.key); // ikisi de sırasız → özgün sıra
    });
    final sorted = indexed.map((e) => e.value).toList();
    merged
      ..clear()
      ..addAll(sorted);
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const <String>[];
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is String && value.isNotEmpty) {
      try {
        return _asMapList(jsonDecode(value));
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _asMap(dynamic value) => _mapOf(value);
}

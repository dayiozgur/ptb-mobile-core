/// Search modelleri
///
/// Arama sorguları, sonuçları ve öneriler için
/// veri modelleri.

/// Arama varlık türü
enum SearchEntityType {
  all('ALL', 'Tümü'),
  organization('ORGANIZATION', 'Organizasyon'),
  site('SITE', 'Tesis'),
  unit('UNIT', 'Ünite'),
  user('USER', 'Kullanıcı'),
  activity('ACTIVITY', 'Aktivite');

  final String value;
  final String label;
  const SearchEntityType(this.value, this.label);

  static SearchEntityType? fromString(String? value) {
    if (value == null) return null;
    return SearchEntityType.values.cast<SearchEntityType?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }

  /// İkon adı
  String get iconName {
    switch (this) {
      case SearchEntityType.all:
        return 'search';
      case SearchEntityType.organization:
        return 'business';
      case SearchEntityType.site:
        return 'location_city';
      case SearchEntityType.unit:
        return 'widgets';
      case SearchEntityType.user:
        return 'person';
      case SearchEntityType.activity:
        return 'timeline';
    }
  }
}

/// Arama sorgusu
class SearchQuery {
  final String text;
  final SearchEntityType entityType;
  final String? tenantId;
  final String? organizationId;
  final String? siteId;
  final int limit;
  final int offset;
  final Map<String, dynamic>? filters;
  final List<String>? sortBy;
  final bool ascending;

  const SearchQuery({
    required this.text,
    this.entityType = SearchEntityType.all,
    this.tenantId,
    this.organizationId,
    this.siteId,
    this.limit = 20,
    this.offset = 0,
    this.filters,
    this.sortBy,
    this.ascending = true,
  });

  /// Boş sorgu mu?
  bool get isEmpty => text.trim().isEmpty;

  /// Geçerli sorgu mu?
  bool get isValid => text.trim().length >= 2;

  /// Kopya oluştur
  SearchQuery copyWith({
    String? text,
    SearchEntityType? entityType,
    String? tenantId,
    String? organizationId,
    String? siteId,
    int? limit,
    int? offset,
    Map<String, dynamic>? filters,
    List<String>? sortBy,
    bool? ascending,
  }) {
    return SearchQuery(
      text: text ?? this.text,
      entityType: entityType ?? this.entityType,
      tenantId: tenantId ?? this.tenantId,
      organizationId: organizationId ?? this.organizationId,
      siteId: siteId ?? this.siteId,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      filters: filters ?? this.filters,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'entity_type': entityType.value,
        'tenant_id': tenantId,
        'organization_id': organizationId,
        'site_id': siteId,
        'limit': limit,
        'offset': offset,
        'filters': filters,
        'sort_by': sortBy,
        'ascending': ascending,
      };

  @override
  String toString() => 'SearchQuery("$text", type: ${entityType.value})';
}

/// Arama sonucu
class SearchResult {
  final String id;
  final SearchEntityType entityType;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? iconName;
  final String? color;
  final double? score;
  final Map<String, dynamic>? metadata;
  final List<String>? highlightedFields;

  const SearchResult({
    required this.id,
    required this.entityType,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.iconName,
    this.color,
    this.score,
    this.metadata,
    this.highlightedFields,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String,
      entityType:
          SearchEntityType.fromString(json['entity_type'] as String?) ??
              SearchEntityType.all,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      iconName: json['icon_name'] as String?,
      color: json['color'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      highlightedFields: (json['highlighted_fields'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType.value,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'image_url': imageUrl,
        'icon_name': iconName,
        'color': color,
        'score': score,
        'metadata': metadata,
        'highlighted_fields': highlightedFields,
      };

  /// Entity türüne göre icon
  String get effectiveIconName => iconName ?? entityType.iconName;

  @override
  String toString() => 'SearchResult($id, "${title}")';
}

/// Arama yanıtı
class SearchResponse {
  final SearchQuery query;
  final List<SearchResult> results;
  final int totalCount;
  final int offset;
  final bool hasMore;
  final Duration duration;
  final DateTime searchedAt;

  const SearchResponse({
    required this.query,
    required this.results,
    required this.totalCount,
    this.offset = 0,
    this.hasMore = false,
    required this.duration,
    required this.searchedAt,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      query: SearchQuery(text: json['query_text'] as String? ?? ''),
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCount: json['total_count'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
      duration: Duration(milliseconds: json['duration_ms'] as int? ?? 0),
      searchedAt: json['searched_at'] != null
          ? DateTime.parse(json['searched_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'query_text': query.text,
        'results': results.map((r) => r.toJson()).toList(),
        'total_count': totalCount,
        'offset': offset,
        'has_more': hasMore,
        'duration_ms': duration.inMilliseconds,
        'searched_at': searchedAt.toIso8601String(),
      };

  /// Boş sonuç mu?
  bool get isEmpty => results.isEmpty;

  /// Sonuç sayısı
  int get count => results.length;

  @override
  String toString() =>
      'SearchResponse(${results.length}/$totalCount results, ${duration.inMilliseconds}ms)';
}

/// Arama önerisi
class SearchSuggestion {
  final String text;
  final SearchEntityType? entityType;
  final String? iconName;
  final SuggestionType type;
  final int? count;
  final double? relevance;

  const SearchSuggestion({
    required this.text,
    this.entityType,
    this.iconName,
    this.type = SuggestionType.query,
    this.count,
    this.relevance,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      text: json['text'] as String,
      entityType: SearchEntityType.fromString(json['entity_type'] as String?),
      iconName: json['icon_name'] as String?,
      type:
          SuggestionType.fromString(json['type'] as String?) ??
              SuggestionType.query,
      count: json['count'] as int?,
      relevance: (json['relevance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'entity_type': entityType?.value,
        'icon_name': iconName,
        'type': type.value,
        'count': count,
        'relevance': relevance,
      };

  @override
  String toString() => 'SearchSuggestion("$text", type: ${type.value})';
}

/// Öneri türü
enum SuggestionType {
  query('QUERY', 'Sorgu'),
  recent('RECENT', 'Son Aramalar'),
  popular('POPULAR', 'Popüler'),
  autocomplete('AUTOCOMPLETE', 'Otomatik Tamamla');

  final String value;
  final String label;
  const SuggestionType(this.value, this.label);

  static SuggestionType? fromString(String? value) {
    if (value == null) return null;
    return SuggestionType.values.cast<SuggestionType?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Son arama kaydı
class RecentSearch {
  final String id;
  final String query;
  final SearchEntityType? entityType;
  final DateTime searchedAt;
  final int resultCount;

  const RecentSearch({
    required this.id,
    required this.query,
    this.entityType,
    required this.searchedAt,
    this.resultCount = 0,
  });

  factory RecentSearch.fromJson(Map<String, dynamic> json) {
    return RecentSearch(
      id: json['id'] as String,
      query: json['query'] as String,
      entityType: SearchEntityType.fromString(json['entity_type'] as String?),
      searchedAt: DateTime.parse(json['searched_at'] as String),
      resultCount: json['result_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'entity_type': entityType?.value,
        'searched_at': searchedAt.toIso8601String(),
        'result_count': resultCount,
      };

  @override
  String toString() => 'RecentSearch("$query", ${searchedAt.toIso8601String()})';
}

/// Arama filtresi
class SearchFilter {
  final String field;
  final SearchFilterOperator operator;
  final dynamic value;

  const SearchFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  factory SearchFilter.fromJson(Map<String, dynamic> json) {
    return SearchFilter(
      field: json['field'] as String,
      operator:
          SearchFilterOperator.fromString(json['operator'] as String?) ??
              SearchFilterOperator.equals,
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() => {
        'field': field,
        'operator': operator.value,
        'value': value,
      };
}

/// Filtre operatörü
enum SearchFilterOperator {
  equals('EQ', '='),
  notEquals('NEQ', '!='),
  contains('CONTAINS', 'içerir'),
  startsWith('STARTS_WITH', 'ile başlar'),
  endsWith('ENDS_WITH', 'ile biter'),
  greaterThan('GT', '>'),
  greaterThanOrEqual('GTE', '>='),
  lessThan('LT', '<'),
  lessThanOrEqual('LTE', '<='),
  inList('IN', 'içinde'),
  notInList('NOT_IN', 'dışında'),
  isNull('IS_NULL', 'boş'),
  isNotNull('IS_NOT_NULL', 'dolu');

  final String value;
  final String label;
  const SearchFilterOperator(this.value, this.label);

  static SearchFilterOperator? fromString(String? value) {
    if (value == null) return null;
    return SearchFilterOperator.values.cast<SearchFilterOperator?>().firstWhere(
          (e) => e?.value == value,
          orElse: () => null,
        );
  }
}

/// Arama ayarları
class SearchSettings {
  final bool enableFuzzySearch;
  final bool enableTypoTolerance;
  final int minQueryLength;
  final int maxResults;
  final int debounceMs;
  final List<SearchEntityType> enabledEntityTypes;
  final bool saveRecentSearches;
  final int maxRecentSearches;

  const SearchSettings({
    this.enableFuzzySearch = true,
    this.enableTypoTolerance = true,
    this.minQueryLength = 2,
    this.maxResults = 50,
    this.debounceMs = 300,
    this.enabledEntityTypes = const [
      SearchEntityType.organization,
      SearchEntityType.site,
      SearchEntityType.unit,
    ],
    this.saveRecentSearches = true,
    this.maxRecentSearches = 10,
  });

  factory SearchSettings.fromJson(Map<String, dynamic> json) {
    return SearchSettings(
      enableFuzzySearch: json['enable_fuzzy_search'] as bool? ?? true,
      enableTypoTolerance: json['enable_typo_tolerance'] as bool? ?? true,
      minQueryLength: json['min_query_length'] as int? ?? 2,
      maxResults: json['max_results'] as int? ?? 50,
      debounceMs: json['debounce_ms'] as int? ?? 300,
      enabledEntityTypes: (json['enabled_entity_types'] as List<dynamic>?)
              ?.map((e) => SearchEntityType.fromString(e as String))
              .whereType<SearchEntityType>()
              .toList() ??
          const [
            SearchEntityType.organization,
            SearchEntityType.site,
            SearchEntityType.unit,
          ],
      saveRecentSearches: json['save_recent_searches'] as bool? ?? true,
      maxRecentSearches: json['max_recent_searches'] as int? ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'enable_fuzzy_search': enableFuzzySearch,
        'enable_typo_tolerance': enableTypoTolerance,
        'min_query_length': minQueryLength,
        'max_results': maxResults,
        'debounce_ms': debounceMs,
        'enabled_entity_types':
            enabledEntityTypes.map((e) => e.value).toList(),
        'save_recent_searches': saveRecentSearches,
        'max_recent_searches': maxRecentSearches,
      };

  SearchSettings copyWith({
    bool? enableFuzzySearch,
    bool? enableTypoTolerance,
    int? minQueryLength,
    int? maxResults,
    int? debounceMs,
    List<SearchEntityType>? enabledEntityTypes,
    bool? saveRecentSearches,
    int? maxRecentSearches,
  }) {
    return SearchSettings(
      enableFuzzySearch: enableFuzzySearch ?? this.enableFuzzySearch,
      enableTypoTolerance: enableTypoTolerance ?? this.enableTypoTolerance,
      minQueryLength: minQueryLength ?? this.minQueryLength,
      maxResults: maxResults ?? this.maxResults,
      debounceMs: debounceMs ?? this.debounceMs,
      enabledEntityTypes: enabledEntityTypes ?? this.enabledEntityTypes,
      saveRecentSearches: saveRecentSearches ?? this.saveRecentSearches,
      maxRecentSearches: maxRecentSearches ?? this.maxRecentSearches,
    );
  }
}

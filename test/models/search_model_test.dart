import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  // API drift: enum `value`s are now UPPERCASE codes and lookups use nullable
  // `fromString` (not `fromValue`). SearchQuery takes a single `entityType`
  // (the `entityTypes` list, `hasFilters` and `SearchQuery.defaultQuery()` were
  // removed). SearchResult/SearchResponse JSON use snake_case keys; SearchResult
  // has no `hasImage` getter and no value-equality override. SearchResponse now
  // requires `duration` + `searchedAt`, `fromJson` reads a flat `query_text`,
  // and `empty()`/`resultsByType` were removed. SearchSuggestion.type is a
  // `SuggestionType`. RecentSearch requires `id` and uses `searchedAt` (not
  // `timestamp`). SearchSettings uses `debounceMs` (no debounceMilliseconds/
  // highlightMatches/debounceDuration).
  group('SearchEntityType', () {
    test('has correct values', () {
      expect(SearchEntityType.organization.value, 'ORGANIZATION');
      expect(SearchEntityType.site.value, 'SITE');
      expect(SearchEntityType.unit.value, 'UNIT');
      expect(SearchEntityType.user.value, 'USER');
      expect(SearchEntityType.activity.value, 'ACTIVITY');
      expect(SearchEntityType.all.value, 'ALL');
    });

    test('has correct labels', () {
      expect(SearchEntityType.organization.label, 'Organizasyon');
      expect(SearchEntityType.site.label, 'Tesis');
      expect(SearchEntityType.unit.label, 'Ünite');
      expect(SearchEntityType.user.label, 'Kullanıcı');
      expect(SearchEntityType.activity.label, 'Aktivite');
      expect(SearchEntityType.all.label, 'Tümü');
    });

    test('has correct icons', () {
      expect(SearchEntityType.organization.iconName, 'business');
      expect(SearchEntityType.site.iconName, 'location_city');
      expect(SearchEntityType.unit.iconName, 'widgets');
      expect(SearchEntityType.user.iconName, 'person');
      expect(SearchEntityType.activity.iconName, 'timeline');
    });

    test('fromString returns correct type', () {
      expect(SearchEntityType.fromString('ORGANIZATION'),
          SearchEntityType.organization);
      expect(SearchEntityType.fromString('SITE'), SearchEntityType.site);
      expect(SearchEntityType.fromString('ALL'), SearchEntityType.all);
    });

    test('fromString returns null for invalid value', () {
      expect(SearchEntityType.fromString('invalid'), isNull);
      expect(SearchEntityType.fromString(null), isNull);
    });
  });

  group('SearchQuery', () {
    test('creates correctly', () {
      const query = SearchQuery(
        text: 'test query',
        entityType: SearchEntityType.organization,
        limit: 20,
        offset: 0,
      );

      expect(query.text, 'test query');
      expect(query.entityType, SearchEntityType.organization);
      expect(query.limit, 20);
      expect(query.offset, 0);
    });

    test('defaults to all entity types', () {
      const query = SearchQuery(text: 'test');
      expect(query.entityType, SearchEntityType.all);
    });

    test('toJson serializes correctly', () {
      const query = SearchQuery(
        text: 'test',
        entityType: SearchEntityType.organization,
        limit: 10,
        offset: 5,
      );

      final json = query.toJson();

      expect(json['text'], 'test');
      expect(json['entity_type'], 'ORGANIZATION');
      expect(json['limit'], 10);
      expect(json['offset'], 5);
    });

    test('copyWith creates correct copy', () {
      const query = SearchQuery(text: 'original', limit: 10);
      final copy = query.copyWith(text: 'updated', limit: 20);

      expect(copy.text, 'updated');
      expect(copy.limit, 20);
    });

    test('isEmpty returns correct value', () {
      expect(const SearchQuery(text: '').isEmpty, true);
      expect(const SearchQuery(text: '   ').isEmpty, true);
      expect(const SearchQuery(text: 'test').isEmpty, false);
    });

    test('isValid returns correct value', () {
      expect(const SearchQuery(text: 'a').isValid, false);
      expect(const SearchQuery(text: 'ab').isValid, true);
    });
  });

  group('SearchResult', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'result-123',
        'entity_type': 'ORGANIZATION',
        'title': 'Test Organization',
        'subtitle': 'Subtitle text',
        'description': 'Description text',
        'image_url': 'https://example.com/image.png',
        'score': 0.95,
        'metadata': {'key': 'value'},
      };

      final result = SearchResult.fromJson(json);

      expect(result.id, 'result-123');
      expect(result.entityType, SearchEntityType.organization);
      expect(result.title, 'Test Organization');
      expect(result.subtitle, 'Subtitle text');
      expect(result.description, 'Description text');
      expect(result.imageUrl, 'https://example.com/image.png');
      expect(result.score, 0.95);
      expect(result.metadata?['key'], 'value');
    });

    test('toJson serializes correctly', () {
      const result = SearchResult(
        id: 'result-123',
        entityType: SearchEntityType.site,
        title: 'Test Site',
        subtitle: 'Subtitle',
        score: 0.8,
      );

      final json = result.toJson();

      expect(json['id'], 'result-123');
      expect(json['entity_type'], 'SITE');
      expect(json['title'], 'Test Site');
      expect(json['subtitle'], 'Subtitle');
      expect(json['score'], 0.8);
    });

    test('effectiveIconName falls back to entity type icon', () {
      const result = SearchResult(
        id: '1',
        entityType: SearchEntityType.unit,
        title: 'Test',
      );
      expect(result.effectiveIconName, 'widgets');

      const withIcon = SearchResult(
        id: '2',
        entityType: SearchEntityType.unit,
        title: 'Test',
        iconName: 'custom_icon',
      );
      expect(withIcon.effectiveIconName, 'custom_icon');
    });
  });

  group('SearchResponse', () {
    test('creates correctly', () {
      const results = [
        SearchResult(
          id: '1',
          entityType: SearchEntityType.organization,
          title: 'Org 1',
        ),
        SearchResult(
          id: '2',
          entityType: SearchEntityType.site,
          title: 'Site 1',
        ),
      ];

      final response = SearchResponse(
        results: results,
        totalCount: 100,
        query: const SearchQuery(text: 'test'),
        hasMore: true,
        duration: const Duration(milliseconds: 12),
        searchedAt: DateTime(2024, 1, 15),
      );

      expect(response.results.length, 2);
      expect(response.totalCount, 100);
      expect(response.hasMore, true);
      expect(response.count, 2);
    });

    test('fromJson parses correctly', () {
      final json = {
        'results': [
          {
            'id': '1',
            'entity_type': 'ORGANIZATION',
            'title': 'Test',
          },
        ],
        'total_count': 50,
        'has_more': true,
        'query_text': 'test',
        'duration_ms': 12,
        'searched_at': '2024-01-15T10:00:00.000',
      };

      final response = SearchResponse.fromJson(json);

      expect(response.results.length, 1);
      expect(response.totalCount, 50);
      expect(response.hasMore, true);
      expect(response.query.text, 'test');
      expect(response.duration.inMilliseconds, 12);
    });

    test('isEmpty returns correct value', () {
      final emptyResponse = SearchResponse(
        results: const [],
        totalCount: 0,
        query: const SearchQuery(text: ''),
        hasMore: false,
        duration: Duration.zero,
        searchedAt: DateTime(2024, 1, 15),
      );
      expect(emptyResponse.isEmpty, true);

      final nonEmptyResponse = SearchResponse(
        results: const [
          SearchResult(id: '1', entityType: SearchEntityType.unit, title: 'Test'),
        ],
        totalCount: 1,
        query: const SearchQuery(text: 'test'),
        hasMore: false,
        duration: Duration.zero,
        searchedAt: DateTime(2024, 1, 15),
      );
      expect(nonEmptyResponse.isEmpty, false);
    });
  });

  group('SearchSuggestion', () {
    test('creates correctly', () {
      const suggestion = SearchSuggestion(
        text: 'suggested text',
        type: SuggestionType.query,
        entityType: SearchEntityType.organization,
      );

      expect(suggestion.text, 'suggested text');
      expect(suggestion.type, SuggestionType.query);
      expect(suggestion.entityType, SearchEntityType.organization);
    });

    test('fromJson parses correctly', () {
      final json = {
        'text': 'suggestion',
        'type': 'RECENT',
        'entity_type': 'SITE',
      };

      final suggestion = SearchSuggestion.fromJson(json);

      expect(suggestion.text, 'suggestion');
      expect(suggestion.type, SuggestionType.recent);
      expect(suggestion.entityType, SearchEntityType.site);
    });
  });

  group('RecentSearch', () {
    test('creates correctly', () {
      final search = RecentSearch(
        id: 'rs-1',
        query: 'recent search',
        entityType: SearchEntityType.unit,
        searchedAt: DateTime(2024, 1, 15),
      );

      expect(search.id, 'rs-1');
      expect(search.query, 'recent search');
      expect(search.entityType, SearchEntityType.unit);
      expect(search.searchedAt.year, 2024);
    });

    test('toJson serializes correctly', () {
      final search = RecentSearch(
        id: 'rs-1',
        query: 'test',
        entityType: SearchEntityType.user,
        searchedAt: DateTime(2024, 1, 15, 10, 30),
      );

      final json = search.toJson();

      expect(json['id'], 'rs-1');
      expect(json['query'], 'test');
      expect(json['entity_type'], 'USER');
      expect(json['searched_at'], isA<String>());
    });

    test('fromJson parses correctly', () {
      final json = {
        'id': 'rs-1',
        'query': 'test',
        'entity_type': 'ACTIVITY',
        'searched_at': '2024-01-15T10:30:00.000',
      };

      final search = RecentSearch.fromJson(json);

      expect(search.query, 'test');
      expect(search.entityType, SearchEntityType.activity);
      expect(search.searchedAt.year, 2024);
    });
  });

  group('SearchFilter', () {
    test('creates correctly', () {
      const filter = SearchFilter(
        field: 'status',
        operator: SearchFilterOperator.equals,
        value: 'active',
      );

      expect(filter.field, 'status');
      expect(filter.operator, SearchFilterOperator.equals);
      expect(filter.value, 'active');
    });

    test('toJson serializes correctly', () {
      const filter = SearchFilter(
        field: 'createdAt',
        operator: SearchFilterOperator.greaterThan,
        value: '2024-01-01',
      );

      final json = filter.toJson();

      expect(json['field'], 'createdAt');
      expect(json['operator'], 'GT');
      expect(json['value'], '2024-01-01');
    });
  });

  group('SearchSettings', () {
    test('creates with defaults', () {
      const settings = SearchSettings();

      expect(settings.minQueryLength, 2);
      expect(settings.debounceMs, 300);
      expect(settings.maxRecentSearches, 10);
      expect(settings.enableFuzzySearch, true);
    });

    test('custom settings work', () {
      const settings = SearchSettings(
        minQueryLength: 3,
        debounceMs: 500,
        maxRecentSearches: 5,
        enableFuzzySearch: false,
      );

      expect(settings.minQueryLength, 3);
      expect(settings.debounceMs, 500);
      expect(settings.maxRecentSearches, 5);
      expect(settings.enableFuzzySearch, false);
    });

    test('round-trips through JSON', () {
      const settings = SearchSettings(minQueryLength: 4, debounceMs: 250);
      final restored = SearchSettings.fromJson(settings.toJson());

      expect(restored.minQueryLength, 4);
      expect(restored.debounceMs, 250);
    });
  });
}

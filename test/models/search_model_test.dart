import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('SearchEntityType', () {
    test('has correct values', () {
      expect(SearchEntityType.organization.value, 'organization');
      expect(SearchEntityType.site.value, 'site');
      expect(SearchEntityType.unit.value, 'unit');
      expect(SearchEntityType.user.value, 'user');
      expect(SearchEntityType.activity.value, 'activity');
      expect(SearchEntityType.all.value, 'all');
    });

    test('has correct labels', () {
      expect(SearchEntityType.organization.label, 'Organizasyon');
      expect(SearchEntityType.site.label, 'Saha');
      expect(SearchEntityType.unit.label, 'Alan');
      expect(SearchEntityType.user.label, 'Kullanıcı');
      expect(SearchEntityType.activity.label, 'Aktivite');
      expect(SearchEntityType.all.label, 'Tümü');
    });

    test('has correct icons', () {
      expect(SearchEntityType.organization.iconName, 'business');
      expect(SearchEntityType.site.iconName, 'location_on');
      expect(SearchEntityType.unit.iconName, 'meeting_room');
      expect(SearchEntityType.user.iconName, 'person');
      expect(SearchEntityType.activity.iconName, 'event');
    });

    test('fromValue returns correct type', () {
      expect(SearchEntityType.fromValue('organization'), SearchEntityType.organization);
      expect(SearchEntityType.fromValue('site'), SearchEntityType.site);
      expect(SearchEntityType.fromValue('unit'), SearchEntityType.unit);
      expect(SearchEntityType.fromValue('user'), SearchEntityType.user);
      expect(SearchEntityType.fromValue('activity'), SearchEntityType.activity);
      expect(SearchEntityType.fromValue('all'), SearchEntityType.all);
    });

    test('fromValue returns all for invalid value', () {
      expect(SearchEntityType.fromValue('invalid'), SearchEntityType.all);
      expect(SearchEntityType.fromValue(null), SearchEntityType.all);
    });
  });

  group('SearchQuery', () {
    test('creates correctly', () {
      final query = SearchQuery(
        text: 'test query',
        entityTypes: [SearchEntityType.organization, SearchEntityType.site],
        limit: 20,
        offset: 0,
      );

      expect(query.text, 'test query');
      expect(query.entityTypes.length, 2);
      expect(query.limit, 20);
      expect(query.offset, 0);
    });

    test('toJson serializes correctly', () {
      final query = SearchQuery(
        text: 'test',
        entityTypes: [SearchEntityType.organization],
        limit: 10,
        offset: 5,
      );

      final json = query.toJson();

      expect(json['text'], 'test');
      expect(json['entityTypes'], ['organization']);
      expect(json['limit'], 10);
      expect(json['offset'], 5);
    });

    test('copyWith creates correct copy', () {
      final query = SearchQuery(text: 'original', limit: 10);
      final copy = query.copyWith(text: 'updated', limit: 20);

      expect(copy.text, 'updated');
      expect(copy.limit, 20);
    });

    test('default factory creates empty query', () {
      final query = SearchQuery.defaultQuery();

      expect(query.text, '');
      expect(query.entityTypes, [SearchEntityType.all]);
      expect(query.limit, 20);
      expect(query.offset, 0);
    });

    test('isEmpty returns correct value', () {
      final emptyQuery = SearchQuery(text: '');
      expect(emptyQuery.isEmpty, true);

      final emptyQuery2 = SearchQuery(text: '   ');
      expect(emptyQuery2.isEmpty, true);

      final nonEmptyQuery = SearchQuery(text: 'test');
      expect(nonEmptyQuery.isEmpty, false);
    });

    test('hasFilters returns correct value', () {
      final noFilter = SearchQuery(
        text: 'test',
        entityTypes: [SearchEntityType.all],
      );
      expect(noFilter.hasFilters, false);

      final withFilter = SearchQuery(
        text: 'test',
        entityTypes: [SearchEntityType.organization],
      );
      expect(withFilter.hasFilters, true);
    });
  });

  group('SearchResult', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'result-123',
        'entityType': 'organization',
        'title': 'Test Organization',
        'subtitle': 'Subtitle text',
        'description': 'Description text',
        'imageUrl': 'https://example.com/image.png',
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
      final result = SearchResult(
        id: 'result-123',
        entityType: SearchEntityType.site,
        title: 'Test Site',
        subtitle: 'Subtitle',
        score: 0.8,
      );

      final json = result.toJson();

      expect(json['id'], 'result-123');
      expect(json['entityType'], 'site');
      expect(json['title'], 'Test Site');
      expect(json['subtitle'], 'Subtitle');
      expect(json['score'], 0.8);
    });

    test('hasImage returns correct value', () {
      final withImage = SearchResult(
        id: '1',
        entityType: SearchEntityType.unit,
        title: 'Test',
        imageUrl: 'https://example.com/image.png',
      );
      expect(withImage.hasImage, true);

      final withoutImage = SearchResult(
        id: '2',
        entityType: SearchEntityType.unit,
        title: 'Test',
      );
      expect(withoutImage.hasImage, false);
    });

    test('equality works correctly', () {
      final result1 = SearchResult(
        id: 'result-1',
        entityType: SearchEntityType.organization,
        title: 'Test',
      );
      final result2 = SearchResult(
        id: 'result-1',
        entityType: SearchEntityType.organization,
        title: 'Different',
      );
      final result3 = SearchResult(
        id: 'result-2',
        entityType: SearchEntityType.organization,
        title: 'Test',
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });

  group('SearchResponse', () {
    test('creates correctly', () {
      final results = [
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
        query: SearchQuery(text: 'test'),
        hasMore: true,
      );

      expect(response.results.length, 2);
      expect(response.totalCount, 100);
      expect(response.hasMore, true);
    });

    test('fromJson parses correctly', () {
      final json = {
        'results': [
          {
            'id': '1',
            'entityType': 'organization',
            'title': 'Test',
          },
        ],
        'totalCount': 50,
        'hasMore': true,
        'query': {
          'text': 'test',
          'entityTypes': ['all'],
          'limit': 20,
          'offset': 0,
        },
      };

      final response = SearchResponse.fromJson(json);

      expect(response.results.length, 1);
      expect(response.totalCount, 50);
      expect(response.hasMore, true);
      expect(response.query.text, 'test');
    });

    test('empty factory creates empty response', () {
      final empty = SearchResponse.empty();

      expect(empty.results, isEmpty);
      expect(empty.totalCount, 0);
      expect(empty.hasMore, false);
      expect(empty.isEmpty, true);
    });

    test('isEmpty returns correct value', () {
      final emptyResponse = SearchResponse(
        results: [],
        totalCount: 0,
        query: SearchQuery.defaultQuery(),
        hasMore: false,
      );
      expect(emptyResponse.isEmpty, true);

      final nonEmptyResponse = SearchResponse(
        results: [
          SearchResult(id: '1', entityType: SearchEntityType.unit, title: 'Test'),
        ],
        totalCount: 1,
        query: SearchQuery.defaultQuery(),
        hasMore: false,
      );
      expect(nonEmptyResponse.isEmpty, false);
    });

    test('resultsByType groups correctly', () {
      final results = [
        SearchResult(id: '1', entityType: SearchEntityType.organization, title: 'Org 1'),
        SearchResult(id: '2', entityType: SearchEntityType.organization, title: 'Org 2'),
        SearchResult(id: '3', entityType: SearchEntityType.site, title: 'Site 1'),
      ];

      final response = SearchResponse(
        results: results,
        totalCount: 3,
        query: SearchQuery.defaultQuery(),
        hasMore: false,
      );

      final byType = response.resultsByType;

      expect(byType[SearchEntityType.organization]?.length, 2);
      expect(byType[SearchEntityType.site]?.length, 1);
    });
  });

  group('SearchSuggestion', () {
    test('creates correctly', () {
      final suggestion = SearchSuggestion(
        text: 'suggested text',
        type: SearchSuggestionType.query,
        entityType: SearchEntityType.organization,
      );

      expect(suggestion.text, 'suggested text');
      expect(suggestion.type, SearchSuggestionType.query);
      expect(suggestion.entityType, SearchEntityType.organization);
    });

    test('fromJson parses correctly', () {
      final json = {
        'text': 'suggestion',
        'type': 'recent',
        'entityType': 'site',
      };

      final suggestion = SearchSuggestion.fromJson(json);

      expect(suggestion.text, 'suggestion');
      expect(suggestion.type, SearchSuggestionType.recent);
      expect(suggestion.entityType, SearchEntityType.site);
    });
  });

  group('RecentSearch', () {
    test('creates correctly', () {
      final search = RecentSearch(
        query: 'recent search',
        entityType: SearchEntityType.unit,
        timestamp: DateTime(2024, 1, 15),
      );

      expect(search.query, 'recent search');
      expect(search.entityType, SearchEntityType.unit);
      expect(search.timestamp.year, 2024);
    });

    test('toJson serializes correctly', () {
      final search = RecentSearch(
        query: 'test',
        entityType: SearchEntityType.user,
        timestamp: DateTime(2024, 1, 15, 10, 30),
      );

      final json = search.toJson();

      expect(json['query'], 'test');
      expect(json['entityType'], 'user');
      expect(json['timestamp'], isA<String>());
    });

    test('fromJson parses correctly', () {
      final json = {
        'query': 'test',
        'entityType': 'activity',
        'timestamp': '2024-01-15T10:30:00.000',
      };

      final search = RecentSearch.fromJson(json);

      expect(search.query, 'test');
      expect(search.entityType, SearchEntityType.activity);
      expect(search.timestamp.year, 2024);
    });
  });

  group('SearchFilter', () {
    test('creates correctly', () {
      final filter = SearchFilter(
        field: 'status',
        operator: SearchFilterOperator.equals,
        value: 'active',
      );

      expect(filter.field, 'status');
      expect(filter.operator, SearchFilterOperator.equals);
      expect(filter.value, 'active');
    });

    test('toJson serializes correctly', () {
      final filter = SearchFilter(
        field: 'createdAt',
        operator: SearchFilterOperator.greaterThan,
        value: '2024-01-01',
      );

      final json = filter.toJson();

      expect(json['field'], 'createdAt');
      expect(json['operator'], 'greaterThan');
      expect(json['value'], '2024-01-01');
    });
  });

  group('SearchSettings', () {
    test('creates with defaults', () {
      final settings = SearchSettings();

      expect(settings.minQueryLength, 2);
      expect(settings.debounceMilliseconds, 300);
      expect(settings.maxRecentSearches, 10);
      expect(settings.highlightMatches, true);
    });

    test('custom settings work', () {
      final settings = SearchSettings(
        minQueryLength: 3,
        debounceMilliseconds: 500,
        maxRecentSearches: 5,
        highlightMatches: false,
      );

      expect(settings.minQueryLength, 3);
      expect(settings.debounceMilliseconds, 500);
      expect(settings.maxRecentSearches, 5);
      expect(settings.highlightMatches, false);
    });

    test('debounceDuration returns correct Duration', () {
      final settings = SearchSettings(debounceMilliseconds: 500);

      expect(settings.debounceDuration, const Duration(milliseconds: 500));
    });
  });
}

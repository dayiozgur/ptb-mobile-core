import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'search_model.dart';

/// Search Servisi
///
/// Çoklu varlık türleri üzerinde arama yapma, öneri ve
/// son aramalar yönetimi sağlar.
///
/// Örnek kullanım:
/// ```dart
/// final searchService = SearchService(
///   supabase: Supabase.instance.client,
///   cacheManager: CacheManager(),
/// );
///
/// // Arama yap
/// final response = await searchService.search(
///   SearchQuery(text: 'test', tenantId: tenantId),
/// );
///
/// // Önerileri getir
/// final suggestions = await searchService.getSuggestions('te');
/// ```
class SearchService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  // Settings
  SearchSettings _settings = const SearchSettings();

  // Recent searches (in-memory + persistent)
  List<RecentSearch> _recentSearches = [];

  // Stream controllers
  final _searchResultsController = StreamController<SearchResponse>.broadcast();
  final _suggestionsController =
      StreamController<List<SearchSuggestion>>.broadcast();

  // Cache keys
  static const String _recentSearchesKey = 'recent_searches';
  static const String _searchCachePrefix = 'search_cache_';

  SearchService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
    SearchSettings? settings,
  })  : _supabase = supabase,
        _cacheManager = cacheManager {
    if (settings != null) {
      _settings = settings;
    }
    _loadRecentSearches();
  }

  // ============================================
  // GETTERS
  // ============================================

  /// Arama ayarları
  SearchSettings get settings => _settings;

  /// Son aramalar
  List<RecentSearch> get recentSearches => List.unmodifiable(_recentSearches);

  /// Arama sonuçları stream'i
  Stream<SearchResponse> get searchResultsStream =>
      _searchResultsController.stream;

  /// Öneriler stream'i
  Stream<List<SearchSuggestion>> get suggestionsStream =>
      _suggestionsController.stream;

  // ============================================
  // SETTINGS
  // ============================================

  /// Ayarları güncelle
  void updateSettings(SearchSettings settings) {
    _settings = settings;
    Logger.debug('Search settings updated');
  }

  // ============================================
  // SEARCH
  // ============================================

  /// Ana arama fonksiyonu
  Future<SearchResponse> search(SearchQuery query) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Minimum uzunluk kontrolü
      if (query.text.trim().length < _settings.minQueryLength) {
        return SearchResponse(
          query: query,
          results: [],
          totalCount: 0,
          duration: stopwatch.elapsed,
          searchedAt: DateTime.now(),
        );
      }

      // Cache kontrolü
      final cacheKey = _generateCacheKey(query);
      final cached = await _cacheManager.getTyped<SearchResponse>(
        key: cacheKey,
        fromJson: SearchResponse.fromJson,
      );
      if (cached != null) {
        _searchResultsController.add(cached);
        return cached;
      }

      // Aramayı yap
      final results = await _performSearch(query);

      final response = SearchResponse(
        query: query,
        results: results,
        totalCount: results.length,
        offset: query.offset,
        hasMore: results.length >= query.limit,
        duration: stopwatch.elapsed,
        searchedAt: DateTime.now(),
      );

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        response.toJson(),
        ttl: const Duration(minutes: 5),
      );

      // Son aramalara ekle
      if (_settings.saveRecentSearches && query.isValid) {
        await _saveRecentSearch(query, response.totalCount);
      }

      // Stream'e gönder
      _searchResultsController.add(response);

      Logger.debug(
          'Search completed: "${query.text}" -> ${results.length} results in ${stopwatch.elapsedMilliseconds}ms');
      return response;
    } catch (e) {
      Logger.error('Search failed for: "${query.text}"', e);
      stopwatch.stop();
      return SearchResponse(
        query: query,
        results: [],
        totalCount: 0,
        duration: stopwatch.elapsed,
        searchedAt: DateTime.now(),
      );
    }
  }

  /// Aramayı gerçekleştir
  Future<List<SearchResult>> _performSearch(SearchQuery query) async {
    final results = <SearchResult>[];
    final searchText = query.text.trim().toLowerCase();

    // Varlık türüne göre ara
    if (query.entityType == SearchEntityType.all) {
      // Tüm türlerde ara
      final futures = _settings.enabledEntityTypes.map((type) {
        return _searchEntityType(searchText, type, query);
      });

      final allResults = await Future.wait(futures);
      for (final typeResults in allResults) {
        results.addAll(typeResults);
      }

      // Skora göre sırala
      results.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    } else {
      // Belirli türde ara
      results.addAll(await _searchEntityType(
        searchText,
        query.entityType,
        query,
      ));
    }

    // Limit uygula
    if (results.length > query.limit) {
      return results.sublist(query.offset, query.offset + query.limit);
    }

    return results;
  }

  /// Belirli varlık türünde ara
  Future<List<SearchResult>> _searchEntityType(
    String searchText,
    SearchEntityType entityType,
    SearchQuery query,
  ) async {
    switch (entityType) {
      case SearchEntityType.organization:
        return _searchOrganizations(searchText, query);
      case SearchEntityType.site:
        return _searchSites(searchText, query);
      case SearchEntityType.unit:
        return _searchUnits(searchText, query);
      case SearchEntityType.user:
        return _searchUsers(searchText, query);
      case SearchEntityType.activity:
        return _searchActivities(searchText, query);
      case SearchEntityType.all:
        return [];
    }
  }

  /// Organizasyonlarda ara
  Future<List<SearchResult>> _searchOrganizations(
    String searchText,
    SearchQuery query,
  ) async {
    try {
      var dbQuery = _supabase
          .from('organizations')
          .select('id, name, code, description, color, active');

      // Tenant filtresi
      if (query.tenantId != null) {
        dbQuery = dbQuery.eq('tenant_id', query.tenantId!);
      }

      // Aktif filtresi
      dbQuery = dbQuery.eq('active', true);

      // Metin araması
      dbQuery = dbQuery.or(
        'name.ilike.%$searchText%,code.ilike.%$searchText%,description.ilike.%$searchText%',
      );

      final response = await dbQuery.limit(query.limit);

      return response.map<SearchResult>((item) {
        final name = item['name'] as String;
        final code = item['code'] as String?;

        return SearchResult(
          id: item['id'] as String,
          entityType: SearchEntityType.organization,
          title: name,
          subtitle: code,
          description: item['description'] as String?,
          color: item['color'] as String?,
          score: _calculateScore(searchText, name, code),
          metadata: {'active': item['active']},
        );
      }).toList();
    } catch (e) {
      Logger.error('Organization search failed', e);
      return [];
    }
  }

  /// Tesislerde ara
  Future<List<SearchResult>> _searchSites(
    String searchText,
    SearchQuery query,
  ) async {
    try {
      var dbQuery = _supabase
          .from('sites')
          .select('id, name, code, description, address, city, color, active');

      // Tenant filtresi
      if (query.tenantId != null) {
        dbQuery = dbQuery.eq('tenant_id', query.tenantId!);
      }

      // Organization filtresi
      if (query.organizationId != null) {
        dbQuery = dbQuery.eq('organization_id', query.organizationId!);
      }

      // Aktif filtresi
      dbQuery = dbQuery.eq('active', true);

      // Metin araması
      dbQuery = dbQuery.or(
        'name.ilike.%$searchText%,code.ilike.%$searchText%,address.ilike.%$searchText%,city.ilike.%$searchText%',
      );

      final response = await dbQuery.limit(query.limit);

      return response.map<SearchResult>((item) {
        final name = item['name'] as String;
        final code = item['code'] as String?;
        final city = item['city'] as String?;
        final address = item['address'] as String?;

        String? subtitle;
        if (city != null && address != null) {
          subtitle = '$address, $city';
        } else if (city != null) {
          subtitle = city;
        } else if (address != null) {
          subtitle = address;
        } else {
          subtitle = code;
        }

        return SearchResult(
          id: item['id'] as String,
          entityType: SearchEntityType.site,
          title: name,
          subtitle: subtitle,
          description: item['description'] as String?,
          color: item['color'] as String?,
          score: _calculateScore(searchText, name, code),
          metadata: {'active': item['active'], 'city': city},
        );
      }).toList();
    } catch (e) {
      Logger.error('Site search failed', e);
      return [];
    }
  }

  /// Ünitelerde ara
  Future<List<SearchResult>> _searchUnits(
    String searchText,
    SearchQuery query,
  ) async {
    try {
      var dbQuery = _supabase
          .from('units')
          .select('id, name, code, description, color, active');

      // Tenant filtresi
      if (query.tenantId != null) {
        dbQuery = dbQuery.eq('tenant_id', query.tenantId!);
      }

      // Site filtresi
      if (query.siteId != null) {
        dbQuery = dbQuery.eq('site_id', query.siteId!);
      }

      // Aktif filtresi
      dbQuery = dbQuery.eq('active', true);

      // Metin araması
      dbQuery = dbQuery.or(
        'name.ilike.%$searchText%,code.ilike.%$searchText%,description.ilike.%$searchText%',
      );

      final response = await dbQuery.limit(query.limit);

      return response.map<SearchResult>((item) {
        final name = item['name'] as String;
        final code = item['code'] as String?;

        return SearchResult(
          id: item['id'] as String,
          entityType: SearchEntityType.unit,
          title: name,
          subtitle: code,
          description: item['description'] as String?,
          color: item['color'] as String?,
          score: _calculateScore(searchText, name, code),
          metadata: {'active': item['active']},
        );
      }).toList();
    } catch (e) {
      Logger.error('Unit search failed', e);
      return [];
    }
  }

  /// Kullanıcılarda ara
  Future<List<SearchResult>> _searchUsers(
    String searchText,
    SearchQuery query,
  ) async {
    try {
      var dbQuery = _supabase.from('profiles').select(
          'id, first_name, last_name, email, title, avatar_url');

      // Metin araması
      dbQuery = dbQuery.or(
        'first_name.ilike.%$searchText%,last_name.ilike.%$searchText%,email.ilike.%$searchText%',
      );

      final response = await dbQuery.limit(query.limit);

      return response.map<SearchResult>((item) {
        final firstName = item['first_name'] as String? ?? '';
        final lastName = item['last_name'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        final email = item['email'] as String?;

        return SearchResult(
          id: item['id'] as String,
          entityType: SearchEntityType.user,
          title: fullName.isNotEmpty ? fullName : email ?? 'Unknown',
          subtitle: item['title'] as String? ?? email,
          imageUrl: item['avatar_url'] as String?,
          score: _calculateScore(searchText, fullName, email),
          metadata: {'email': email},
        );
      }).toList();
    } catch (e) {
      Logger.error('User search failed', e);
      return [];
    }
  }

  /// Aktivitelerde ara
  Future<List<SearchResult>> _searchActivities(
    String searchText,
    SearchQuery query,
  ) async {
    try {
      var dbQuery = _supabase
          .from('activity_logs')
          .select('id, action_type, entity_type, entity_id, description, created_at');

      // Tenant filtresi
      if (query.tenantId != null) {
        dbQuery = dbQuery.eq('tenant_id', query.tenantId!);
      }

      // Metin araması
      dbQuery = dbQuery.or(
        'description.ilike.%$searchText%,action_type.ilike.%$searchText%',
      );

      final response = await dbQuery.order('created_at', ascending: false).limit(query.limit);

      return response.map<SearchResult>((item) {
        final actionType = item['action_type'] as String? ?? '';
        final entityType = item['entity_type'] as String? ?? '';
        final description = item['description'] as String?;

        return SearchResult(
          id: item['id'] as String,
          entityType: SearchEntityType.activity,
          title: description ?? '$actionType on $entityType',
          subtitle: '$actionType - $entityType',
          score: _calculateScore(searchText, description ?? '', actionType),
          metadata: {
            'action_type': actionType,
            'entity_type': entityType,
            'entity_id': item['entity_id'],
            'created_at': item['created_at'],
          },
        );
      }).toList();
    } catch (e) {
      Logger.error('Activity search failed', e);
      return [];
    }
  }

  /// Skor hesapla
  double _calculateScore(String query, String? primary, String? secondary) {
    double score = 0;

    if (primary != null) {
      final primaryLower = primary.toLowerCase();
      if (primaryLower == query) {
        score += 100; // Tam eşleşme
      } else if (primaryLower.startsWith(query)) {
        score += 80; // Başlangıç eşleşmesi
      } else if (primaryLower.contains(query)) {
        score += 50; // İçerik eşleşmesi
      }
    }

    if (secondary != null) {
      final secondaryLower = secondary.toLowerCase();
      if (secondaryLower == query) {
        score += 30;
      } else if (secondaryLower.startsWith(query)) {
        score += 20;
      } else if (secondaryLower.contains(query)) {
        score += 10;
      }
    }

    return score;
  }

  // ============================================
  // SUGGESTIONS
  // ============================================

  /// Öneri getir
  Future<List<SearchSuggestion>> getSuggestions(
    String prefix, {
    String? tenantId,
    int limit = 10,
  }) async {
    final suggestions = <SearchSuggestion>[];

    try {
      // Minimum uzunluk kontrolü
      if (prefix.trim().length < 2) {
        // Son aramalardan öner
        final recentSuggestions = _recentSearches
            .take(5)
            .map((r) => SearchSuggestion(
                  text: r.query,
                  entityType: r.entityType,
                  type: SuggestionType.recent,
                  count: r.resultCount,
                ))
            .toList();

        _suggestionsController.add(recentSuggestions);
        return recentSuggestions;
      }

      // Son aramalardan eşleşenler
      final matchingRecent = _recentSearches
          .where((r) => r.query.toLowerCase().startsWith(prefix.toLowerCase()))
          .take(3)
          .map((r) => SearchSuggestion(
                text: r.query,
                entityType: r.entityType,
                type: SuggestionType.recent,
                count: r.resultCount,
              ));
      suggestions.addAll(matchingRecent);

      // Autocomplete önerileri (veritabanından)
      final autocompleteSuggestions = await _getAutocompleteSuggestions(
        prefix,
        tenantId: tenantId,
        limit: limit - suggestions.length,
      );
      suggestions.addAll(autocompleteSuggestions);

      _suggestionsController.add(suggestions);
      return suggestions;
    } catch (e) {
      Logger.error('Failed to get suggestions', e);
      _suggestionsController.add([]);
      return [];
    }
  }

  /// Veritabanından autocomplete önerileri
  Future<List<SearchSuggestion>> _getAutocompleteSuggestions(
    String prefix, {
    String? tenantId,
    int limit = 7,
  }) async {
    final suggestions = <SearchSuggestion>[];

    try {
      // Organizasyonlardan
      var orgQuery = _supabase
          .from('organizations')
          .select('name')
          .eq('active', true)
          .ilike('name', '$prefix%');

      if (tenantId != null) {
        orgQuery = orgQuery.eq('tenant_id', tenantId);
      }

      final orgResponse = await orgQuery.limit(3);
      for (final item in orgResponse) {
        suggestions.add(SearchSuggestion(
          text: item['name'] as String,
          entityType: SearchEntityType.organization,
          type: SuggestionType.autocomplete,
        ));
      }

      // Sitelerden
      var siteQuery = _supabase
          .from('sites')
          .select('name')
          .eq('active', true)
          .ilike('name', '$prefix%');

      if (tenantId != null) {
        siteQuery = siteQuery.eq('tenant_id', tenantId);
      }

      final siteResponse = await siteQuery.limit(3);
      for (final item in siteResponse) {
        suggestions.add(SearchSuggestion(
          text: item['name'] as String,
          entityType: SearchEntityType.site,
          type: SuggestionType.autocomplete,
        ));
      }

      // Ünitelerden
      var unitQuery = _supabase
          .from('units')
          .select('name')
          .eq('active', true)
          .ilike('name', '$prefix%');

      if (tenantId != null) {
        unitQuery = unitQuery.eq('tenant_id', tenantId);
      }

      final unitResponse = await unitQuery.limit(3);
      for (final item in unitResponse) {
        suggestions.add(SearchSuggestion(
          text: item['name'] as String,
          entityType: SearchEntityType.unit,
          type: SuggestionType.autocomplete,
        ));
      }

      return suggestions.take(limit).toList();
    } catch (e) {
      Logger.error('Failed to get autocomplete suggestions', e);
      return [];
    }
  }

  // ============================================
  // RECENT SEARCHES
  // ============================================

  /// Son aramaları yükle
  Future<void> _loadRecentSearches() async {
    try {
      final cached = await _cacheManager.getList<RecentSearch>(
        key: _recentSearchesKey,
        fromJson: RecentSearch.fromJson,
      );
      if (cached != null) {
        _recentSearches = cached;
      }
    } catch (e) {
      Logger.error('Failed to load recent searches', e);
    }
  }

  /// Son aramayı kaydet
  Future<void> _saveRecentSearch(SearchQuery query, int resultCount) async {
    try {
      // Aynı sorgu varsa kaldır
      _recentSearches.removeWhere(
        (r) =>
            r.query.toLowerCase() == query.text.toLowerCase() &&
            r.entityType == query.entityType,
      );

      // Yeni arama ekle
      final recent = RecentSearch(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        query: query.text,
        entityType: query.entityType,
        searchedAt: DateTime.now(),
        resultCount: resultCount,
      );

      _recentSearches.insert(0, recent);

      // Limit uygula
      if (_recentSearches.length > _settings.maxRecentSearches) {
        _recentSearches = _recentSearches.take(_settings.maxRecentSearches).toList();
      }

      // Kalıcı depolama
      await _cacheManager.setList(
        key: _recentSearchesKey,
        value: _recentSearches,
        toJson: (r) => r.toJson(),
        ttl: const Duration(days: 30),
      );
    } catch (e) {
      Logger.error('Failed to save recent search', e);
    }
  }

  /// Son aramayı sil
  Future<void> removeRecentSearch(String id) async {
    _recentSearches.removeWhere((r) => r.id == id);
    await _cacheManager.setList(
      key: _recentSearchesKey,
      value: _recentSearches,
      toJson: (r) => r.toJson(),
      ttl: const Duration(days: 30),
    );
  }

  /// Tüm son aramaları temizle
  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    await _cacheManager.delete(_recentSearchesKey);
    Logger.debug('Recent searches cleared');
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Cache anahtarı oluştur
  String _generateCacheKey(SearchQuery query) {
    final key = jsonEncode({
      'text': query.text.toLowerCase(),
      'type': query.entityType.value,
      'tenant': query.tenantId,
      'org': query.organizationId,
      'site': query.siteId,
      'limit': query.limit,
      'offset': query.offset,
    });
    return '$_searchCachePrefix${key.hashCode}';
  }

  /// Arama cache'ini temizle
  Future<void> clearSearchCache() async {
    await _cacheManager.deleteByPrefix(_searchCachePrefix);
    Logger.debug('Search cache cleared');
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi kapat
  void dispose() {
    _searchResultsController.close();
    _suggestionsController.close();
    Logger.debug('SearchService disposed');
  }
}

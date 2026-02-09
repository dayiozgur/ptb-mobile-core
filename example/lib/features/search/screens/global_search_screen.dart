import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Global Arama Ekranı
///
/// Tüm varlık türleri üzerinde arama yapma imkanı sağlar.
/// Son aramalar, öneriler ve filtreleme özellikleri içerir.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _debouncer = Debouncer(milliseconds: 300);

  late SearchService _searchService;
  SearchEntityType _selectedType = SearchEntityType.all;
  List<SearchSuggestion> _suggestions = [];
  SearchResponse? _searchResponse;
  bool _isLoading = false;
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _initSearchService();
    _focusNode.requestFocus();
  }

  void _initSearchService() {
    _searchService = searchService;
    // Stream'leri dinle
    _searchService.searchResultsStream.listen((response) {
      if (mounted) {
        setState(() {
          _searchResponse = response;
          _isLoading = false;
          _showSuggestions = false;
        });
      }
    });

    _searchService.suggestionsStream.listen((suggestions) {
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    });

    // İlk önerileri yükle
    _loadSuggestions('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _showSuggestions = true);

    if (value.isEmpty) {
      setState(() {
        _searchResponse = null;
        _isLoading = false;
      });
      _loadSuggestions('');
      return;
    }

    _debouncer.run(() {
      if (value.length >= 2) {
        _loadSuggestions(value);
      }
    });
  }

  Future<void> _loadSuggestions(String prefix) async {
    final tenantId = tenantService.currentTenantId;
    await _searchService.getSuggestions(prefix, tenantId: tenantId);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _showSuggestions = false;
    });

    final searchQuery = SearchQuery(
      text: query,
      entityType: _selectedType,
      tenantId: tenantService.currentTenantId,
      organizationId: organizationService.currentOrganizationId,
      limit: 50,
    );

    await _searchService.search(searchQuery);
  }

  void _onSuggestionTap(SearchSuggestion suggestion) {
    _searchController.text = suggestion.text;
    _performSearch(suggestion.text);
  }

  void _onRecentSearchTap(RecentSearch recent) {
    _searchController.text = recent.query;
    if (recent.entityType != null) {
      setState(() => _selectedType = recent.entityType!);
    }
    _performSearch(recent.query);
  }

  void _onResultTap(SearchResult result) {
    // Navigate to result detail
    switch (result.entityType) {
      case SearchEntityType.organization:
        context.push('/organizations/${result.id}');
        break;
      case SearchEntityType.site:
        context.push('/sites/${result.id}');
        break;
      case SearchEntityType.unit:
        context.push('/units/${result.id}');
        break;
      case SearchEntityType.user:
        context.push('/members/${result.id}');
        break;
      case SearchEntityType.activity:
        // Show activity detail in bottom sheet
        _showActivityDetail(result);
        break;
      case SearchEntityType.all:
        break;
    }
  }

  void _showActivityDetail(SearchResult result) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (result.subtitle != null)
              Text(
                result.subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            const SizedBox(height: 16),
            if (result.metadata != null) ...[
              _buildMetadataRow('Tarih', result.metadata!['created_at']?.toString() ?? '-'),
              _buildMetadataRow('Tip', result.metadata!['action_type']?.toString() ?? '-'),
              _buildMetadataRow('Varlık', result.metadata!['entity_type']?.toString() ?? '-'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResponse = null;
      _showSuggestions = true;
    });
    _loadSuggestions('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentSearches = _searchService.recentSearches;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arama'),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Input
                AppTextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  placeholder: 'Organizasyon, tesis, ünite veya kullanıcı ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onChanged: _onSearchChanged,
                  onSubmitted: _performSearch,
                ),
                const SizedBox(height: 12),

                // Entity Type Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: SearchEntityType.values.map((type) {
                      final isSelected = _selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(type.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedType = type);
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          },
                          avatar: Icon(
                            _getIconForType(type),
                            size: 18,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _showSuggestions
                ? _buildSuggestionsAndRecent(recentSearches)
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsAndRecent(List<RecentSearch> recentSearches) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Recent Searches
        if (recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son Aramalar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextButton(
                onPressed: () async {
                  await _searchService.clearRecentSearches();
                  setState(() {});
                },
                child: const Text('Temizle'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...recentSearches.take(5).map((recent) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(recent.query),
                subtitle: Text(
                  '${recent.entityType?.label ?? 'Tümü'} - ${recent.resultCount} sonuç',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    await _searchService.removeRecentSearch(recent.id);
                    setState(() {});
                  },
                ),
                onTap: () => _onRecentSearchTap(recent),
              )),
          const SizedBox(height: 24),
        ],

        // Suggestions
        if (_suggestions.isNotEmpty) ...[
          Text(
            'Öneriler',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ..._suggestions.map((suggestion) => ListTile(
                leading: Icon(
                  suggestion.type == SuggestionType.recent
                      ? Icons.history
                      : Icons.search,
                ),
                title: Text(suggestion.text),
                subtitle: suggestion.entityType != null
                    ? Text(suggestion.entityType!.label)
                    : null,
                trailing: suggestion.count != null
                    ? Text(
                        '${suggestion.count} sonuç',
                        style: TextStyle(color: Colors.grey[600]),
                      )
                    : null,
                onTap: () => _onSuggestionTap(suggestion),
              )),
        ],

        // Empty State
        if (recentSearches.isEmpty && _suggestions.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Icon(
                  Icons.search,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aramaya başlayın',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Organizasyonlar, tesisler, üniteler\nve kullanıcılar arasında arayın',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final response = _searchResponse;
    if (response == null || response.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Sonuç bulunamadı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${_searchController.text}" için sonuç yok',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _clearSearch,
              child: const Text('Yeni Arama'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${response.totalCount} sonuç bulundu',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              Text(
                '${response.duration.inMilliseconds}ms',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),
            ],
          ),
        ),

        // Results List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: response.results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = response.results[index];
              return _buildResultItem(result);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: result.color != null
            ? Color(int.parse(result.color!.replaceFirst('#', '0xFF')))
            : Theme.of(context).primaryColor.withOpacity(0.1),
        child: result.imageUrl != null
            ? ClipOval(
                child: Image.network(
                  result.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    _getIconForType(result.entityType),
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              )
            : Icon(
                _getIconForType(result.entityType),
                color: result.color != null
                    ? Colors.white
                    : Theme.of(context).primaryColor,
              ),
      ),
      title: Text(
        result.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.subtitle != null)
            Text(
              result.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            ),
          Text(
            result.entityType.label,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: result.score != null && result.score! > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${result.score!.toInt()}%',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => _onResultTap(result),
    );
  }

  IconData _getIconForType(SearchEntityType type) {
    switch (type) {
      case SearchEntityType.all:
        return Icons.search;
      case SearchEntityType.organization:
        return Icons.business;
      case SearchEntityType.site:
        return Icons.location_city;
      case SearchEntityType.unit:
        return Icons.widgets;
      case SearchEntityType.user:
        return Icons.person;
      case SearchEntityType.activity:
        return Icons.timeline;
    }
  }
}

/// Debouncer for search input
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

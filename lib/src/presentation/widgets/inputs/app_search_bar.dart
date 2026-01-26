import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/search/search_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Protoolbag Arama Çubuğu
///
/// Tam özellikli arama çubuğu widget'ı.
/// Öneriler, son aramalar ve filtreleme desteği.
///
/// Örnek kullanım:
/// ```dart
/// AppSearchBar(
///   onSearch: (query) => searchService.search(query),
///   onSuggestionTap: (suggestion) => _handleSuggestion(suggestion),
///   placeholder: 'Ara...',
/// )
/// ```
class AppSearchBar extends StatefulWidget {
  /// Arama callback'i
  final void Function(String text)? onSearch;

  /// Metin değişikliği callback'i
  final void Function(String text)? onChanged;

  /// Öneri seçildiğinde
  final void Function(SearchSuggestion suggestion)? onSuggestionTap;

  /// Son arama seçildiğinde
  final void Function(RecentSearch recent)? onRecentTap;

  /// Temizle callback'i
  final VoidCallback? onClear;

  /// İptal callback'i
  final VoidCallback? onCancel;

  /// Placeholder metin
  final String placeholder;

  /// Otomatik odaklan
  final bool autofocus;

  /// Salt okunur
  final bool readOnly;

  /// Etkin mi
  final bool enabled;

  /// Debounce süresi
  final Duration debounceDuration;

  /// Minimum arama uzunluğu
  final int minSearchLength;

  /// Öneriler
  final List<SearchSuggestion>? suggestions;

  /// Son aramalar
  final List<RecentSearch>? recentSearches;

  /// Yüklenme durumu
  final bool isLoading;

  /// Varlık türü filtresi
  final SearchEntityType? entityType;

  /// Varlık türü değiştiğinde
  final void Function(SearchEntityType? type)? onEntityTypeChanged;

  /// Filtre göster
  final bool showFilter;

  /// İptal butonu göster
  final bool showCancelButton;

  /// Controller
  final TextEditingController? controller;

  /// Focus node
  final FocusNode? focusNode;

  const AppSearchBar({
    super.key,
    this.onSearch,
    this.onChanged,
    this.onSuggestionTap,
    this.onRecentTap,
    this.onClear,
    this.onCancel,
    this.placeholder = 'Ara...',
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.minSearchLength = 2,
    this.suggestions,
    this.recentSearches,
    this.isLoading = false,
    this.entityType,
    this.onEntityTypeChanged,
    this.showFilter = false,
    this.showCancelButton = false,
    this.controller,
    this.focusNode,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();

    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);

    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus;
    });
  }

  void _onTextChange() {
    final text = _controller.text;

    widget.onChanged?.call(text);

    // Debounce ile arama
    _debounceTimer?.cancel();
    if (text.length >= widget.minSearchLength) {
      _debounceTimer = Timer(widget.debounceDuration, () {
        widget.onSearch?.call(text);
      });
    }

    setState(() {
      _showSuggestions = _focusNode.hasFocus && text.isNotEmpty;
    });
  }

  void _handleClear() {
    _controller.clear();
    widget.onClear?.call();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _handleCancel() {
    _controller.clear();
    _focusNode.unfocus();
    widget.onCancel?.call();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _handleSuggestionTap(SearchSuggestion suggestion) {
    _controller.text = suggestion.text;
    _focusNode.unfocus();
    widget.onSuggestionTap?.call(suggestion);
    widget.onSearch?.call(suggestion.text);
    setState(() {
      _showSuggestions = false;
    });
  }

  void _handleRecentTap(RecentSearch recent) {
    _controller.text = recent.query;
    _focusNode.unfocus();
    widget.onRecentTap?.call(recent);
    widget.onSearch?.call(recent.query);
    setState(() {
      _showSuggestions = false;
    });
  }

  void _handleSubmit(String text) {
    _debounceTimer?.cancel();
    _focusNode.unfocus();
    widget.onSearch?.call(text);
    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Arama çubuğu
        _buildSearchBar(brightness),

        // Öneriler / Son aramalar
        if (_showSuggestions) _buildSuggestions(brightness),
      ],
    );
  }

  Widget _buildSearchBar(Brightness brightness) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: brightness == Brightness.light ? AppColors.systemGray6 : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          // Arama ikonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: widget.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.textSecondary(brightness),
                      ),
                    ),
                  )
                : Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.textSecondary(brightness),
                  ),
          ),

          // Metin alanı
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              readOnly: widget.readOnly,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              onSubmitted: _handleSubmit,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary(brightness),
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Filtre butonu
          if (widget.showFilter) ...[
            _buildFilterButton(brightness),
          ],

          // Temizle butonu
          if (_controller.text.isNotEmpty) ...[
            GestureDetector(
              onTap: _handleClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: brightness == Brightness.light ? AppColors.systemGray4 : AppColors.borderDark,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.surface(brightness),
                  ),
                ),
              ),
            ),
          ],

          // İptal butonu
          if (widget.showCancelButton) ...[
            TextButton(
              onPressed: _handleCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                'İptal',
                style: AppTypography.body.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterButton(Brightness brightness) {
    return PopupMenuButton<SearchEntityType?>(
      icon: Icon(
        Icons.filter_list,
        size: 20,
        color: widget.entityType != null
            ? AppColors.primary
            : AppColors.textSecondary(brightness),
      ),
      initialValue: widget.entityType,
      onSelected: widget.onEntityTypeChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text('Tümü'),
        ),
        ...SearchEntityType.values
            .where((e) => e != SearchEntityType.all)
            .map(
              (type) => PopupMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(
                      _getEntityIcon(type),
                      size: 18,
                      color: AppColors.textSecondary(brightness),
                    ),
                    const SizedBox(width: 8),
                    Text(type.label),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildSuggestions(Brightness brightness) {
    final suggestions = widget.suggestions ?? [];
    final recentSearches = widget.recentSearches ?? [];

    if (suggestions.isEmpty && recentSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Son aramalar
          if (recentSearches.isNotEmpty &&
              _controller.text.length < widget.minSearchLength) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Son Aramalar',
                style: AppTypography.caption1.copyWith(
                  color: AppColors.textSecondary(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...recentSearches.map(
              (recent) => _buildRecentItem(recent, brightness),
            ),
            if (suggestions.isNotEmpty) const Divider(height: 16),
          ],

          // Öneriler
          if (suggestions.isNotEmpty) ...[
            if (_controller.text.length >= widget.minSearchLength)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Öneriler',
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.textSecondary(brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ...suggestions.map(
              (suggestion) => _buildSuggestionItem(suggestion, brightness),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentItem(RecentSearch recent, Brightness brightness) {
    return InkWell(
      onTap: () => _handleRecentTap(recent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 18,
              color: AppColors.textSecondary(brightness),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                recent.query,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary(brightness),
                ),
              ),
            ),
            if (recent.resultCount > 0)
              Text(
                '${recent.resultCount} sonuç',
                style: AppTypography.caption2.copyWith(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(
      SearchSuggestion suggestion, Brightness brightness) {
    return InkWell(
      onTap: () => _handleSuggestionTap(suggestion),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              suggestion.entityType != null
                  ? _getEntityIcon(suggestion.entityType!)
                  : Icons.search,
              size: 18,
              color: suggestion.type == SuggestionType.autocomplete
                  ? AppColors.primary
                  : AppColors.textSecondary(brightness),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: _highlightQuery(
                    suggestion.text,
                    _controller.text,
                    brightness,
                  ),
                ),
              ),
            ),
            if (suggestion.entityType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: brightness == Brightness.light ? AppColors.systemGray6 : AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  suggestion.entityType!.label,
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _highlightQuery(
      String text, String query, Brightness brightness) {
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // Önceki kısım
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary(brightness),
          ),
        ));
      }

      // Eşleşen kısım (vurgulu)
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: AppTypography.body.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Kalan kısım
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: AppTypography.body.copyWith(
          color: AppColors.textPrimary(brightness),
        ),
      ));
    }

    return spans;
  }

  IconData _getEntityIcon(SearchEntityType type) {
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

/// Minimal arama butonu
///
/// Tıklandığında arama ekranına yönlendirir.
class SearchButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String placeholder;

  const SearchButton({
    super.key,
    this.onTap,
    this.placeholder = 'Ara...',
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: brightness == Brightness.light ? AppColors.systemGray6 : AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 18,
              color: AppColors.textSecondary(brightness),
            ),
            const SizedBox(width: 8),
            Text(
              placeholder,
              style: AppTypography.subhead.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

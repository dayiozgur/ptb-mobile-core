import 'dart:async';

import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../field_render_context.dart';
import 'field_scaffold.dart';

/// `lookup` → dinamik referans arama alanı.
///
/// [LookupService] ile min 2 karakter, ~300ms debounce'lu arama yapar; seçilen
/// sonucu `{entityId, displayValue}` Map olarak depolar ve displayValue'yu
/// gösterir. Yerel arama/yükleme state'i içeride tutulur; seçilen değer daima
/// [FieldRenderContext.onChanged] üzerinden akar.
class LookupFieldWidget extends FieldWidget {
  const LookupFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return _LookupFieldView(ctx: ctx);
  }
}

class _LookupFieldView extends StatefulWidget {
  final FieldRenderContext ctx;

  const _LookupFieldView({required this.ctx});

  @override
  State<_LookupFieldView> createState() => _LookupFieldViewState();
}

class _LookupFieldViewState extends State<_LookupFieldView> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  bool _open = false;

  static const _debounceMs = 300;
  static const _minChars = 2;

  @override
  void initState() {
    super.initState();
    _controller.text = _displayValueOf(widget.ctx.value);
  }

  @override
  void didUpdateWidget(covariant _LookupFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seçim dışarıdan temizlendiyse (ör. cascade reset) kutuyu senkronla.
    final incoming = _displayValueOf(widget.ctx.value);
    if (!_open && incoming != _controller.text) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _displayValueOf(dynamic value) {
    if (value is Map && value['displayValue'] != null) {
      return value['displayValue'].toString();
    }
    return '';
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final query = raw.trim();
    if (query.length < _minChars) {
      setState(() {
        _results = const [];
        _open = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _open = true;
    });
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    try {
      final results = await sl<LookupService>().search(
        widget.ctx.field.options,
        query: query,
        dependsOnValues: widget.ctx.formValues,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  void _select(Map<String, dynamic> result) {
    final stored = <String, dynamic>{
      'entityId': result['entityId'],
      'displayValue': result['displayValue']?.toString() ?? '',
    };
    _controller.text = stored['displayValue'] as String;
    setState(() {
      _open = false;
      _results = const [];
    });
    widget.ctx.onChanged(stored);
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _open = false;
      _results = const [];
    });
    widget.ctx.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final field = widget.ctx.field;
    final hasSelection = _displayValueOf(widget.ctx.value).isNotEmpty;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _controller,
            placeholder: field.placeholder,
            enabled: widget.ctx.enabled,
            keyboardType: TextInputType.text,
            prefixIcon: Icons.search,
            suffixIcon: (hasSelection || _controller.text.isNotEmpty)
                ? Icons.clear
                : null,
            onSuffixIconPressed: widget.ctx.enabled ? _clear : null,
            onChanged: widget.ctx.enabled ? _onQueryChanged : null,
          ),
          if (_open) _buildResults(brightness),
        ],
      ),
    );
  }

  Widget _buildResults(Brightness brightness) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Aranıyor…',
              style: AppTypography.caption1.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          'Sonuç bulunamadı',
          style: AppTypography.caption1.copyWith(
            color: AppColors.textSecondary(brightness),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.divider(brightness)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _results.length; i++)
            AppListTile(
              title: _results[i]['displayValue']?.toString() ?? '',
              showDivider: i < _results.length - 1,
              onTap: () => _select(_results[i]),
            ),
        ],
      ),
    );
  }
}

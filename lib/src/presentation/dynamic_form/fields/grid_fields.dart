import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../field_render_context.dart';
import 'field_scaffold.dart';

/// `matrix_input` ve `table_grid` → çok-satırlı, çok-kolonlu bileşik alanlar.
///
/// Web `ptb-field-matrix-input` / `ptb-field-table-grid` karşılığı. Value
/// sözleşmesi web ile BİREBİR: `List<Map<String,dynamic>>` (satır-objesi
/// listesi, her satır `{kolonKey: hücreDeğeri}`). Config `field.metadata`'dan
/// gelir (web ile aynı isimler): `columns` (`{key,label,type,options}`),
/// matrix için `rows` (`{mode:'fixed'|'dynamic', fixedRows, minRows, maxRows}`),
/// table için `minRows`/`maxRows`.
///
/// Mobil uyarlama: web `<table>` küçük ekrana sığmaz → her satır bir kart,
/// içinde dikey `etiket: giriş` listesi + (dinamikse) sil ikonu; en altta
/// "Satır Ekle". Hücre tipleri: text, number/currency, select, checkbox, date.
/// `computed` v1'de salt-okunur (ifade değerlendirme mobilde yok).
class MatrixInputFieldWidget extends FieldWidget {
  const MatrixInputFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _GridFieldView(ctx: ctx, isMatrix: true);
}

class TableGridFieldWidget extends FieldWidget {
  const TableGridFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _GridFieldView(ctx: ctx, isMatrix: false);
}

/// Bir kolon tanımı (`metadata.columns[i]`).
class _GridColumn {
  final String key;
  final String label;
  final String type; // text | number | currency | select | checkbox | date | computed
  final List<String> options;

  const _GridColumn({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
  });

  factory _GridColumn.fromMap(Map<dynamic, dynamic> m) => _GridColumn(
        key: m['key']?.toString() ?? '',
        label: m['label']?.toString() ?? m['key']?.toString() ?? '',
        type: (m['type']?.toString() ?? 'text').toLowerCase(),
        options: ((m['options'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Kalıcı kimlikli satır — ekle/sil sırasında Flutter'ın hücre state'ini doğru
/// koruması için `id` sabit kalır (ValueKey).
class _GridRow {
  final int id;
  final Map<String, dynamic> data;
  _GridRow(this.id, this.data);
}

class _GridFieldView extends StatefulWidget {
  final FieldRenderContext ctx;
  final bool isMatrix;
  const _GridFieldView({required this.ctx, required this.isMatrix});

  @override
  State<_GridFieldView> createState() => _GridFieldViewState();
}

class _GridFieldViewState extends State<_GridFieldView> {
  late List<_GridColumn> _columns;
  late bool _fixed;
  late List<String> _fixedRows;
  late int _minRows;
  late int _maxRows;

  final List<_GridRow> _rows = [];
  int _nextId = 0;

  /// text/number hücreleri için kalıcı controller'lar (key: `rowId::colKey`).
  /// AppTextField `initialValue` desteklemediğinden controller şart; satır
  /// silinince ilgili controller'lar dispose edilir.
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _parseConfig();
    _initRows();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int rowId, String colKey, String initial) {
    return _controllers.putIfAbsent(
        '$rowId::$colKey', () => TextEditingController(text: initial));
  }

  void _parseConfig() {
    final meta = widget.ctx.field.metadata ?? const {};
    _columns = ((meta['columns'] as List?) ?? const [])
        .whereType<Map>()
        .map(_GridColumn.fromMap)
        .where((c) => c.key.isNotEmpty)
        .toList();

    final rowsCfg = (meta['rows'] as Map?) ?? const {};
    // matrix: rows.mode; table_grid daima dinamik.
    _fixed = widget.isMatrix && (rowsCfg['mode']?.toString() == 'fixed');
    _fixedRows = ((rowsCfg['fixedRows'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    _minRows =
        (rowsCfg['minRows'] as num?)?.toInt() ?? (meta['minRows'] as num?)?.toInt() ?? 1;
    _maxRows = (rowsCfg['maxRows'] as num?)?.toInt() ??
        (meta['maxRows'] as num?)?.toInt() ??
        (widget.isMatrix ? 50 : 100);
  }

  void _initRows() {
    final incoming = widget.ctx.value;
    final existing = incoming is List
        ? incoming
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : <Map<String, dynamic>>[];

    if (_fixed && _fixedRows.isNotEmpty) {
      // Sabit satırlar: her satır fixedRows[i] başlıklı; varsa mevcut değeri eşle.
      for (var i = 0; i < _fixedRows.length; i++) {
        final base = i < existing.length ? existing[i] : _emptyRow();
        base['_label'] = _fixedRows[i];
        _rows.add(_GridRow(_nextId++, base));
      }
      return;
    }

    for (final m in existing) {
      _rows.add(_GridRow(_nextId++, m));
    }
    while (_rows.length < _minRows) {
      _rows.add(_GridRow(_nextId++, _emptyRow()));
    }
  }

  Map<String, dynamic> _emptyRow() {
    final row = <String, dynamic>{};
    for (final c in _columns) {
      row[c.key] = c.type == 'checkbox' ? false : null;
    }
    return row;
  }

  void _emit() {
    final out = _rows
        .map((r) => Map<String, dynamic>.from(r.data)..remove('_label'))
        .toList();
    widget.ctx.onChanged(out);
  }

  void _addRow() {
    if (_rows.length >= _maxRows) return;
    setState(() => _rows.add(_GridRow(_nextId++, _emptyRow())));
    _emit();
  }

  void _removeRow(int id) {
    if (_rows.length <= _minRows) return;
    // Silinen satırın controller'larını temizle.
    _controllers.removeWhere((k, c) {
      if (k.startsWith('$id::')) {
        c.dispose();
        return true;
      }
      return false;
    });
    setState(() => _rows.removeWhere((r) => r.id == id));
    _emit();
  }

  void _updateCell(int rowId, String colKey, dynamic value) {
    final row = _rows.firstWhere((r) => r.id == rowId);
    row.data[colKey] = value;
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    final brightness = Theme.of(context).brightness;

    if (_columns.isEmpty) {
      return FieldScaffold(
        labelText: field.label,
        required: field.isRequired,
        helpText: field.helpText,
        errorText: widget.ctx.errorText,
        child: Text(
          'Kolon tanımı yok',
          style: AppTypography.caption1.copyWith(
            color: AppColors.textSecondary(brightness),
          ),
        ),
      );
    }

    final canAdd =
        !_fixed && widget.ctx.enabled && _rows.length < _maxRows;
    final canRemove = !_fixed && widget.ctx.enabled;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _rows.length; i++)
            _buildRowCard(brightness, _rows[i], i, canRemove),
          if (canAdd)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Satır Ekle'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRowCard(
    Brightness brightness,
    _GridRow row,
    int index,
    bool canRemove,
  ) {
    final title = _fixed
        ? (row.data['_label']?.toString() ?? '#${index + 1}')
        : '#${index + 1}';

    return Container(
      key: ValueKey('grid-row-${row.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.divider(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTypography.footnote.copyWith(
                  color: AppColors.textSecondary(brightness),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (canRemove)
                InkWell(
                  onTap: () => _removeRow(row.id),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxs),
                    child: Icon(Icons.delete_outline,
                        size: 20, color: AppColors.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final col in _columns) ...[
            _buildCell(brightness, row, col),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildCell(Brightness brightness, _GridRow row, _GridColumn col) {
    final enabled = widget.ctx.enabled;
    final value = row.data[col.key];

    // `_label` kolonu (fixed matrix ilk sütun) salt-okunur başlıktır — atla.
    Widget input;
    switch (col.type) {
      case 'checkbox':
        return AppCheckboxListTile(
          title: col.label,
          value: value == true,
          enabled: enabled,
          showDivider: false,
          onChanged: (v) => _updateCell(row.id, col.key, v ?? false),
        );

      case 'select':
        input = AppDropdown<dynamic>(
          items: col.options
              .map((o) => AppDropdownItem<dynamic>(value: o, label: o))
              .toList(),
          value: value,
          enabled: enabled,
          onChanged: (v) => _updateCell(row.id, col.key, v),
        );
        break;

      case 'date':
        final label = value?.toString();
        input = InkWell(
          onTap: enabled ? () => _pickDate(row, col) : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: AppColors.divider(brightness)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: AppColors.textSecondary(brightness)),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  (label != null && label.isNotEmpty) ? label : 'Tarih seç',
                  style: AppTypography.body.copyWith(
                    color: (label != null && label.isNotEmpty)
                        ? AppColors.textPrimary(brightness)
                        : AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        );
        break;

      case 'computed':
        // v1: salt-okunur (ifade değerlendirme mobilde yok).
        input = Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: AppColors.divider(brightness)),
            color: AppColors.surface(brightness),
          ),
          child: Text(
            value?.toString() ?? '—',
            style: AppTypography.body
                .copyWith(color: AppColors.textSecondary(brightness)),
          ),
        );
        break;

      case 'number':
      case 'currency':
        input = AppTextField(
          controller: _controllerFor(row.id, col.key, value?.toString() ?? ''),
          enabled: enabled,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => _updateCell(
              row.id, col.key, v.trim().isEmpty ? null : num.tryParse(v.trim())),
        );
        break;

      default: // text
        input = AppTextField(
          controller: _controllerFor(row.id, col.key, value?.toString() ?? ''),
          enabled: enabled,
          onChanged: (v) => _updateCell(row.id, col.key, v),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          col.label,
          style: AppTypography.caption1.copyWith(
            color: AppColors.textSecondary(brightness),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        input,
      ],
    );
  }

  Future<void> _pickDate(_GridRow row, _GridColumn col) async {
    final current = DateTime.tryParse(row.data[col.key]?.toString() ?? '');
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final iso = picked.toIso8601String().split('T').first;
    setState(() => row.data[col.key] = iso);
    _emit();
  }
}

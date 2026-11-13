import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../field_render_context.dart';
import 'field_scaffold.dart';

/// `select` → açılır liste. Değer: seçilen seçeneğin `value`'su.
class SelectFieldWidget extends FieldWidget {
  const SelectFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final field = ctx.field;
    final opts = field.options;
    if (opts.isLookup && (opts.table ?? '').isNotEmpty) {
      return _LookupSelectField(ctx: ctx);
    }
    final items = field.options.items
        .map((o) => AppDropdownItem<dynamic>(
              value: o.value,
              label: o.label,
              enabled: !o.disabled,
            ))
        .toList();

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: ctx.errorText,
      child: AppDropdown<dynamic>(
        items: items,
        value: ctx.value,
        placeholder: field.placeholder,
        enabled: ctx.enabled,
        onChanged: (v) => ctx.onChanged(v),
      ),
    );
  }
}

/// `select` whose options come from a table (`options.type == 'lookup'`, e.g.
/// the service-request priority). Options are read once through
/// [LookupService.selectOptions] (static filters with `null` → IS NULL, as on
/// the web) and again when the `dependsOn` source value changes. A failed read
/// shows "options could not be loaded" with a retry, not an empty list.
class _LookupSelectField extends StatefulWidget {
  final FieldRenderContext ctx;
  const _LookupSelectField({required this.ctx});

  @override
  State<_LookupSelectField> createState() => _LookupSelectFieldState();
}

class _LookupSelectFieldState extends State<_LookupSelectField> {
  List<FieldOption> _options = const [];
  bool _loading = true;
  bool _failed = false;

  Object? get _dependsOnValue {
    final dep = widget.ctx.field.options.dependsOn;
    return dep == null ? null : widget.ctx.formValues[dep.fieldCode];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _LookupSelectField old) {
    super.didUpdateWidget(old);
    final dep = widget.ctx.field.options.dependsOn;
    if (dep != null && old.ctx.formValues[dep.fieldCode] != _dependsOnValue) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final options = await sl<LookupService>().selectOptions(
        widget.ctx.field.options,
        dependsOnValues: widget.ctx.formValues,
      );
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final field = ctx.field;
    final value = ctx.value?.toString();
    final items = _options
        .map((o) => AppDropdownItem<dynamic>(
              value: o.value,
              label: o.label,
              enabled: !o.disabled,
            ))
        .toList();
    final known = value == null || _options.any((o) => o.value == value);
    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: _failed
          ? sl<LocalizationService>().translate('field.options_load_failed')
          : ctx.errorText,
      child: Row(
        children: [
          Expanded(
            child: AppDropdown<dynamic>(
              items: items,
              value: known ? value : null,
              placeholder: field.placeholder,
              enabled: ctx.enabled && !_loading,
              onChanged: (v) => ctx.onChanged(v),
            ),
          ),
          if (_failed)
            AppIconButton(
              icon: Icons.refresh,
              tooltip: sl<LocalizationService>().translate('common.retry'),
              onPressed: _load,
            ),
        ],
      ),
    );
  }
}

/// `radio` → seçenek grubu. Değer: seçilen seçeneğin `value`'su.
class RadioFieldWidget extends FieldWidget {
  const RadioFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final field = ctx.field;
    final options = field.options.items;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: ctx.errorText,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            AppRadioListTile<dynamic>(
              title: options[i].label,
              value: options[i].value,
              groupValue: ctx.value,
              enabled: ctx.enabled && !options[i].disabled,
              showDivider: i < options.length - 1,
              onChanged: (v) => ctx.onChanged(v),
            ),
        ],
      ),
    );
  }
}

/// `checkbox` → tekil boolean onay kutusu. Değer: bool.
class CheckboxFieldWidget extends FieldWidget {
  const CheckboxFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final field = ctx.field;
    final checked = ctx.value == true;

    // Etiket, tile başlığında gösterilir; scaffold yalnızca hata/yardım metnini
    // ve zorunluluk işaretini üstlenir (labelText null).
    return FieldScaffold(
      required: field.isRequired,
      helpText: field.helpText,
      errorText: ctx.errorText,
      child: AppCheckboxListTile(
        title: field.label,
        subtitle: field.placeholder,
        value: checked,
        enabled: ctx.enabled,
        showDivider: false,
        onChanged: (v) => ctx.onChanged(v ?? false),
      ),
    );
  }
}

/// `multiselect` → çoklu onay kutusu listesi. Değer: List (seçili `value`'lar).
class MultiselectFieldWidget extends FieldWidget {
  const MultiselectFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final field = ctx.field;
    final options = field.options.items;
    final selected =
        ctx.value is List ? List<dynamic>.from(ctx.value) : <dynamic>[];

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: ctx.errorText,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            AppCheckboxListTile(
              title: options[i].label,
              value: selected.contains(options[i].value),
              enabled: ctx.enabled && !options[i].disabled,
              showDivider: i < options.length - 1,
              onChanged: (checked) {
                final next = List<dynamic>.from(selected);
                if (checked == true) {
                  if (!next.contains(options[i].value)) {
                    next.add(options[i].value);
                  }
                } else {
                  next.remove(options[i].value);
                }
                ctx.onChanged(next);
              },
            ),
        ],
      ),
    );
  }
}

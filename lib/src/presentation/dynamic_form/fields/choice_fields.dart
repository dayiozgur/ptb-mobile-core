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
    final selected = ctx.value is List ? List<dynamic>.from(ctx.value) : <dynamic>[];

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

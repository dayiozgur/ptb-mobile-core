import 'package:flutter/material.dart' hide FormField;

import '../field_render_context.dart';
import 'managed_text_field.dart';

String _displayString(dynamic value) => value?.toString() ?? '';

/// `text` → tek satır metin. Değer: String.
class TextFieldWidget extends FieldWidget {
  const TextFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return ManagedTextField(
      ctx: ctx,
      keyboardType: TextInputType.text,
      transform: (raw) => raw,
      display: _displayString,
    );
  }
}

/// `textarea` → çok satırlı metin. Değer: String.
class TextareaFieldWidget extends FieldWidget {
  const TextareaFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return ManagedTextField(
      ctx: ctx,
      keyboardType: TextInputType.multiline,
      maxLines: 4,
      transform: (raw) => raw,
      display: _displayString,
    );
  }
}

/// `email` → e-posta klavyeli metin. Değer: String.
class EmailFieldWidget extends FieldWidget {
  const EmailFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return ManagedTextField(
      ctx: ctx,
      keyboardType: TextInputType.emailAddress,
      transform: (raw) => raw,
      display: _displayString,
    );
  }
}

/// `phone` → telefon klavyeli metin. Değer: String.
class PhoneFieldWidget extends FieldWidget {
  const PhoneFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return ManagedTextField(
      ctx: ctx,
      keyboardType: TextInputType.phone,
      transform: (raw) => raw,
      display: _displayString,
    );
  }
}

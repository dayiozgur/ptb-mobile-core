import 'package:flutter/material.dart' hide FormField;

import '../../widgets/inputs/app_text_field.dart';
import '../field_render_context.dart';
import 'field_scaffold.dart';

/// Bir string→değer dönüştürücü.
typedef ValueTransform = dynamic Function(String raw);

/// Depolanan değeri text kutusunda gösterilecek metne çeviren dönüştürücü.
typedef ValueDisplay = String Function(dynamic value);

/// Text tabanlı alanlar (text/textarea/email/phone/number/currency/percentage)
/// için ortak, controller sahibi stateful gövde.
///
/// Kendi [TextEditingController]'ını yönetir (contract, lookup gibi alanlarda
/// yerel state'e izin verir; text controller'ı da aynı kapsamdadır) — ancak
/// seçilen/girilen değer daima [FieldRenderContext.onChanged] üzerinden akar.
/// Widget dışarıdan değer değişince (ör. cascade reset) controller'ı senkronlar
/// ama imleç zıplamasını önlemek için yalnızca metin gerçekten farklıysa.
class ManagedTextField extends StatefulWidget {
  final FieldRenderContext ctx;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final Widget? prefixWidget;
  final Widget? suffixWidget;

  /// Ham metni depolanacak değere çevirir (ör. `num.tryParse`).
  final ValueTransform transform;

  /// Depolanan değeri gösterilecek metne çevirir.
  final ValueDisplay display;

  const ManagedTextField({
    super.key,
    required this.ctx,
    required this.transform,
    required this.display,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.prefixWidget,
    this.suffixWidget,
  });

  @override
  State<ManagedTextField> createState() => _ManagedTextFieldState();
}

class _ManagedTextFieldState extends State<ManagedTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.display(widget.ctx.value));
  }

  @override
  void didUpdateWidget(covariant ManagedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dışarıdan gelen değer değiştiyse ve kullanıcının yazdığından farklıysa
    // senkronla (imleç zıplamasını önlemek için yalnızca farklıysa).
    final incoming = widget.display(widget.ctx.value);
    if (incoming != _controller.text) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText,
      child: AppTextField(
        controller: _controller,
        placeholder: field.placeholder,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        minLines: widget.maxLines > 1 ? 3 : null,
        maxLength: widget.maxLength,
        prefixWidget: widget.prefixWidget,
        suffixWidget: widget.suffixWidget,
        enabled: widget.ctx.enabled,
        onChanged: (raw) => widget.ctx.onChanged(widget.transform(raw)),
      ),
    );
  }
}

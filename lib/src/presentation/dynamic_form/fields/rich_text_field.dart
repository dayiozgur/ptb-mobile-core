import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../field_render_context.dart';
import 'field_scaffold.dart';

/// `rich_text` → biçimlendirme araç çubuklu çok-satır editör. Değer: String
/// (markdown metni; `value_text`'e yazılır).
///
/// Web'deki zengin-metin alanının mobil paritesi. Ağır bir editör paketine
/// (flutter_quill vb.) bağımlılık YOK — araç çubuğu seçime markdown işaretleri
/// (kalın `**`, italik `_`, madde `- `, başlık `## `, bağlantı `[..](..)`)
/// ekler. Böylece dinamik-form artık "unsupported" placeholder'a düşmez.
class RichTextFieldWidget extends FieldWidget {
  const RichTextFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _RichTextView(ctx: ctx);
}

class _RichTextView extends StatefulWidget {
  final FieldRenderContext ctx;
  const _RichTextView({required this.ctx});

  @override
  State<_RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<_RichTextView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.ctx.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _RichTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.ctx.value?.toString() ?? '';
    if (incoming != _controller.text) _controller.text = incoming;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit() => widget.ctx.onChanged(_controller.text);

  /// Seçili metni [prefix]/[suffix] ile sarar (kalın/italik). Seçim yoksa
  /// işaretleri imlece ekler ve imleci ortaya koyar.
  void _wrap(String prefix, String suffix) {
    final value = _controller.value;
    final sel = value.selection;
    final text = value.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final selected = text.substring(start, end);
    final replaced = '$prefix$selected$suffix';
    final newText = text.replaceRange(start, end, replaced);
    final caret = selected.isEmpty
        ? start + prefix.length
        : start + replaced.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
    _emit();
  }

  /// İçinde bulunulan satırın başına [token] ekler (madde/başlık).
  void _prefixLine(String token) {
    final value = _controller.value;
    final text = value.text;
    final caret = value.selection.start < 0 ? text.length : value.selection.start;
    var lineStart = caret;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    final newText = text.replaceRange(lineStart, lineStart, token);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret + token.length),
    );
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    final enabled = widget.ctx.enabled;
    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enabled) ...[
            _Toolbar(
              onBold: () => _wrap('**', '**'),
              onItalic: () => _wrap('_', '_'),
              onBullet: () => _prefixLine('- '),
              onHeading: () => _prefixLine('## '),
              onLink: () => _wrap('[', '](https://)'),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          AppTextField(
            controller: _controller,
            placeholder: field.placeholder,
            keyboardType: TextInputType.multiline,
            maxLines: 8,
            minLines: 4,
            enabled: enabled,
            onChanged: (_) => _emit(),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onBullet;
  final VoidCallback onHeading;
  final VoidCallback onLink;

  const _Toolbar({
    required this.onBold,
    required this.onItalic,
    required this.onBullet,
    required this.onHeading,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: brightness == Brightness.light
            ? AppColors.systemGray6
            : AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.format_bold, 'Kalın', onBold),
          _btn(Icons.format_italic, 'İtalik', onItalic),
          _btn(Icons.format_list_bulleted, 'Madde', onBullet),
          _btn(Icons.title, 'Başlık', onHeading),
          _btn(Icons.link, 'Bağlantı', onLink),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, String tooltip, VoidCallback onTap) => IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
      );
}

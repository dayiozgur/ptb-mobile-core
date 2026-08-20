import 'dart:convert';

import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:signature/signature.dart';

import '../field_render_context.dart';
import 'field_scaffold.dart';

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

/// `signature` → imza pad'i. Çizim → PNG bytes → storage'a yükle.
/// Değer: `{"path":.., "name":.., "url":..}` json.
class SignatureFieldWidget extends FieldWidget {
  const SignatureFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _SignatureFieldView(ctx: ctx);
}

class _SignatureFieldView extends StatefulWidget {
  final FieldRenderContext ctx;

  const _SignatureFieldView({required this.ctx});

  @override
  State<_SignatureFieldView> createState() => _SignatureFieldViewState();
}

class _SignatureFieldViewState extends State<_SignatureFieldView> {
  late final SignatureController _controller;
  bool _uploading = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) {
      setState(() => _localError = 'Lütfen önce imza atın.');
      return;
    }
    setState(() {
      _uploading = true;
      _localError = null;
    });
    try {
      final bytes = await _controller.toPngBytes();
      if (bytes == null) {
        _fail('İmza dışa aktarılamadı.');
        return;
      }
      final fileName =
          'signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final result = await sl<FileStorageService>().uploadBytes(
        bytes: bytes,
        fileName: fileName,
        category: StorageCategory.formAttachment,
        access: StorageAccessLevel.private,
        contentType: 'image/png',
      );
      if (!mounted) return;
      if (result.success) {
        setState(() => _uploading = false);
        widget.ctx.onChanged(<String, dynamic>{
          'path': result.path,
          'name': fileName,
          'url': result.signedUrl ?? result.publicUrl,
        });
      } else {
        // Yükleme başarısız → data-URI olarak sakla ki submit engellenmesin.
        // TODO(upload): storage kotası/registry hatasında yeniden dene.
        setState(() {
          _uploading = false;
          _localError = 'Yükleme başarısız: ${result.error ?? ''} (gömülü kaydedildi)';
        });
        widget.ctx.onChanged(<String, dynamic>{
          'name': fileName,
          'data': 'data:image/png;base64,${base64Encode(bytes)}',
        });
      }
    } catch (e) {
      _fail('İmza kaydedilemedi: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _localError = message;
    });
  }

  void _clearPad() {
    _controller.clear();
    setState(() => _localError = null);
    widget.ctx.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    final brightness = Theme.of(context).brightness;
    final map = _asMap(widget.ctx.value);
    final saved = map.isNotEmpty && (map['path'] != null || map['data'] != null);

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText ?? _localError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: saved ? AppColors.success : AppColors.divider(brightness),
                width: saved ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              AppButton(
                label: 'Kaydet',
                icon: Icons.check,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.medium,
                isFullWidth: false,
                isLoading: _uploading,
                onPressed: widget.ctx.enabled ? _save : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Temizle',
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                isFullWidth: false,
                onPressed: widget.ctx.enabled ? _clearPad : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

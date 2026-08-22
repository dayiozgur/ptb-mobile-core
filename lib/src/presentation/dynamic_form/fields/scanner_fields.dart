import 'package:flutter/material.dart' hide FormField;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../field_render_context.dart';
import 'field_scaffold.dart';

/// `barcode` → kamerayla barkod (tüm formatlar) oku, çözülen metni String
/// olarak sakla. Manuel giriş de mümkün (fallback). Değer: String → value_text.
class BarcodeFieldWidget extends FieldWidget {
  const BarcodeFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _ScannerFieldView(ctx: ctx, qrOnly: false);
}

/// `qr_scanner` → yalnız QR kodu oku (e-Fatura/e-Arşiv QR dahil). Değer: String.
class QrScannerFieldWidget extends FieldWidget {
  const QrScannerFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _ScannerFieldView(ctx: ctx, qrOnly: true);
}

class _ScannerFieldView extends StatefulWidget {
  final FieldRenderContext ctx;
  final bool qrOnly;

  const _ScannerFieldView({required this.ctx, required this.qrOnly});

  @override
  State<_ScannerFieldView> createState() => _ScannerFieldViewState();
}

class _ScannerFieldViewState extends State<_ScannerFieldView> {
  late final TextEditingController _controller;
  bool _scanning = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.ctx.value?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _ScannerFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.ctx.value?.toString() ?? '';
    if (incoming != _controller.text) _controller.text = incoming;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _scanning = true;
      _localError = null;
    });
    final scanner = BarcodeScanner(
      formats: widget.qrOnly
          ? const [BarcodeFormat.qrCode]
          : const [BarcodeFormat.all],
    );
    try {
      final XFile? shot = await ImagePicker().pickImage(
        source: source,
        imageQuality: 100,
      );
      if (shot == null) {
        if (mounted) setState(() => _scanning = false);
        return;
      }
      final input = InputImage.fromFilePath(shot.path);
      final codes = await scanner.processImage(input);
      final raw = codes
          .map((b) => b.rawValue ?? b.displayValue ?? '')
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
      if (!mounted) return;
      if (raw.isEmpty) {
        setState(() {
          _scanning = false;
          _localError = widget.qrOnly
              ? 'QR kod okunamadı — tekrar deneyin veya elle girin'
              : 'Barkod okunamadı — tekrar deneyin veya elle girin';
        });
        return;
      }
      _controller.text = raw;
      widget.ctx.onChanged(raw);
      setState(() => _scanning = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _localError = 'Tarama hatası: $e';
      });
    } finally {
      await scanner.close();
    }
  }

  Future<void> _showSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _scan(source);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    final enabled = widget.ctx.enabled;
    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText ?? _localError,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AppTextField(
              controller: _controller,
              placeholder: field.placeholder ??
                  (widget.qrOnly ? 'QR değeri' : 'Barkod değeri'),
              enabled: enabled,
              onChanged: widget.ctx.onChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Tara',
            icon: widget.qrOnly
                ? Icons.qr_code_scanner
                : Icons.barcode_reader,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            isFullWidth: false,
            isLoading: _scanning,
            onPressed: enabled ? _showSourceSheet : null,
          ),
        ],
      ),
    );
  }
}

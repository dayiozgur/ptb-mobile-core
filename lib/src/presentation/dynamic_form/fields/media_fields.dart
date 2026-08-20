import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart' hide FormField;
import 'package:image_picker/image_picker.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

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

/// `image` → kamera/galeriden görsel seç, storage'a yükle, küçük resim göster.
/// Değer: `{"path":.., "name":.., "url":..}` json.
class ImageFieldWidget extends FieldWidget {
  const ImageFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _MediaFieldView(ctx: ctx, isImage: true);
}

/// `file` → cihazdan dosya seç, storage'a yükle, dosya adını göster.
/// Değer: `{"path":.., "name":.., "url":..}` json.
class FileFieldWidget extends FieldWidget {
  const FileFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) =>
      _MediaFieldView(ctx: ctx, isImage: false);
}

class _MediaFieldView extends StatefulWidget {
  final FieldRenderContext ctx;
  final bool isImage;

  const _MediaFieldView({required this.ctx, required this.isImage});

  @override
  State<_MediaFieldView> createState() => _MediaFieldViewState();
}

class _MediaFieldViewState extends State<_MediaFieldView> {
  bool _uploading = false;
  String? _localError;
  File? _localPreview;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _handleFile(File(picked.path), picked.name);
    } catch (e) {
      _fail('Görsel seçilemedi: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles();
      final path = result?.files.single.path;
      if (path == null) return;
      await _handleFile(File(path), result!.files.single.name);
    } catch (e) {
      _fail('Dosya seçilemedi: $e');
    }
  }

  Future<void> _handleFile(File file, String name) async {
    setState(() {
      _uploading = true;
      _localError = null;
      _localPreview = widget.isImage ? file : null;
    });
    try {
      final result = await sl<FileStorageService>().uploadFile(
        file: file,
        category: StorageCategory.formAttachment,
        access: StorageAccessLevel.private,
        fileName: name,
      );
      if (!mounted) return;
      if (result.success) {
        setState(() => _uploading = false);
        widget.ctx.onChanged(<String, dynamic>{
          'path': result.path,
          'name': name,
          'url': result.signedUrl ?? result.publicUrl,
        });
      } else {
        // Yükleme başarısız → yerel yolu sakla ki submit engellenmesin.
        // TODO(upload): storage kotası/registry hatasında yeniden dene.
        setState(() {
          _uploading = false;
          _localError = 'Yükleme başarısız: ${result.error ?? ''} (yerel yol kaydedildi)';
        });
        widget.ctx.onChanged(<String, dynamic>{
          'path': file.path,
          'name': name,
        });
      }
    } catch (e) {
      _fail('Yükleme hatası: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _localError = message;
    });
  }

  void _clear() {
    setState(() {
      _localPreview = null;
      _localError = null;
    });
    widget.ctx.onChanged(null);
  }

  Future<void> _showImageSourceSheet() async {
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
    if (source != null) {
      await _pickImage(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    final brightness = Theme.of(context).brightness;
    final map = _asMap(widget.ctx.value);
    final name = map['name']?.toString();
    final url = map['url']?.toString();
    final hasValue = map.isNotEmpty && (map['path'] != null);

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText ?? _localError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isImage && (hasValue || _localPreview != null)) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: _buildThumbnail(url),
            ),
            const SizedBox(height: AppSpacing.sm),
          ] else if (!widget.isImage && hasValue) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: brightness == Brightness.light
                    ? AppColors.systemGray6
                    : AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      name ?? 'Dosya',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              AppButton(
                label: hasValue
                    ? 'Değiştir'
                    : (widget.isImage ? 'Görsel Ekle' : 'Dosya Ekle'),
                icon: widget.isImage
                    ? Icons.add_a_photo_outlined
                    : Icons.attach_file,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.medium,
                isFullWidth: false,
                isLoading: _uploading,
                onPressed: widget.ctx.enabled
                    ? (widget.isImage ? _showImageSourceSheet : _pickFile)
                    : null,
              ),
              if (hasValue && widget.ctx.enabled) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: AppColors.textSecondary(brightness)),
                  onPressed: _clear,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? url) {
    const double size = 96;
    if (_localPreview != null) {
      return Image.file(_localPreview!,
          width: size, height: size, fit: BoxFit.cover);
    }
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _thumbFallback(size),
      );
    }
    return _thumbFallback(size);
  }

  Widget _thumbFallback(double size) => Container(
        width: size,
        height: size,
        color: AppColors.systemGray6,
        child: const Icon(Icons.image_outlined),
      );
}

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/integration/entity_file_link_service.dart';
import '../../../core/integration/microsoft_integration_service.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/storage/file_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/url_actions.dart';
import '../../widgets/buttons/app_icon_button.dart';
import '../../widgets/cards/app_card.dart';
import '../entities/entity_detail_extensions.dart';
import 'ms_onedrive_picker.dart';

/// Çekirdek i18n yardımcısı — anahtar bulunamazsa Türkçe [fb] gösterilir.
String _t(String k, String fb) {
  final v = sl<LocalizationService>().translate(k);
  return v == k ? fb : v;
}

/// **"Dosyalar" bölümünü tüm entity tiplerine kaydeder** — çekirdek
/// `EntityDetailExtensions` üzerinden `'*'` (tüm tipler) altında [EntityFilesCard]'ı
/// yayar. Kart artık İKİ KAYNAK gösterir: iç depo (`storage_objects`, kota-sayılır)
/// + OneDrive/SharePoint linkleri (`entity_file_links`). Her app kendi
/// `registerXxxScreens()`'inden bir kez çağırır.
void registerMicrosoftFilesSection() {
  EntityDetailExtensions.registerSections('*', (ctx, e, reload) {
    final t = e.entityType;
    if (t == null || t.isEmpty) return const <Widget>[];
    // The card renders nothing until there is something to show (internal file or a
    // connected MS account), so users with neither get zero footprint.
    return [EntityFilesCard(entityType: t, entityId: e.id)];
  });
}

/// **Files card for any entity** — the mobile parity of the web two-source entity
/// "Files" card. Lists BOTH the internal (our-storage) files scoped to
/// [entityType]/[entityId] (via `storage_objects`, quota-counted) and the
/// OneDrive/SharePoint links (via `entity_file_links`), each with a source badge.
/// Internal files open via a signed URL (read-only here — delete needs registry +
/// quota cleanup, done on web); MS links open in the browser and can be detached.
class EntityFilesCard extends StatefulWidget {
  final String entityType;
  final String entityId;
  const EntityFilesCard({super.key, required this.entityType, required this.entityId});

  @override
  State<EntityFilesCard> createState() => _EntityFilesCardState();
}

class _EntityFilesCardState extends State<EntityFilesCard> {
  EntityFileLinkService get _links => sl<EntityFileLinkService>();
  FileStorageService get _storage => sl<FileStorageService>();

  List<EntityFileLink> _files = const [];
  List<InternalEntityFile> _internal = const [];
  bool _loading = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Internal files always load; MS links only when connected. A failure on either
    // source never blocks the other (listEntityFiles already returns [] on error).
    final conn = await sl<MicrosoftIntegrationService>().getConnected();
    final connected = conn != null;
    final internal = await _storage.listEntityFiles(widget.entityType, widget.entityId);
    List<EntityFileLink> msFiles = const [];
    if (connected) {
      try {
        msFiles = await _links.list(widget.entityType, widget.entityId);
      } catch (_) {
        msFiles = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _files = msFiles;
      _internal = internal;
      _loading = false;
    });
  }

  Future<void> _attach() async {
    await showMsOneDrivePicker(context, entityType: widget.entityType, entityId: widget.entityId);
    await _load();
  }

  Future<void> _remove(EntityFileLink f) async {
    final ok = await _links.remove(f.id);
    if (ok) {
      await _load();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('crm.files.browse_failed', 'Kaldırılamadı')),
          backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> _openInternal(InternalEntityFile f) async {
    final url = await _storage.getSignedUrl(bucket: f.bucket, path: f.path);
    if (url != null) {
      UrlActions.openUrl(url);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('crm.files.browse_failed', 'Açılamadı')),
          backgroundColor: Colors.red.shade700));
    }
  }

  IconData _iconForName(String name, String? mime) {
    final n = name.toLowerCase();
    final m = (mime ?? '').toLowerCase();
    if (m.contains('pdf') || n.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (m.contains('excel') || m.contains('sheet') || n.endsWith('.xlsx') || n.endsWith('.xls')) return Icons.table_chart;
    if (m.contains('word') || n.endsWith('.docx') || n.endsWith('.doc')) return Icons.description;
    if (m.startsWith('image/') || RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(n)) return Icons.image;
    return Icons.insert_drive_file;
  }

  String _size(int? b) {
    if (b == null || b <= 0) return '';
    if (b < 1024) return '$b B';
    const u = ['KB', 'MB', 'GB'];
    double v = b / 1024;
    int i = 0;
    while (v >= 1024 && i < u.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)} ${u[i]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    // Zero footprint when there is nothing to show and no MS account.
    if (!_connected && _internal.isEmpty) return const SizedBox.shrink();

    final total = _internal.length + _files.length;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.attach_file, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(_t('crm.files.title', 'Dosyalar'), style: AppTypography.subhead),
                  if (total > 0) ...[
                    const SizedBox(width: 6),
                    Text('$total',
                        style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context))),
                  ],
                  const Spacer(),
                  if (_connected)
                    AppIconButton(
                      icon: Icons.cloud_upload_outlined,
                      tooltip: _t('crm.files.attach', 'OneDrive\'dan ekle'),
                      onPressed: _attach,
                    ),
                ],
              ),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_t('crm.files.empty', 'Henüz dosya yok.'),
                      style: AppTypography.footnote.copyWith(color: AppColors.tertiaryLabel(context))),
                )
              else ...[
                for (final f in _internal) _internalRow(f),
                for (final f in _files) _msRow(f),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: AppTypography.caption2.copyWith(color: color, fontWeight: FontWeight.w600)),
      );

  Widget _internalRow(InternalEntityFile f) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(_iconForName(f.name, f.mime), size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: () => _openInternal(f),
                child: Text(f.name,
                    style: AppTypography.footnote.copyWith(decoration: TextDecoration.underline),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            _sourceBadge(_t('files.badge_internal', 'Depomuz'), AppColors.primary),
            if (_size(f.size).isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(_size(f.size),
                  style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
            ],
          ],
        ),
      );

  Widget _msRow(EntityFileLink f) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(_iconForName(f.name, f.mime), size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: () => UrlActions.openUrl(f.webUrl),
                child: Text(f.name,
                    style: AppTypography.footnote.copyWith(decoration: TextDecoration.underline),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 6),
            _sourceBadge(_t('files.badge_onedrive', 'OneDrive'), Colors.blue.shade700),
            if (_size(f.size).isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(_size(f.size),
                  style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
            ],
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              tooltip: _t('common.remove', 'Kaldır'),
              onPressed: () => _remove(f),
            ),
          ],
        ),
      );
}

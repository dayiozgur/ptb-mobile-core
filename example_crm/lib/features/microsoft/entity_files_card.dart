import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import 'ms_onedrive_picker.dart';

/// **Files card for any CRM entity** — the mobile parity of the web entity
/// "Files" card. Lists the OneDrive/SharePoint files linked to [entityType]/
/// [entityId] (via `entity_file_links`), opens each in the browser, removes a
/// link, and attaches a new drive item through the OneDrive picker. The file
/// stays in the user's drive; only a reference is stored. Reused by contact
/// detail and (via EntityDetailExtensions) the deal / company entity detail.
class EntityFilesCard extends StatefulWidget {
  final String entityType;
  final String entityId;
  const EntityFilesCard({super.key, required this.entityType, required this.entityId});

  @override
  State<EntityFilesCard> createState() => _EntityFilesCardState();
}

class _EntityFilesCardState extends State<EntityFilesCard> {
  EntityFileLinkService get _links => sl<EntityFileLinkService>();

  List<EntityFileLink> _files = const [];
  bool _loading = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final conn = await sl<MicrosoftIntegrationService>().getConnected();
    final files = await _links.list(widget.entityType, widget.entityId);
    if (!mounted) return;
    setState(() {
      _connected = conn != null;
      _files = files;
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
          content: Text(crmT('crm.files.browse_failed', 'Kaldırılamadı')),
          backgroundColor: Colors.red.shade700));
    }
  }

  IconData _iconFor(EntityFileLink f) {
    final n = f.name.toLowerCase();
    final m = (f.mime ?? '').toLowerCase();
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
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_file, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(crmT('crm.files.title', 'Dosyalar'), style: AppTypography.subhead),
                if (_files.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('${_files.length}',
                      style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context))),
                ],
                const Spacer(),
                if (_connected)
                  AppIconButton(
                    icon: Icons.cloud_upload_outlined,
                    tooltip: crmT('crm.files.attach', 'OneDrive\'dan ekle'),
                    onPressed: _attach,
                  ),
              ],
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: AppLoadingIndicator()))
            else if (!_connected)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(crmT('crm.files.not_connected', 'OneDrive için Microsoft hesabınızı bağlayın.'),
                    style: AppTypography.footnote.copyWith(color: AppColors.tertiaryLabel(context))),
              )
            else if (_files.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(crmT('crm.files.empty', 'Henüz bağlı dosya yok.'),
                    style: AppTypography.footnote.copyWith(color: AppColors.tertiaryLabel(context))),
              )
            else
              for (final f in _files) _fileRow(f),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(EntityFileLink f) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(_iconFor(f), size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => UrlActions.openUrl(f.webUrl),
                child: Text(f.name,
                    style: AppTypography.footnote.copyWith(decoration: TextDecoration.underline),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
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
              tooltip: crmT('common.remove', 'Kaldır'),
              onPressed: () => _remove(f),
            ),
          ],
        ),
      );
}

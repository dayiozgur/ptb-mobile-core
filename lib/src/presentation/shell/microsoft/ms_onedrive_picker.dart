import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/integration/entity_file_link_service.dart';
import '../../../core/integration/microsoft_integration_service.dart';
import '../../../core/localization/localization_service.dart';

/// Çekirdek i18n yardımcısı — anahtar bulunamazsa Türkçe [fb] gösterilir.
String _t(String k, String fb) {
  final v = sl<LocalizationService>().translate(k);
  return v == k ? fb : v;
}

/// OneDrive file picker (mobile) — browse the connected user's recent drive
/// items (or search), pick one, and link it to a CRM entity via
/// `entity_file_links`. The file stays in OneDrive; only a reference is stored.
Future<void> showMsOneDrivePicker(
  BuildContext context, {
  required String entityType,
  required String entityId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.82,
      child: _OneDrivePicker(entityType: entityType, entityId: entityId),
    ),
  );
}

class _DriveItem {
  final String id;
  final String name;
  final String? webUrl;
  final int? size;
  final String? mime;
  final String? driveId;
  final bool isFolder;
  const _DriveItem(this.id, this.name, this.webUrl, this.size, this.mime, this.driveId, this.isFolder);

  factory _DriveItem.fromMap(Map m) => _DriveItem(
        (m['id'] ?? '') as String,
        (m['name'] ?? '') as String,
        m['webUrl'] as String?,
        (m['size'] as num?)?.toInt(),
        (m['file'] is Map) ? (m['file']['mimeType'] as String?) : null,
        (m['parentReference'] is Map) ? (m['parentReference']['driveId'] as String?) : null,
        m['folder'] != null,
      );
}

class _OneDrivePicker extends StatefulWidget {
  final String entityType;
  final String entityId;
  const _OneDrivePicker({required this.entityType, required this.entityId});
  @override
  State<_OneDrivePicker> createState() => _OneDrivePickerState();
}

class _OneDrivePickerState extends State<_OneDrivePicker> {
  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();
  final _search = TextEditingController();
  List<_DriveItem> _items = const [];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _browse(String path, {Map<String, String>? query}) async {
    setState(() => _loading = true);
    final res = await _svc.graphCall('GET', path, query: query);
    if (!mounted) return;
    if (res == null || !res.ok || res.data is! Map) {
      setState(() {
        _items = const [];
        _loading = false;
      });
      _snack(_t('crm.files.browse_failed', 'Dosyalar yüklenemedi. Lütfen tekrar deneyin.'), error: true);
      return;
    }
    final value = (res.data['value'] as List?) ?? const [];
    setState(() {
      _items = value.map((e) => _DriveItem.fromMap(e as Map)).toList();
      _loading = false;
    });
  }

  Future<void> _loadRecent() =>
      _browse('/me/drive/recent', query: {'\$top': '25', '\$select': 'id,name,size,webUrl,file,folder,parentReference'});

  Future<void> _runSearch() {
    final q = _search.text.trim();
    if (q.isEmpty) return _loadRecent();
    final esc = q.replaceAll("'", "''");
    return _browse("/me/drive/root/search(q='$esc')",
        query: {'\$top': '25', '\$select': 'id,name,size,webUrl,file,folder,parentReference'});
  }

  Future<void> _pick(_DriveItem it) async {
    if (it.webUrl == null || it.isFolder) return;
    setState(() => _adding = true);
    final row = await sl<EntityFileLinkService>().add(
      entityType: widget.entityType,
      entityId: widget.entityId,
      source: 'onedrive',
      name: it.name,
      webUrl: it.webUrl!,
      itemId: it.id,
      driveId: it.driveId,
      size: it.size,
      mime: it.mime,
    );
    if (!mounted) return;
    setState(() => _adding = false);
    if (row != null) {
      _snack(_t('crm.files.attached', 'Dosya eklendi.'));
      Navigator.pop(context);
    } else {
      _snack(_t('crm.files.browse_failed', 'Dosya eklenemedi.'), error: true);
    }
  }

  IconData _iconFor(_DriveItem it) {
    if (it.isFolder) return Icons.folder;
    final n = it.name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (n.endsWith('.xlsx') || n.endsWith('.xls')) return Icons.table_chart;
    if (n.endsWith('.docx') || n.endsWith('.doc')) return Icons.description;
    if (RegExp(r'\.(png|jpe?g|gif|webp)$').hasMatch(n)) return Icons.image;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _t('crm.files.search_files', 'Dosya ara…'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            TextButton(onPressed: _runSearch, child: Text(_t('crm.files.search', 'Ara'))),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_items.isEmpty
                    ? Center(child: Text(_t('crm.files.no_files', 'Bu klasör boş.')))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final it = _items[i];
                          return ListTile(
                            leading: Icon(_iconFor(it)),
                            title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: it.isFolder ? null : const Icon(Icons.add, size: 20),
                            enabled: !it.isFolder && !_adding,
                            onTap: () => _pick(it),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}

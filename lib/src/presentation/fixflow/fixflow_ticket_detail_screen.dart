import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/di/service_locator.dart';
import '../../core/collaboration/comments_service.dart';
import '../../core/fixflow/fixflow_models.dart';
import '../../core/fixflow/fixflow_services.dart';
import '../shell/collaboration/comments_thread.dart';
import '../widgets/feedback/app_empty_state.dart';
import 'fixflow_common.dart';

/// Seçilen fotoğraf (bayt + ad + MIME).
typedef FixflowPickedFile = ({Uint8List bytes, String name, String? mimeType});

/// Fotoğraf seçici — testte enjekte edilir; varsayılan [ImagePicker].
typedef FixflowPhotoPicker = Future<FixflowPickedFile?> Function(
    ImageSource source);

Future<FixflowPickedFile?> _defaultPicker(ImageSource source) async {
  final XFile? x = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2048,
    imageQuality: 85,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  final ext = x.name.split('.').last.toLowerCase();
  final mime = x.mimeType ??
      (ext == 'png'
          ? 'image/png'
          : ext == 'heic'
              ? 'image/heic'
              : 'image/jpeg');
  return (bytes: bytes, name: x.name, mimeType: mime);
}

/// **Bilet detayı** — teknisyen akışı: durum değiştir (yalnız
/// `status-transition` EF), kapat, efor kaydı, fotoğraf eki, yorum.
class FixflowTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final FixflowPhotoPicker? photoPicker;

  /// Yorum thread'ini göster (CommentsService kayıtlı değilse otomatik gizli).
  final bool showComments;

  const FixflowTicketDetailScreen({
    super.key,
    required this.ticketId,
    this.photoPicker,
    this.showComments = true,
  });

  @override
  State<FixflowTicketDetailScreen> createState() =>
      _FixflowTicketDetailScreenState();
}

class _FixflowTicketDetailScreenState extends State<FixflowTicketDetailScreen> {
  FixflowTicket? _ticket;
  FixflowStatusCatalog _catalog = FixflowStatusCatalog.empty;
  List<FixflowTransition> _transitions = const [];
  List<FixflowWorklog> _worklogs = const [];
  List<FixflowAttachment> _attachments = const [];
  bool _loading = true;
  bool _notFound = false;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = FixflowServices.status;
      final tickets = FixflowServices.tickets;
      _catalog = await status.catalog(FixflowConstants.ticketEntity);
      final t = await tickets.getTicket(widget.ticketId);
      if (t == null) {
        if (!mounted) return;
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        status.availableTransitions(FixflowConstants.ticketEntity, t.status),
        tickets.listWorklogs(t.id),
        tickets.listAttachments(t.id),
      ]);
      if (!mounted) return;
      setState(() {
        _ticket = t;
        _transitions = results[0] as List<FixflowTransition>;
        _worklogs = results[1] as List<FixflowWorklog>;
        _attachments = results[2] as List<FixflowAttachment>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Kapatma geçişleri: hedefi `is_final` olan izinli geçişler. Durum kodu
  /// sabitlenmez — tamamen `status_definitions` + `status_transitions`'tan
  /// türetilir. Birden fazlaysa (ör. çözüldü / iptal) kullanıcı seçer; onay
  /// diyaloğu hedef durumun adını gösterir.
  List<FixflowTransition> get _closeTransitions =>
      _transitions.where((t) => t.toStatus.isFinal).toList();

  Future<void> _close() async {
    final finals = _closeTransitions;
    if (finals.isEmpty) return;
    if (finals.length == 1) return _runTransition(finals.first);
    return _pickTransition(only: finals);
  }

  Future<void> _runTransition(FixflowTransition tr) async {
    final t = _ticket;
    if (t == null || _busy) return;
    final comment = await _askComment(tr);
    if (comment == null) return; // iptal
    setState(() => _busy = true);
    try {
      await FixflowServices.status.executeTransition(
        entityType: FixflowConstants.ticketEntity,
        entityId: t.id,
        toStatus: tr.toStatus.code,
        comment: comment,
      );
      _snack(ffT('fixflow.mobile.status_changed', 'Status updated: {status}',
          params: {'status': tr.toStatus.name}));
      await _load();
    } on FixflowTransitionException catch (e) {
      _snack(e.commentRequired
          ? ffT('fixflow.mobile.comment_required',
              'This change requires a comment.')
          : e.forbidden
              ? ffT('fixflow.mobile.transition_forbidden',
                  'You are not allowed to make this change.')
              : ffT('fixflow.mobile.status_change_failed',
                  'Status could not be changed: {error}',
                  params: {'error': e.message}));
    } catch (e) {
      _snack(ffT('fixflow.mobile.status_change_failed',
          'Status could not be changed: {error}',
          params: {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Onay + yorum diyaloğu. İptal → null; yorum boşsa '' döner.
  Future<String?> _askComment(FixflowTransition tr) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? err;
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            title: Text(ffT('fixflow.mobile.change_status_to',
                'Change status to "{status}"?',
                params: {'status': tr.toStatus.name})),
            content: TextField(
              key: const Key('fixflow_transition_comment'),
              controller: ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: tr.requiresComment
                    ? ffT('fixflow.mobile.comment_required_label',
                        'Comment (required)')
                    : ffT('fixflow.mobile.comment_optional_label',
                        'Comment (optional)'),
                errorText: err,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ffT('common.cancel', 'Cancel')),
              ),
              FilledButton(
                key: const Key('fixflow_transition_confirm'),
                onPressed: () {
                  final text = ctrl.text.trim();
                  if (tr.requiresComment && text.isEmpty) {
                    setD(() => err = ffT('fixflow.mobile.comment_required',
                        'This change requires a comment.'));
                    return;
                  }
                  Navigator.of(ctx).pop(text);
                },
                child: Text(ffT('common.confirm', 'Confirm')),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _pickTransition({List<FixflowTransition>? only}) async {
    final options = only ?? _transitions;
    final tr = await showModalBottomSheet<FixflowTransition>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(ffT('fixflow.mobile.change_status', 'Change status'),
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...options.map((t) => ListTile(
                  leading: Icon(Icons.circle,
                      size: 14, color: t.toStatus.color ?? Colors.grey),
                  title: Text(t.toStatus.name),
                  subtitle: (t.name != null && t.name!.isNotEmpty)
                      ? Text(t.name!)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(t),
                )),
          ],
        ),
      ),
    );
    if (tr != null) await _runTransition(tr);
  }

  Future<void> _logWork() async {
    final t = _ticket;
    if (t == null) return;
    final minutesCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? err;
        return StatefulBuilder(builder: (ctx, setD) {
          return AlertDialog(
            title: Text(ffT('fixflow.mobile.log_work', 'Log work')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('fixflow_worklog_minutes'),
                  controller: minutesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: ffT('fixflow.mobile.worklog_minutes',
                        'Time spent (minutes)'),
                    errorText: err,
                  ),
                ),
                TextField(
                  key: const Key('fixflow_worklog_desc'),
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: ffT('fixflow.mobile.worklog_description',
                        'What was done?'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ffT('common.cancel', 'Cancel')),
              ),
              FilledButton(
                key: const Key('fixflow_worklog_save'),
                onPressed: () {
                  final m = int.tryParse(minutesCtrl.text.trim());
                  if (m == null || m <= 0) {
                    setD(() => err = ffT('fixflow.mobile.worklog_invalid',
                        'Enter a positive number of minutes.'));
                    return;
                  }
                  Navigator.of(ctx).pop(true);
                },
                child: Text(ffT('common.save', 'Save')),
              ),
            ],
          );
        });
      },
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await FixflowServices.tickets.addWorklog(
        entityId: t.id,
        minutes: int.parse(minutesCtrl.text.trim()),
        description: descCtrl.text,
      );
      final list = await FixflowServices.tickets.listWorklogs(t.id);
      if (mounted) setState(() => _worklogs = list);
      _snack(ffT('fixflow.mobile.worklog_saved', 'Work logged.'));
    } catch (e) {
      _snack(ffT('fixflow.mobile.worklog_failed',
          'Work could not be logged: {error}',
          params: {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPhoto() async {
    final t = _ticket;
    if (t == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(ffT('fixflow.mobile.take_photo', 'Take photo')),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(
                  ffT('fixflow.mobile.choose_from_gallery', 'Choose from gallery')),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    FixflowPickedFile? picked;
    try {
      picked = await (widget.photoPicker ?? _defaultPicker)(source);
    } catch (e) {
      _snack(ffT('fixflow.mobile.photo_pick_failed',
          'Photo could not be selected: {error}',
          params: {'error': e}));
      return;
    }
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await FixflowServices.tickets.uploadAttachment(
        entityId: t.id,
        bytes: picked.bytes,
        fileName: picked.name,
        mimeType: picked.mimeType,
      );
      final list = await FixflowServices.tickets.listAttachments(t.id);
      if (mounted) setState(() => _attachments = list);
      _snack(ffT('fixflow.mobile.attachment_uploaded', 'Photo attached.'));
    } catch (e) {
      _snack(ffT('fixflow.mobile.attachment_failed',
          'Photo could not be attached: {error}',
          params: {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAttachment(FixflowAttachment a) async {
    final url = await FixflowServices.tickets.attachmentUrl(a);
    if (!mounted) return;
    if (url == null) {
      _snack(ffT('fixflow.mobile.attachment_open_failed',
          'Attachment could not be opened.'));
      return;
    }
    if (!a.isImage) {
      _snack(a.fileName);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url,
              errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(ffT('fixflow.mobile.attachment_open_failed',
                        'Attachment could not be opened.')),
                  )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.displayCode ??
            ffT('fixflow.mobile.ticket_detail', 'Ticket')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _content(),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_notFound) {
      return Center(
        child: AppEmptyState(
          icon: Icons.search_off,
          title: ffT('fixflow.mobile.ticket_not_found', 'Ticket not found'),
          message: ffT('fixflow.mobile.ticket_not_found_hint',
              'It may have been removed or you may not have access.'),
        ),
      );
    }
    if (_error != null || _ticket == null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: ffT('fixflow.mobile.load_failed', 'Could not load'),
          message: ffT('fixflow.mobile.try_again_hint',
              'Check your connection and try again.'),
          actionLabel: ffT('fixflow.mobile.retry', 'Retry'),
          onAction: _load,
        ),
      );
    }
    final t = _ticket!;
    final theme = Theme.of(context);
    final hasClose = _closeTransitions.isNotEmpty;
    final showComments =
        widget.showComments && sl.isRegistered<CommentsService>();
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t.subject, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                FixflowStatusChip(status: t.status, catalog: _catalog),
                FixflowPriorityChip(
                  code: t.priorityCode,
                  name: t.priorityName,
                  colorHex: t.priorityColor,
                ),
              ]),
              const SizedBox(height: 12),
              _info(ffT('fixflow.mobile.assignee', 'Assignee'),
                  t.assignedToName),
              _info(ffT('fixflow.mobile.location', 'Location'),
                  t.locationName),
              _info(ffT('fixflow.mobile.category', 'Category'),
                  t.categoryName),
              _info(ffT('fixflow.mobile.due_date', 'Due date'),
                  t.dueDate == null ? null : fixflowDateTime(t.dueDate)),
              _info(ffT('fixflow.mobile.created_at', 'Created'),
                  fixflowDateTime(t.createdAt)),
              if (t.description != null && t.description!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t.description!, style: theme.textTheme.bodyMedium),
                ),
              if (t.resolutionNote != null &&
                  t.resolutionNote!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _info(
                      ffT('fixflow.mobile.resolution_note', 'Resolution'),
                      t.resolutionNote),
                ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (_transitions.isNotEmpty)
                  FilledButton.tonalIcon(
                    key: const Key('fixflow_change_status'),
                    onPressed: _busy ? null : () => _pickTransition(),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                        ffT('fixflow.mobile.change_status', 'Change status')),
                  ),
                if (hasClose)
                  FilledButton.icon(
                    key: const Key('fixflow_close_ticket'),
                    onPressed: _busy ? null : _close,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                        ffT('fixflow.mobile.close_ticket', 'Close ticket')),
                  ),
              ]),
              if (_transitions.isEmpty && !_catalog.isFinal(t.status))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ffT('fixflow.mobile.no_transitions',
                        'No status change is available to you.'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              const Divider(height: 32),
              _sectionHeader(
                ffT('fixflow.mobile.worklogs', 'Work log'),
                trailing: TextButton.icon(
                  key: const Key('fixflow_log_work'),
                  onPressed: _busy ? null : _logWork,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(ffT('fixflow.mobile.log_work', 'Log work')),
                ),
              ),
              if (_worklogs.isEmpty)
                _muted(ffT('fixflow.mobile.no_worklogs', 'No work logged yet.'))
              else ...[
                _muted(ffT('fixflow.mobile.worklog_total', 'Total: {total}',
                    params: {
                      'total': fixflowMinutes(
                          _worklogs.fold<int>(0, (s, w) => s + w.minutes)),
                    })),
                ..._worklogs.map((w) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(fixflowMinutes(w.minutes)),
                      subtitle: Text([
                        fixflowDate(w.workDate),
                        if (w.description != null) w.description!,
                      ].where((s) => s.isNotEmpty).join(' · ')),
                    )),
              ],
              const Divider(height: 32),
              _sectionHeader(
                ffT('fixflow.mobile.attachments', 'Photos & files'),
                trailing: TextButton.icon(
                  key: const Key('fixflow_add_photo'),
                  onPressed: _busy ? null : _addPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(ffT('fixflow.mobile.add_photo', 'Add photo')),
                ),
              ),
              if (_attachments.isEmpty)
                _muted(ffT('fixflow.mobile.no_attachments', 'No attachments.'))
              else
                ..._attachments.map((a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(a.isImage
                          ? Icons.image_outlined
                          : Icons.insert_drive_file_outlined),
                      title: Text(a.fileName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(fixflowDateTime(a.createdAt)),
                      onTap: () => _openAttachment(a),
                    )),
              if (showComments) ...[
                const Divider(height: 32),
                _sectionHeader(ffT('fixflow.mobile.comments', 'Comments')),
                CommentsThread(
                  entityType: FixflowConstants.ticketEntity,
                  entityId: t.id,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_busy)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _info(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) => Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (trailing != null) trailing,
        ],
      );

  Widget _muted(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
      );
}

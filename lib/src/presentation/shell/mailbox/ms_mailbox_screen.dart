import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Microsoft (Outlook) mailbox — mobile, in CORE.** The mobile parity of the
/// web CrmMailboxComponent, placed in `protoolbag_core` so EVERY thin app (CRM,
/// PPM, PHR…) can surface it, not just the CRM app. Lists the connected user's
/// inbox (`GET /me/mailFolders/inbox/messages`), opens a message
/// (`GET /me/messages/{id}`), and composes / replies (`POST /me/sendMail`,
/// Mail.Send) — all through the shared graph-proxy on the user's own connection.
class MsMailboxScreen extends StatefulWidget {
  const MsMailboxScreen({super.key});
  @override
  State<MsMailboxScreen> createState() => _MsMailboxScreenState();
}

class _MailItem {
  final String id;
  final String subject;
  final String fromName;
  final String fromAddress;
  final String received;
  bool isRead;
  final String preview;
  _MailItem(this.id, this.subject, this.fromName, this.fromAddress, this.received, this.isRead, this.preview);
}

String _t(String k) => sl<LocalizationService>().translate(k);

/// Minimal HTML→text for the reading pane (Flutter has no native HTML render).
String htmlToText(String html) {
  var s = html.replaceAll(RegExp(r'<(style|script)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&#39;', "'").replaceAll('&quot;', '"');
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

class _MsMailboxScreenState extends State<MsMailboxScreen> {
  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();

  bool _loading = true;
  bool _connected = false;
  bool _syncing = false;
  List<_MailItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final conn = await _svc.getConnected();
    if (conn == null) {
      if (mounted) setState(() { _connected = false; _loading = false; });
      return;
    }
    final res = await _svc.graphCall('GET', '/me/mailFolders/inbox/messages', query: {
      '\$top': '30',
      '\$orderby': 'receivedDateTime desc',
      '\$select': 'id,subject,from,receivedDateTime,isRead,bodyPreview',
    });
    if (!mounted) return;
    if (res == null || !res.ok || res.data is! Map) {
      setState(() { _connected = true; _items = const []; _loading = false; });
      return;
    }
    final value = (res.data['value'] as List?) ?? const [];
    setState(() {
      _connected = true;
      _items = value.map((m) => _map(m as Map)).toList();
      _loading = false;
    });
  }

  _MailItem _map(Map m) {
    final from = (m['from'] is Map) ? (m['from']['emailAddress'] as Map?) : null;
    return _MailItem(
      m['id'] as String,
      (m['subject'] as String?) ?? '',
      (from?['name'] as String?) ?? '',
      (from?['address'] as String?) ?? '',
      (m['receivedDateTime'] as String?) ?? '',
      (m['isRead'] as bool?) ?? true,
      ((m['bodyPreview'] as String?) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
  }

  Future<void> _syncToCrm() async {
    setState(() => _syncing = true);
    final ok = await _svc.syncMailbox();
    if (!mounted) return;
    setState(() => _syncing = false);
    _snack(ok ? _t('crm.mailbox.synced') : _t('crm.mailbox.sync_failed'), error: !ok);
  }

  Future<void> _connect() async {
    final url = await _svc.startConnect(redirectAfter: 'ptbcrm://oauth-callback');
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _snack(_t('crm.mailbox.load_failed'), error: true);
    }
  }

  Future<void> _open(_MailItem m) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _MailDetailScreen(item: m)));
    if (!m.isRead && mounted) setState(() {}); // read-state may have flipped
  }

  Future<void> _compose({String? to, String? subject}) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MsComposeSheet(to: to, subject: subject),
    );
    if (sent == true) _snack(_t('crm.outlook_reply.sent'));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _t('crm.mailbox.title'),
      showBackButton: true,
      actions: [
        if (_connected) ...[
          AppIconButton(icon: _syncing ? Icons.hourglass_bottom : Icons.cloud_download_outlined, tooltip: _t('crm.mailbox.sync_to_crm'), onPressed: _syncing ? null : _syncToCrm),
          AppIconButton(icon: Icons.refresh, onPressed: _load),
        ],
      ],
      floatingActionButton: _connected
          ? FloatingActionButton(onPressed: () => _compose(), child: const Icon(Icons.edit_outlined))
          : null,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : (!_connected
              ? Center(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AppEmptyState(icon: Icons.mark_email_unread_outlined, title: _t('crm.mailbox.not_connected')),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(label: _t('crm.mailbox.connect'), icon: Icons.link, isFullWidth: false, onPressed: _connect),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 140),
                          Center(child: AppEmptyState(icon: Icons.inbox_outlined, title: _t('crm.mailbox.empty'))),
                        ])
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _row(_items[i]),
                        ),
                )),
    );
  }

  Widget _row(_MailItem m) {
    final w = m.isRead ? FontWeight.w500 : FontWeight.w700;
    return ListTile(
      onTap: () => _open(m),
      title: Row(children: [
        Expanded(child: Text(m.fromName.isNotEmpty ? m.fromName : m.fromAddress, style: TextStyle(fontWeight: w), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(_shortDate(m.received), style: AppTypography.caption2.copyWith(color: AppColors.tertiaryLabel(context))),
      ]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.subject.isEmpty ? _t('crm.mailbox.no_subject') : m.subject, style: TextStyle(fontWeight: w), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(m.preview, style: AppTypography.caption1.copyWith(color: AppColors.secondaryLabel(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? '' : AppClock.date(d.toLocal());
  }
}

/// Reading pane for one message.
class _MailDetailScreen extends StatefulWidget {
  final _MailItem item;
  const _MailDetailScreen({required this.item});
  @override
  State<_MailDetailScreen> createState() => _MailDetailScreenState();
}

class _MailDetailScreenState extends State<_MailDetailScreen> {
  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();
  bool _loading = true;
  String _body = '';
  String _to = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _svc.graphCall('GET', '/me/messages/${widget.item.id}', query: {'\$select': 'body,toRecipients'});
    if (!mounted) return;
    if (res != null && res.ok && res.data is Map) {
      final body = res.data['body'] as Map?;
      final content = (body?['content'] as String?) ?? '';
      final isHtml = (body?['contentType'] as String?) == 'html';
      final toList = (res.data['toRecipients'] as List? ?? []).map((r) => ((r as Map)['emailAddress'] as Map?)?['address'] as String? ?? '').where((s) => s.isNotEmpty).toList();
      setState(() {
        _body = isHtml ? htmlToText(content) : content.trim();
        _to = toList.join(', ');
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
    // best-effort mark-read
    if (!widget.item.isRead) {
      _svc.graphCall('PATCH', '/me/messages/${widget.item.id}', body: {'isRead': true}).then((_) => widget.item.isRead = true).catchError((_) => false);
    }
  }

  Future<void> _reply() async {
    final s = widget.item.subject;
    final subject = RegExp(r'^re:', caseSensitive: false).hasMatch(s) ? s : 'Re: $s';
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MsComposeSheet(to: widget.item.fromAddress, subject: subject),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('crm.outlook_reply.sent'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    return AppScaffold(
      title: m.subject.isEmpty ? _t('crm.mailbox.no_subject') : m.subject,
      showBackButton: true,
      actions: [AppIconButton(icon: Icons.reply, tooltip: _t('crm.mailbox.reply'), onPressed: _reply)],
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                Text(m.subject.isEmpty ? _t('crm.mailbox.no_subject') : m.subject, style: AppTypography.headline),
                const SizedBox(height: AppSpacing.xs),
                Text('${m.fromName.isNotEmpty ? m.fromName : m.fromAddress}${m.fromAddress.isNotEmpty ? ' <${m.fromAddress}>' : ''}',
                    style: AppTypography.footnote.copyWith(color: AppColors.secondaryLabel(context))),
                if (_to.isNotEmpty)
                  Text('${_t('crm.outlook_reply.to')}: $_to', style: AppTypography.caption1.copyWith(color: AppColors.tertiaryLabel(context))),
                const Divider(height: AppSpacing.lg),
                SelectableText(_body, style: AppTypography.body),
              ],
            ),
    );
  }
}

/// Compose/reply sheet — sends from the connected Outlook mailbox via
/// `/me/sendMail` (Mail.Send). Returns true on a successful send.
class MsComposeSheet extends StatefulWidget {
  final String? to;
  final String? subject;
  const MsComposeSheet({super.key, this.to, this.subject});
  @override
  State<MsComposeSheet> createState() => _MsComposeSheetState();
}

class _MsComposeSheetState extends State<MsComposeSheet> {
  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();
  late final _to = TextEditingController(text: widget.to ?? '');
  late final _subject = TextEditingController(text: widget.subject ?? '');
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _to.text.trim();
    if (to.isEmpty || _body.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final res = await _svc.graphCall('POST', '/me/sendMail', body: {
      'message': {
        'subject': _subject.text.trim(),
        'body': {'contentType': 'Text', 'content': _body.text.trim()},
        'toRecipients': [{'emailAddress': {'address': to}}],
      },
      'saveToSentItems': true,
    });
    if (!mounted) return;
    setState(() => _sending = false);
    if (res != null && res.ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('crm.outlook_reply.failed')), backgroundColor: Colors.red.shade700));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_t('crm.mailbox.new_mail'), style: AppTypography.subhead),
        const SizedBox(height: AppSpacing.sm),
        TextField(controller: _to, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: _t('crm.outlook_reply.to'), isDense: true)),
        const SizedBox(height: AppSpacing.sm),
        TextField(controller: _subject, decoration: InputDecoration(labelText: _t('crm.outlook_reply.subject'), isDense: true)),
        const SizedBox(height: AppSpacing.sm),
        TextField(controller: _body, maxLines: 6, decoration: InputDecoration(labelText: _t('crm.outlook_reply.body'), alignLabelWithHint: true)),
        const SizedBox(height: AppSpacing.md),
        AppButton(label: _t('crm.teams.send'), icon: Icons.send, isLoading: _sending, onPressed: _sending ? null : _send),
      ]),
    );
  }
}

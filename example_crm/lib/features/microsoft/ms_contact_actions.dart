import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import 'ms_onedrive_picker.dart';

/// Bottom sheet of Microsoft actions for a CRM contact — the mobile parity of
/// the web contact-detail action bar. Each action proxies Microsoft Graph
/// through `graph-proxy` (delegated scopes on the user's connected account):
///   • Teams meeting  — POST /me/onlineMeetings → share the join link
///   • Teams message  — resolve user → 1:1 chat → send (Chat.ReadWrite)
///   • Outlook email  — POST /me/sendMail (Mail.Send)
///   • OneDrive file  — pick a drive item and link it to the contact
///
/// Opens only when a Microsoft account is connected; otherwise it points the
/// user to Settings → Integrations.
Future<void> showMsContactActions(
  BuildContext context, {
  required String contactId,
  required String? contactName,
  required String? contactEmail,
}) async {
  final svc = sl<MicrosoftIntegrationService>();
  final connected = await svc.getConnected();
  if (!context.mounted) return;
  if (connected == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(crmT('crm.files.not_connected',
          'OneDrive / Teams için Microsoft hesabınızı Ayarlar → Entegrasyonlar\'dan bağlayın.')),
    ));
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _MsActionsSheet(
      contactId: contactId,
      contactName: contactName,
      contactEmail: contactEmail,
    ),
  );
}

class _MsActionsSheet extends StatelessWidget {
  final String contactId;
  final String? contactName;
  final String? contactEmail;
  const _MsActionsSheet({required this.contactId, this.contactName, this.contactEmail});

  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();

  void _snack(BuildContext c, String msg, {bool error = false}) {
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.video_call_outlined),
            title: Text(crmT('crm.teams.meeting_action', 'Teams Toplantısı')),
            onTap: () => _teamsMeeting(context),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: Text(crmT('crm.teams.chat_action', 'Teams\'te Mesaj')),
            enabled: (contactEmail ?? '').isNotEmpty,
            onTap: () => _teamsChat(context),
          ),
          ListTile(
            leading: const Icon(Icons.outgoing_mail),
            title: Text(crmT('crm.outlook_reply.compose', 'Outlook ile e-posta')),
            enabled: (contactEmail ?? '').isNotEmpty,
            onTap: () => _outlookEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: Text(crmT('crm.files.attach', 'OneDrive\'dan dosya ekle')),
            onTap: () => _attachFile(context),
          ),
        ],
      ),
    );
  }

  // ── Teams meeting ───────────────────────────────────────────────────────────
  Future<void> _teamsMeeting(BuildContext context) async {
    Navigator.pop(context);
    final now = DateTime.now().toUtc();
    final res = await _svc.graphCall('POST', '/me/onlineMeetings', body: {
      'startDateTime': now.add(const Duration(hours: 1)).toIso8601String(),
      'endDateTime': now.add(const Duration(hours: 2)).toIso8601String(),
      'subject': crmT('crm.teams.meeting_subject', 'Toplantı')
          .replaceAll('{{name}}', contactName ?? ''),
    });
    if (!context.mounted) return;
    final join = (res?.data is Map) ? (res!.data['joinWebUrl'] as String?) : null;
    if (res == null || !res.ok || join == null) {
      _snack(context, crmT('crm.teams.meeting_failed', 'Teams toplantısı oluşturulamadı'), error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(crmT('crm.teams.meeting_title', 'Teams toplantısı oluşturuldu')),
        content: SelectableText(join),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: join));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) _snack(context, crmT('crm.teams.copied', 'Bağlantı kopyalandı'));
            },
            child: Text(crmT('crm.teams.copy', 'Kopyala')),
          ),
          TextButton(
            onPressed: () {
              UrlActions.openUrl(join);
              Navigator.pop(ctx);
            },
            child: Text(crmT('crm.teams.open', 'Aç')),
          ),
        ],
      ),
    );
  }

  // ── Teams 1:1 chat ──────────────────────────────────────────────────────────
  Future<void> _teamsChat(BuildContext context) async {
    Navigator.pop(context);
    final email = contactEmail!;
    final msg = await _promptText(context,
        title: crmT('crm.teams.chat_title', 'Teams\'te Mesaj'),
        hint: crmT('crm.teams.message_ph', 'Mesajınızı yazın…'),
        multiline: true);
    if (msg == null || msg.trim().isEmpty || !context.mounted) return;

    final u = await _svc.graphCall('GET', '/users/${Uri.encodeComponent(email)}',
        query: {'\$select': 'id,displayName'});
    final targetId = (u?.data is Map) ? (u!.data['id'] as String?) : null;
    if (u?.status == 404 || targetId == null) {
      if (context.mounted) _snack(context, crmT('crm.teams.user_not_found', 'Bu e-posta bir Microsoft kullanıcısına eşleşmiyor'), error: true);
      return;
    }
    final me = await _svc.graphCall('GET', '/me', query: {'\$select': 'id'});
    final myId = (me?.data is Map) ? (me!.data['id'] as String?) : null;
    if (myId == null) {
      if (context.mounted) _snack(context, crmT('crm.teams.chat_failed', 'Teams mesajı gönderilemedi'), error: true);
      return;
    }
    final chat = await _svc.graphCall('POST', '/chats', body: {
      'chatType': 'oneOnOne',
      'members': [
        {
          '@odata.type': '#microsoft.graph.aadUserConversationMember',
          'roles': ['owner'],
          'user@odata.bind': "https://graph.microsoft.com/v1.0/users('$targetId')",
        },
        {
          '@odata.type': '#microsoft.graph.aadUserConversationMember',
          'roles': ['owner'],
          'user@odata.bind': "https://graph.microsoft.com/v1.0/users('$myId')",
        },
      ],
    });
    final chatId = (chat?.data is Map) ? (chat!.data['id'] as String?) : null;
    if (chatId == null) {
      // Most common cause: the recipient is a shared mailbox / not Teams-licensed.
      if (context.mounted) _snack(context, crmT('crm.teams.chat_no_teams', 'Bu kişiyle Teams sohbeti açılamadı (Teams hesabı olmayabilir).'), error: true);
      return;
    }
    final sent = await _svc.graphCall('POST', '/chats/$chatId/messages',
        body: {'body': {'content': msg.trim()}});
    if (!context.mounted) return;
    _snack(context,
        (sent != null && sent.ok)
            ? crmT('crm.teams.chat_sent', 'Teams\'te mesaj gönderildi')
            : crmT('crm.teams.chat_failed', 'Teams mesajı gönderilemedi'),
        error: !(sent != null && sent.ok));
  }

  // ── Outlook email ─────────────────────────────────────────────────────────
  Future<void> _outlookEmail(BuildContext context) async {
    Navigator.pop(context);
    final email = contactEmail!;
    final composed = await showModalBottomSheet<_Email>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ComposeSheet(to: email),
    );
    if (composed == null || !context.mounted) return;
    final res = await _svc.graphCall('POST', '/me/sendMail', body: {
      'message': {
        'subject': composed.subject,
        'body': {'contentType': 'Text', 'content': composed.body},
        'toRecipients': [
          {'emailAddress': {'address': email}}
        ],
      },
      'saveToSentItems': true,
    });
    if (!context.mounted) return;
    _snack(context,
        (res != null && res.ok)
            ? '${crmT('crm.outlook_reply.sent', 'E-posta gönderildi')}: $email'
            : crmT('crm.outlook_reply.failed', 'E-posta gönderilemedi'),
        error: !(res != null && res.ok));
  }

  // ── OneDrive attach ─────────────────────────────────────────────────────────
  Future<void> _attachFile(BuildContext context) async {
    Navigator.pop(context);
    await showMsOneDrivePicker(context, entityType: 'contact', entityId: contactId);
  }

  // ── helpers ──────────────────────────────────────────────────────────────────
  Future<String?> _promptText(BuildContext context,
      {required String title, required String hint, bool multiline = false}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: multiline ? 4 : 1,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(crmT('common.cancel', 'İptal'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(crmT('crm.teams.send', 'Gönder'))),
        ],
      ),
    );
  }
}

class _Email {
  final String subject;
  final String body;
  const _Email(this.subject, this.body);
}

class _ComposeSheet extends StatefulWidget {
  final String to;
  const _ComposeSheet({required this.to});
  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _subject = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${crmT('crm.outlook_reply.to', 'Alıcı')}: ${widget.to}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _subject,
            decoration: InputDecoration(labelText: crmT('crm.outlook_reply.subject', 'Konu')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            maxLines: 5,
            decoration: InputDecoration(labelText: crmT('crm.outlook_reply.body', 'Mesaj')),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              if (_body.text.trim().isEmpty) return;
              Navigator.pop(context, _Email(_subject.text.trim(), _body.text.trim()));
            },
            icon: const Icon(Icons.send),
            label: Text(crmT('crm.teams.send', 'Gönder')),
          ),
        ],
      ),
    );
  }
}

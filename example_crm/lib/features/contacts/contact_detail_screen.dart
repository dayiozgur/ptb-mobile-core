import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'contacts_service.dart';

/// CRM **Kişi detayı** — bilgi kartı + aktivite feed'i (`fn_crm_activity_feed`)
/// + "Aktivite logla" hızlı-aksiyonu (`fn_crm_log_activity`).
class ContactDetailScreen extends StatefulWidget {
  final String contactId;
  const ContactDetailScreen({super.key, required this.contactId});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _svc = ContactsService();
  bool _loading = true;
  Contact? _contact;
  List<CrmActivity> _feed = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await _svc.get(widget.contactId);
    final feed = await _svc.activityFeed(widget.contactId);
    if (mounted) {
      setState(() {
        _contact = c;
        _feed = feed;
        _loading = false;
      });
    }
  }

  Future<void> _logActivity() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LogActivitySheet(
        contactId: widget.contactId,
        contactName: _contact?.displayName,
      ),
    );
    if (ok == true) _load();
  }

  String _time(DateTime? d) {
    if (d == null) return '';
    final t = AppClock.toTenant(d);
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _contact;
    return AppScaffold(
      title: c?.displayName ?? 'Kişi',
      onBack: () => Navigator.of(context).pop(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logActivity,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Aktivite'),
      ),
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : c == null
              ? const Center(
                  child: AppEmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'Kişi bulunamadı'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: AppSpacing.screenPadding,
                    children: [
                      _infoCard(c),
                      const SizedBox(height: AppSpacing.md),
                      Text('Aktiviteler',
                          style: AppTypography.headline),
                      const SizedBox(height: AppSpacing.sm),
                      if (_feed.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Text('Henüz aktivite yok.',
                              style: AppTypography.footnote.copyWith(
                                  color:
                                      AppColors.secondaryLabel(context))),
                        )
                      else
                        ..._feed.map(_activityTile),
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard(Contact c) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.displayName, style: AppTypography.headline),
            if ((c.title ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(c.title!,
                  style: AppTypography.footnote.copyWith(
                      color: AppColors.secondaryLabel(context))),
            ],
            const SizedBox(height: AppSpacing.sm),
            if ((c.email ?? '').isNotEmpty)
              _row(Icons.email_outlined, c.email!),
            if ((c.phone ?? '').isNotEmpty)
              _row(Icons.phone_outlined, c.phone!),
            if ((c.notes ?? '').isNotEmpty)
              _row(Icons.notes_outlined, c.notes!),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.tertiaryLabel(context)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTypography.footnote)),
          ],
        ),
      );

  Widget _activityTile(CrmActivity a) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppBadge(
                        label: a.type ?? 'not',
                        variant: AppBadgeVariant.info,
                        size: AppBadgeSize.small),
                    const Spacer(),
                    Text(_time(a.occurredAt),
                        style: AppTypography.caption2.copyWith(
                            color: AppColors.tertiaryLabel(context))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(a.subject, style: AppTypography.subhead),
                if ((a.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(a.notes!,
                      style: AppTypography.footnote.copyWith(
                          color: AppColors.secondaryLabel(context))),
                ],
              ],
            ),
          ),
        ),
      );
}

/// "Aktivite logla" alt-sayfası.
class _LogActivitySheet extends StatefulWidget {
  final String contactId;
  final String? contactName;
  const _LogActivitySheet({required this.contactId, this.contactName});

  @override
  State<_LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends State<_LogActivitySheet> {
  final _svc = ContactsService();
  final _subject = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'call';
  bool _saving = false;

  static const _types = ['call', 'meeting', 'email', 'task', 'note'];

  @override
  void dispose() {
    _subject.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_subject.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final ok = await _svc.logActivity(
      subject: _subject.text,
      activityType: _type,
      notes: _notes.text,
      contactId: widget.contactId,
      contactName: widget.contactName,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aktivite kaydedilemedi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Aktivite Logla', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            children: _types
                .map((t) => ChoiceChip(
                      label: Text(t),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _subject,
              decoration: const InputDecoration(
                  labelText: 'Konu *',
                  isDense: true,
                  border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Notlar',
                  isDense: true,
                  border: OutlineInputBorder())),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../microsoft/ms_contact_actions.dart';
import 'contacts_service.dart';

/// Satır sonu hızlı-aksiyon (ara/mail): ikon + açılacak uri şeması.
class _ActionSpec {
  final IconData icon;
  final String uri;
  const _ActionSpec(this.icon, this.uri);
}

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

  Future<void> _editContact(Contact c) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditContactSheet(contact: c, service: _svc),
    );
    if (ok == true) _load();
  }

  String _time(DateTime? d) => d == null ? '' : AppClock.dateTime(d);

  @override
  Widget build(BuildContext context) {
    final c = _contact;
    return AppScaffold(
      title: c?.displayName ?? crmT('crm.contact.title', 'Kişi'),
      onBack: () => Navigator.of(context).pop(),
      actions: c == null
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: crmT('common.edit', 'Düzenle'),
                onPressed: () => _editContact(c),
              ),
              IconButton(
                icon: const Icon(Icons.cloud_outlined),
                tooltip: 'Microsoft',
                onPressed: () => showMsContactActions(
                  context,
                  contactId: widget.contactId,
                  contactName: c.displayName,
                  contactEmail: c.email,
                ),
              ),
            ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logActivity,
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(crmT('crm.contact.activity_fab', 'Aktivite')),
      ),
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : c == null
              ? Center(
                  child: AppEmptyState(
                      icon: Icons.person_off_outlined,
                      title: crmT('crm.contact.not_found', 'Kişi bulunamadı')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: AppSpacing.screenPadding,
                    children: [
                      _infoCard(c),
                      if ((c.companyId ?? '').isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _AccountDealsCard(companyId: c.companyId!),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(crmT('crm.contact.activities', 'Aktiviteler'),
                          style: AppTypography.headline),
                      const SizedBox(height: AppSpacing.sm),
                      if (_feed.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Text(
                              crmT('crm.contact.no_activities',
                                  'Henüz aktivite yok.'),
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
              _row(Icons.email_outlined, c.email!,
                  action: _ActionSpec(Icons.send_outlined, 'mailto:${c.email!.trim()}')),
            if ((c.phone ?? '').isNotEmpty)
              _row(Icons.phone_outlined, c.phone!,
                  action: _ActionSpec(Icons.call_outlined, 'tel:${c.phone!.trim()}')),
            if ((c.notes ?? '').isNotEmpty)
              _row(Icons.notes_outlined, c.notes!),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, {_ActionSpec? action}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.tertiaryLabel(context)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTypography.footnote)),
            if (action != null)
              IconButton(
                icon: Icon(action.icon, size: 18, color: AppColors.primary),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                tooltip: text,
                onPressed: () => _launch(action.uri),
              ),
          ],
        ),
      );

  Future<void> _launch(String uri) async {
    final ok = await UrlActions.openUri(uri); // çekirdek util
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(crmT('crm.contact.launch_failed', 'Uygulama açılamadı'))));
    }
  }

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

/// Firma 360 — kişinin firmasına ait açık fırsatlar (`fn_crm_account_360`).
/// Kendini çeker; boşsa gizlenir.
class _AccountDealsCard extends StatefulWidget {
  final String companyId;
  const _AccountDealsCard({required this.companyId});

  @override
  State<_AccountDealsCard> createState() => _AccountDealsCardState();
}

class _AccountDealsCardState extends State<_AccountDealsCard> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = AggregateService()
        .rows('fn_crm_account_360', params: {'p_company_id': widget.companyId});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final deals = snap.data ?? const [];
        if (deals.isEmpty) return const SizedBox.shrink();
        return AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.business_center_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                        crmT('crm.contact.account_open_deals',
                            'Firma Açık Fırsatları'),
                        style: AppTypography.subhead),
                    const Spacer(),
                    Text('${deals.length}',
                        style: AppTypography.caption1.copyWith(
                            color: AppColors.secondaryLabel(context))),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final d in deals) _dealRow(context, d),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dealRow(BuildContext context, Map<String, dynamic> d) {
    final amount = d['amount'];
    final amtStr = amount is num ? '₺${Formatters.number(amount)}' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(d['subject']?.toString() ?? '—',
                style: AppTypography.footnote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if ((d['status']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(width: 6),
            AppBadge(
                label: d['status'].toString(),
                variant: AppBadgeVariant.info,
                size: AppBadgeSize.small),
          ],
          if (amtStr.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(amtStr,
                style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryLabel(context))),
          ],
        ],
      ),
    );
  }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              crmT('crm.activity.save_failed', 'Aktivite kaydedilemedi.'))));
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
          Text(crmT('crm.activity.log_title', 'Aktivite Logla'),
              style: AppTypography.headline),
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
              decoration: InputDecoration(
                  labelText: crmT('crm.activity.subject', 'Konu *'),
                  isDense: true,
                  border: const OutlineInputBorder())),
          const SizedBox(height: AppSpacing.sm),
          TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                  labelText: crmT('crm.activity.notes', 'Notlar'),
                  isDense: true,
                  border: const OutlineInputBorder())),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(crmT('crm.common.save', 'Kaydet')),
          ),
        ],
      ),
    );
  }
}

/// Kişi düzenleme alt-sayfası — ad/soyad/e-posta/telefon/unvan/not güncelle.
/// Firma serbest-metin (contacts'ta company_id FK var, serbest kolon yok) →
/// mobil hızlı-düzenlemede firma alanı gösterilmez (create ile aynı sınır).
class _EditContactSheet extends StatefulWidget {
  final Contact contact;
  final ContactsService service;
  const _EditContactSheet({required this.contact, required this.service});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final _first = TextEditingController(text: widget.contact.firstName);
  late final _last = TextEditingController(text: widget.contact.lastName);
  late final _email = TextEditingController(text: widget.contact.email ?? '');
  late final _phone = TextEditingController(text: widget.contact.phone ?? '');
  late final _title = TextEditingController(text: widget.contact.title ?? '');
  late final _notes = TextEditingController(text: widget.contact.notes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final ok = await widget.service.update(
      widget.contact.id,
      firstName: _first.text,
      lastName: _last.text,
      email: _email.text,
      phone: _phone.text,
      title: _title.text,
      notes: _notes.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? crmT('crm.contact.saved', 'Kişi güncellendi')
          : crmT('crm.contact.save_failed', 'Güncelleme başarısız')),
      backgroundColor: ok ? null : Colors.red.shade700,
    ));
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(crmT('crm.contact.edit_title', 'Kişiyi düzenle'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: crmT('crm.contact.first_name', 'Ad'), controller: _first),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: crmT('crm.contact.last_name', 'Soyad'), controller: _last),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: crmT('crm.contact.email', 'E-posta'), controller: _email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: crmT('crm.contact.phone', 'Telefon'), controller: _phone, keyboardType: TextInputType.phone),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: crmT('crm.contact.title_field', 'Unvan'), controller: _title),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(label: crmT('crm.contact.notes', 'Notlar'), controller: _notes, maxLines: 3),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: crmT('common.save', 'Kaydet'),
              icon: Icons.check,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

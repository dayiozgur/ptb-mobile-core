import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import 'web_leads_service.dart';

/// CRM **Web Potansiyelleri** (`/crm/web-leads`) — web `WebLeadsComponent`
/// paritesi (telefon): Yeni / Dönüştürülen / Spam segmenti, kart başına
/// "Dönüştür" (`fn_crm_convert_web_lead`, web gibi onaysız → başarıda yeni
/// potansiyele gider), "Spam işaretle" (onaylı) ve "Yeniden aç".
/// Görüşme oluşturma (`fn_crm_web_lead_book_meeting`) mobilde YOK.
class WebLeadsScreen extends StatefulWidget {
  const WebLeadsScreen({super.key, this.service, this.onOpenLead});

  final WebLeadsService? service;

  /// Dönüşen/dönüştürülmüş başvurunun potansiyelini aç; varsayılan çekirdek
  /// `EntityDetailScreen('lead')`.
  final void Function(BuildContext context, String leadId)? onOpenLead;

  @override
  State<WebLeadsScreen> createState() => _WebLeadsScreenState();
}

class _WebLeadsScreenState extends State<WebLeadsScreen> {
  late final WebLeadsService _svc = widget.service ?? WebLeadsService();

  WebLeadFilter _filter = WebLeadFilter.newLeads;
  bool _loading = true;
  String? _error;
  bool _notAuthorized = false;
  String? _busyId;
  List<WebLead> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notAuthorized = false;
    });
    try {
      final rows = await _svc.list(_filter);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      WebLeadsService.log('list', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _notAuthorized = WebLeadsService.isNotAuthorized(e);
      });
    }
  }

  void _openLead(String leadId) {
    final hook = widget.onOpenLead;
    if (hook != null) return hook(context, leadId);
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EntityDetailScreen(typeCode: 'lead', id: leadId)));
  }

  Future<void> _convert(WebLead w) async {
    if (sl.isRegistered<ConnectivityService>() &&
        sl<ConnectivityService>().isOffline) {
      _toast(crmT('common.offline', 'Çevrimdışı'));
      return;
    }
    setState(() => _busyId = w.id);
    try {
      final leadId = await _svc.convert(w.id);
      if (!mounted) return;
      setState(() => _busyId = null);
      _toast(crmT('crm.web_leads.converted',
          'Web başvurusundan potansiyel oluşturuldu'));
      await _load();
      if (leadId != null && leadId.isNotEmpty && mounted) _openLead(leadId);
    } catch (e) {
      WebLeadsService.log('convert', e);
      if (!mounted) return;
      setState(() => _busyId = null);
      _toast(crmT('crm.web_leads.convert_error',
          'Bu potansiyel dönüştürülemedi'));
    }
  }

  Future<void> _markSpam(WebLead w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(crmT('crm.web_leads.mark_spam', 'Spam İşaretle')),
        content: Text(crmT('crm.web_leads.mark_spam_confirm',
            'Bu başvuru spam olarak işaretlensin mi?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: Text(crmT('crm.common.cancel', 'Vazgeç'))),
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(crmT('crm.web_leads.mark_spam', 'Spam İşaretle'))),
        ],
      ),
    );
    if (ok != true) return;
    await _setStatus(w, 'spam',
        crmT('crm.web_leads.marked_spam', 'Spam olarak işaretlendi'));
  }

  Future<void> _setStatus(WebLead w, String status, String okMsg) async {
    setState(() => _busyId = w.id);
    try {
      await _svc.setStatus(w.id, status);
      if (!mounted) return;
      setState(() => _busyId = null);
      _toast(okMsg);
      await _load();
    } catch (e) {
      WebLeadsService.log('setStatus', e);
      if (!mounted) return;
      setState(() => _busyId = null);
      _toast(crmT('crm.web_leads.action_error', 'İşlem başarısız'));
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.web_leads.title', 'Web Potansiyelleri'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: SegmentedButton<WebLeadFilter>(
              segments: [
                ButtonSegment(
                    value: WebLeadFilter.newLeads,
                    label: Text(crmT('crm.web_leads.f_new', 'Yeni'))),
                ButtonSegment(
                    value: WebLeadFilter.converted,
                    label: Text(
                        crmT('crm.web_leads.f_converted', 'Dönüştürülen'))),
                ButtonSegment(
                    value: WebLeadFilter.spam,
                    label: Text(crmT('crm.web_leads.f_spam', 'Spam'))),
              ],
              selected: {_filter},
              onSelectionChanged: (s) {
                if (s.first == _filter) return;
                setState(() => _filter = s.first);
                _load();
              },
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          icon: _notAuthorized ? Icons.lock_outline : Icons.error_outline,
          title: crmT('crm.web_leads.load_error',
              'Web potansiyelleri yüklenemedi.'),
          message: _notAuthorized
              ? crmT('crm.web_leads.admin_only',
                  'Bu liste yalnız yöneticilere açıktır.')
              : null,
          actionLabel: _notAuthorized ? null : crmT('common.retry', 'Yeniden dene'),
          onAction: _notAuthorized ? null : _load,
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            AppEmptyState(
              icon: Icons.inbox_outlined,
              title: crmT('crm.web_leads.empty',
                  'Bu görünümde web potansiyeli yok.'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _card(_rows[i]),
      ),
    );
  }

  Widget _card(WebLead w) {
    final busy = _busyId == w.id;
    final contact = [w.email, w.phone]
        .where((s) => (s ?? '').trim().isNotEmpty)
        .join(' · ');
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(w.displayName,
                    style: AppTypography.subhead,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              AppBadge(
                label: crmT('crm.web_leads.form_type.${w.formType}', w.formType),
                variant: w.formType == 'contact'
                    ? AppBadgeVariant.neutral
                    : AppBadgeVariant.info,
                size: AppBadgeSize.small,
              ),
            ]),
            if ((w.company ?? '').trim().isNotEmpty)
              Text(w.company!.trim(),
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context))),
            if (contact.isNotEmpty)
              Text(contact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption1),
            if ((w.message ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(w.message!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote),
              ),
            if (w.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(AppClock.dateTime(w.createdAt!),
                    style: AppTypography.caption2
                        .copyWith(color: AppColors.tertiaryLabel(context))),
              ),
            const SizedBox(height: AppSpacing.xs),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              _actions(w),
          ],
        ),
      ),
    );
  }

  Widget _actions(WebLead w) {
    switch (w.status) {
      case 'new':
        return Wrap(spacing: AppSpacing.sm, children: [
          FilledButton.icon(
            key: ValueKey('wl-convert-${w.id}'),
            onPressed: () => _convert(w),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(crmT('crm.web_leads.convert', 'Dönüştür')),
          ),
          OutlinedButton(
            onPressed: () => _markSpam(w),
            child: Text(crmT('crm.web_leads.mark_spam', 'Spam İşaretle')),
          ),
        ]);
      case 'converted':
        return Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: crmT('crm.web_leads.status_converted', 'Dönüştürüldü'),
                variant: AppBadgeVariant.success,
                size: AppBadgeSize.small,
              ),
              if ((w.convertedLeadId ?? '').isNotEmpty)
                TextButton(
                  onPressed: () => _openLead(w.convertedLeadId!),
                  child: Text(
                      crmT('crm.web_leads.detail.open_lead', 'Potansiyeli aç')),
                ),
            ]);
      default:
        return Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppBadge(
                label: crmT('crm.web_leads.status_spam', 'Spam'),
                variant: AppBadgeVariant.neutral,
                size: AppBadgeSize.small,
              ),
              TextButton(
                onPressed: () => _setStatus(w, 'new',
                    crmT('crm.web_leads.reopened', 'Yeniden açıldı')),
                child: Text(crmT('crm.web_leads.reopen', 'Yeniden Aç')),
              ),
            ]);
    }
  }
}

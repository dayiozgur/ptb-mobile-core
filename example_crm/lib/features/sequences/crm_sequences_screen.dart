import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import 'crm_sequences_service.dart';

/// CRM **Satış Dizileri** (`/crm/sequences`) — salt-okunur liste (ad, adım
/// sayısı, aktif kayıt, aktif/pasif) + dokununca kayıtlar alt-sayfası.
/// Düzenleme/oluşturma web'de kalır.
class CrmSequencesScreen extends StatefulWidget {
  const CrmSequencesScreen({super.key, this.service});

  final CrmSequencesService? service;

  @override
  State<CrmSequencesScreen> createState() => _CrmSequencesScreenState();
}

class _CrmSequencesScreenState extends State<CrmSequencesScreen> {
  late final CrmSequencesService _svc = widget.service ?? CrmSequencesService();

  bool _loading = true;
  String? _error;
  List<SequenceSummary> _rows = const [];

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
      final rows = await _svc.list();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      Logger.error('crm sequences load hata', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showEnrollments(SequenceSummary s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EnrollmentsSheet(service: _svc, sequence: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: crmT('crm.sequences.title', 'Satış Dizileri'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.error_outline,
          title: crmT('crm.sequences.load_error', 'Diziler yüklenemedi.'),
          actionLabel: crmT('common.retry', 'Yeniden dene'),
          onAction: _load,
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
              icon: Icons.repeat,
              title: crmT('crm.sequences.empty', 'Henüz dizi yok.'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _card(_rows[i]),
      ),
    );
  }

  Widget _card(SequenceSummary s) {
    final steps = '${crmT('crm.sequences.col_steps', 'Adım')}: ${s.stepCount}';
    final enrolled =
        '${crmT('crm.sequences.col_enrolled', 'Kayıtlı')}: ${s.activeEnrollments}';
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEnrollments(s),
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(s.name.isEmpty ? '—' : s.name,
                      style: AppTypography.subhead,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                AppBadge(
                  label: s.active
                      ? crmT('crm.sequences.active', 'Aktif')
                      : crmT('crm.sequences.inactive', 'Pasif'),
                  variant: s.active
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                  size: AppBadgeSize.small,
                ),
              ]),
              if ((s.description ?? '').trim().isNotEmpty)
                Text(s.description!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.secondaryLabel(context))),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$steps · $enrolled',
                    style: AppTypography.caption1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnrollmentsSheet extends StatefulWidget {
  const _EnrollmentsSheet({required this.service, required this.sequence});

  final CrmSequencesService service;
  final SequenceSummary sequence;

  @override
  State<_EnrollmentsSheet> createState() => _EnrollmentsSheetState();
}

class _EnrollmentsSheetState extends State<_EnrollmentsSheet> {
  late final Future<List<SequenceEnrollment>> _future =
      widget.service.enrollments(widget.sequence.id);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                  '${widget.sequence.name} — ${crmT('crm.sequences.enroll.view', 'Kayıtları görüntüle')}',
                  style: AppTypography.headline),
            ),
            Flexible(
              child: FutureBuilder<List<SequenceEnrollment>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: AppLoadingIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return AppEmptyState(
                      compact: true,
                      icon: Icons.error_outline,
                      title: crmT('crm.sequences.load_error',
                          'Diziler yüklenemedi.'),
                    );
                  }
                  final rows = snap.data ?? const <SequenceEnrollment>[];
                  if (rows.isEmpty) {
                    return AppEmptyState(
                      compact: true,
                      icon: Icons.person_off_outlined,
                      title: crmT('crm.sequences.enroll.none',
                          'Bu dizide kayıtlı kişi yok'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final e = rows[i];
                      final next = e.nextActionAt;
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                            e.contactName.isEmpty ? '—' : e.contactName),
                        subtitle: Text([
                          '${crmT('crm.sequences.enroll.step', 'Adım')}: ${e.currentStep}',
                          if (next != null)
                            '${crmT('crm.sequences.enroll.next', 'Sonraki aksiyon')}: ${AppClock.dateTime(next)}',
                        ].join(' · ')),
                        trailing: e.status.isEmpty
                            ? null
                            : AppBadge(
                                label: EntityStatusLabels.humanize(e.status),
                                variant: e.status == 'active'
                                    ? AppBadgeVariant.primary
                                    : AppBadgeVariant.neutral,
                                size: AppBadgeSize.small,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

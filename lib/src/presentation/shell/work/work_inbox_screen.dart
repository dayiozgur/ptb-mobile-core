import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// **Generic "Bana atanan iş" ekranı** — bir [WorkInboxSource]'un RPC'sini
/// yükler, gruplara (ör. gecikmiş/bugün/durgun) ayırıp listeler; bir öğeye
/// dokununca `/entities/<type>/<id>` detayına gider.
///
/// Platform-nötr: CRM `fn_crm_my_work`, PPM `fn_ppm_my_work` gibi kaynakları
/// aynı ekranla render eder (çekirdek yeniden-kullanım).
class WorkInboxScreen extends StatefulWidget {
  final WorkInboxSource source;

  const WorkInboxScreen({super.key, required this.source});

  @override
  State<WorkInboxScreen> createState() => _WorkInboxScreenState();
}

class _WorkInboxScreenState extends State<WorkInboxScreen> {
  bool _loading = true;
  List<WorkInboxItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await sl<WorkInboxService>().load(widget.source);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  /// group → sıralı öğe listesi (group null ise tek grup).
  Map<String, List<WorkInboxItem>> get _grouped {
    final out = <String, List<WorkInboxItem>>{};
    for (final it in _items) {
      out.putIfAbsent(it.group ?? '', () => []).add(it);
    }
    return out;
  }

  void _open(WorkInboxItem it) {
    final type = it.entityType;
    if (type != null && type.isNotEmpty) {
      context.push('/entities/$type/${it.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.source.title,
      onBack: () => context.pop(),
      actions: [AppIconButton(icon: Icons.refresh, onPressed: _load)],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(
            child: AppEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Atanmış iş yok',
            ),
          ),
        ],
      );
    }
    final groups = _grouped;
    final children = <Widget>[];
    groups.forEach((group, items) {
      if (group.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: Text(_groupLabel(group),
              style: AppTypography.withColor(AppTypography.footnote,
                  AppColors.secondaryLabel(context))),
        ));
      }
      for (final it in items) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: _tile(context, it),
        ));
      }
    });
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: children,
    );
  }

  String _groupLabel(String g) {
    switch (g) {
      case 'overdue':
        return 'GECİKMİŞ';
      case 'today':
        return 'BUGÜN';
      case 'stale':
        return 'DURGUN';
      case 'upcoming':
        return 'YAKLAŞAN';
      default:
        return g.toUpperCase();
    }
  }

  Widget _tile(BuildContext context, WorkInboxItem it) {
    final b = Theme.of(context).brightness;
    return AppCard(
      child: InkWell(
        onTap: () => _open(it),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.withColor(
                            AppTypography.subhead, AppColors.textPrimary(b))),
                    if (it.subtitle != null && it.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(it.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.withColor(AppTypography.caption1,
                              AppColors.textSecondary(b))),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (it.status != null && it.status!.isNotEmpty)
                    AppBadge(
                      label: it.status ?? '',
                      variant: AppBadgeVariant.neutral,
                      size: AppBadgeSize.small,
                    ),
                  if (it.trailing != null && it.trailing!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(it.trailing!,
                        style: AppTypography.withColor(AppTypography.caption1,
                            AppColors.tertiaryLabel(context))),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

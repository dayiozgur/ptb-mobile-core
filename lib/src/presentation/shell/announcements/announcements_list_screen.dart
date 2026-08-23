import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// **Duyurular** — yayınlanmış duyuru listesi (yeni → eski). Bir öğeye
/// dokununca [AnnouncementDetailScreen] açılır. Salt-okuma.
class AnnouncementsListScreen extends StatefulWidget {
  const AnnouncementsListScreen({super.key});

  @override
  State<AnnouncementsListScreen> createState() =>
      _AnnouncementsListScreenState();
}

class _AnnouncementsListScreenState extends State<AnnouncementsListScreen> {
  final _ctrl = AsyncViewController();

  void _open(Announcement a) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AnnouncementDetailScreen(id: a.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Duyurular',
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<Announcement>>(
        controller: _ctrl,
        load: () => announcementService.list(),
        errorFallback: 'Duyurular yüklenemedi',
        isEmpty: (d) => d.isEmpty,
        emptyBuilder: (context) => const Center(
          child: AppEmptyState(
            icon: Icons.campaign_outlined,
            title: 'Duyuru yok',
            message: 'Görüntülenecek yayınlanmış duyuru bulunmuyor.',
          ),
        ),
        builder: (context, items) => ListView.separated(
          padding: AppSpacing.screenPadding,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _AnnouncementCard(
            announcement: items[i],
            onTap: () => _open(items[i]),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onTap;

  const _AnnouncementCard({required this.announcement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final category = a.category;
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((a.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      a.body!,
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.secondaryLabel(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (category != null && category.isNotEmpty) ...[
                        AppBadge(
                          label: category,
                          variant: AppBadgeVariant.info,
                          size: AppBadgeSize.small,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        _fmtDate(a.publishDate),
                        style: AppTypography.caption1.copyWith(
                            color: AppColors.tertiaryLabel(context)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.tertiaryLabel(context)),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year}';
  }
}

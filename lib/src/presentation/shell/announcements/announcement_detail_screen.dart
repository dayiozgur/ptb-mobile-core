import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// **Duyuru detayı** — tekil duyurunun tam görünümü: hero görsel (varsa),
/// kategori + tarih, başlık ve tam gövde. Salt-okuma (yazma web admin'de).
class AnnouncementDetailScreen extends StatefulWidget {
  final String id;

  const AnnouncementDetailScreen({super.key, required this.id});

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AppScaffold(
      title: 'Duyuru',
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<Announcement>(
        controller: _ctrl,
        load: () async {
          final a = await announcementService.getById(widget.id);
          if (a == null) throw Exception('Duyuru bulunamadı');
          return a;
        },
        errorFallback: 'Duyuru yüklenemedi',
        builder: (context, a) => _content(context, a, brightness),
      ),
    );
  }

  Widget _content(BuildContext context, Announcement a, Brightness brightness) {
    final imageUrl = a.imageUrl;
    final category = a.category;
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.startsWith('http')) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
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
              Icon(Icons.schedule,
                  size: 14, color: AppColors.tertiaryLabel(context)),
              const SizedBox(width: 4),
              Text(
                _fmtDate(a.publishDate),
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            a.title,
            style: AppTypography.title2.copyWith(
              color: AppColors.textPrimary(brightness),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if ((a.body ?? '').isNotEmpty)
            Text(
              a.body!,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary(brightness),
                height: 1.5,
              ),
            ),
        ],
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

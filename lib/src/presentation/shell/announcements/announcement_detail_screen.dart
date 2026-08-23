import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
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
          if ((imageUrl ?? '').isNotEmpty) ...[
            // Tenant-izolasyonlu: image_url PATH → imzalı-URL (eski http public
            // kayıtlar doğrudan). FutureBuilder ile çöz.
            FutureBuilder<String?>(
              future: announcementService.imageUrlFor(imageUrl),
              builder: (context, snap) {
                final url = snap.data;
                if (url == null || url.isEmpty) return const SizedBox.shrink();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: AppColors.systemGray6,
                    ),
                  ),
                );
              },
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
            // Web rich-editor sanitize'lı HTML üretir → HtmlWidget render eder
            // (biçimlendirme + satır-içi <img> public CDN'den). Düz-metin de sorunsuz.
            HtmlWidget(
              a.body!,
              textStyle: AppTypography.body.copyWith(
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

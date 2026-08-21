import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Oryantasyon / işten-çıkış süreç örneği kartı (salt-okuma).
///
/// Hem `AdminOnboardingScreen` hem `AdminOffboardingScreen` tarafından
/// paylaşılır — aynı `staff_onboarding_*` şeması `type` ile ayrıldığından
/// görsel gösterim de ortaktır. Personel + şablon + durum rozeti + ilerleme
/// (x/y bar) + başlangıç tarihini gösterir.
class AdminOnboardingInstanceCard extends StatelessWidget {
  final OnboardingInstanceRow row;

  const AdminOnboardingInstanceCard({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final staff = row.staffName?.trim().isNotEmpty == true
        ? row.staffName!
        : '—';
    final template = row.templateName?.trim();

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: staff),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        staff,
                        style: AppTypography.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (template != null && template.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          template,
                          style: AppTypography.caption1.copyWith(
                            color: AppColors.secondaryLabel(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: essStatusLabel(row.status),
                  variant: essStatusVariant(row.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  essDate(row.startedAt),
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.tertiaryLabel(context)),
                ),
                const Spacer(),
                Text(
                  '${row.doneCount} / ${row.totalCount}',
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
            if (row.totalCount > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: row.ratio,
                  minHeight: 6,
                  backgroundColor: AppColors.separator(context),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

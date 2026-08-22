import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "Resmi Tatiller" — salt-okuma liste (tarihe göre sıralı).
///
/// Veri `AdminLeaveService.holidays()` (web `LeaveService.listHolidays` aynası):
/// tenant-kapsamlı, `holiday_date` artan. Her satır tatil adı + tarih + (varsa)
/// "her yıl tekrarlar" rozeti gösterir.
class AdminHolidaysScreen extends StatefulWidget {
  const AdminHolidaysScreen({super.key});

  @override
  State<AdminHolidaysScreen> createState() => _AdminHolidaysScreenState();
}

class _AdminHolidaysScreenState extends State<AdminHolidaysScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.leave.holidays_title', 'Resmi Tatiller'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<HolidayRow>>(
        controller: _ctrl,
        load: () => adminLeaveService.holidays(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.celebration_outlined,
        emptyTitle: essT('hr.leave.no_holidays', 'Tatil kaydı yok'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<HolidayRow> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _HolidayCard(row: d[i]),
    );
  }
}

class _HolidayCard extends StatelessWidget {
  final HolidayRow row;

  const _HolidayCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final name = (row.name?.trim().isNotEmpty ?? false) ? row.name! : '-';

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event, color: AppColors.warning),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    essDate(row.holidayDate),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.secondaryLabel(context)),
                  ),
                ],
              ),
            ),
            if (row.isRecurring) ...[
              const SizedBox(width: AppSpacing.sm),
              AppBadge(
                label: essT('hr.leave.recurring', 'Her yıl'),
                variant: AppBadgeVariant.info,
                size: AppBadgeSize.small,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_attendance_common.dart';

/// Vardiyalar — `/admin/pdks/shifts`. İki sekme (salt-okuma): **Tanımlar**
/// (`work_shifts`) ve **Atamalar** (`staff_shifts`). Web `ShiftManagementComponent`
/// aynası.
class AdminPdksShiftsScreen extends StatefulWidget {
  const AdminPdksShiftsScreen({super.key});

  @override
  State<AdminPdksShiftsScreen> createState() => _AdminPdksShiftsScreenState();
}

class _AdminPdksShiftsScreenState extends State<AdminPdksShiftsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _tabIndex = 0; // 0 = Tanımlar, 1 = Atamalar

  List<WorkShiftRow> _shifts = [];
  List<StaffShiftRow> _assignments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final shifts = await adminAttendanceService.listShifts();
      final assignments = await adminAttendanceService.listShiftAssignments();
      if (mounted) {
        setState(() {
          _shifts = shifts;
          _assignments = assignments;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load shifts', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.pdks.shifts_title', 'Vardiyalar'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: AppSegmentedControl(
              segments: [
                essT('hr.pdks.shift_defs', 'Tanımlar'),
                essT('hr.pdks.shift_assignments', 'Atamalar'),
              ],
              selectedIndex: _tabIndex,
              onSegmentChanged: (i) => setState(() => _tabIndex = i),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }
    return _tabIndex == 0 ? _buildDefs() : _buildAssignments();
  }

  Widget _buildDefs() {
    if (_shifts.isEmpty) {
      return pdksEmptyScroll(
        icon: Icons.schedule_outlined,
        title: essT('hr.pdks.no_shifts', 'Vardiya tanımı yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ShiftCard(shift: _shifts[i]),
    );
  }

  Widget _buildAssignments() {
    if (_assignments.isEmpty) {
      return pdksEmptyScroll(
        icon: Icons.assignment_ind_outlined,
        title: essT('hr.pdks.no_assignments', 'Vardiya ataması yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _assignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _AssignmentCard(assignment: _assignments[i]),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final WorkShiftRow shift;

  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final days = shift.daysOfWeek.map(pdksDowShort).join(' · ');
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shift.name,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!shift.active)
                  AppBadge(
                    label: essT('common.passive', 'Pasif'),
                    variant: AppBadgeVariant.neutral,
                    size: AppBadgeSize.small,
                  )
                else if (shift.code != null && shift.code!.isNotEmpty)
                  AppBadge(
                    label: shift.code!,
                    variant: AppBadgeVariant.secondary,
                    size: AppBadgeSize.small,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  '${shift.startTime.isEmpty ? '--:--' : shift.startTime}'
                  ' → '
                  '${shift.endTime.isEmpty ? '--:--' : shift.endTime}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (shift.breakMinutes > 0) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.free_breakfast_outlined,
                      size: 13, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 3),
                  Text(
                    essDuration(shift.breakMinutes),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.secondaryLabel(context)),
                  ),
                ],
              ],
            ),
            if (days.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(Icons.event_repeat,
                      size: 13, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      days,
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.secondaryLabel(context)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final StaffShiftRow assignment;

  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            AppAvatar(name: assignment.staffName, size: AppAvatarSize.small),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    assignment.staffName,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 13, color: AppColors.tertiaryLabel(context)),
                      const SizedBox(width: 4),
                      Text(
                        assignment.shiftName,
                        style: AppTypography.caption1.copyWith(
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              essDateRange(assignment.effectiveFrom, assignment.effectiveTo),
              style: AppTypography.caption2
                  .copyWith(color: AppColors.tertiaryLabel(context)),
            ),
          ],
        ),
      ),
    );
  }
}

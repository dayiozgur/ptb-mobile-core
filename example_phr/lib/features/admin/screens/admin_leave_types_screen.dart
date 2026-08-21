import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// Admin "İzin Türleri" — salt-okuma liste.
///
/// Veri `AdminLeaveService.leaveTypes()` (web `LeaveService.listTypes` aynası):
/// tenant'a özel + global (`tenant_id is null`) ortak türler, ada göre sıralı.
class AdminLeaveTypesScreen extends StatefulWidget {
  const AdminLeaveTypesScreen({super.key});

  @override
  State<AdminLeaveTypesScreen> createState() => _AdminLeaveTypesScreenState();
}

class _AdminLeaveTypesScreenState extends State<AdminLeaveTypesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<LeaveTypeRow> _rows = [];

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
      final rows = await adminLeaveService.leaveTypes();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load leave types', e);
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
      title: essT('hr.leave.types_title', 'İzin Türleri'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(),
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
    if (_rows.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.category_outlined,
                title: essT('hr.leave.no_types', 'İzin türü yok'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _LeaveTypeCard(row: _rows[i]),
    );
  }
}

class _LeaveTypeCard extends StatelessWidget {
  final LeaveTypeRow row;

  const _LeaveTypeCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final name = (row.name?.trim().isNotEmpty ?? false) ? row.name! : '-';
    final subtitle = <String>[
      if (row.code?.trim().isNotEmpty ?? false) row.code!.trim(),
      if (row.defaultDays > 0)
        '${_dayText(row.defaultDays)} ${essT('hr.leave.days', 'gün')}',
    ].join(' · ');

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.event_available, color: AppColors.primary),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.secondaryLabel(context)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBadge(
                  label: row.isPaid
                      ? essT('hr.leave.paid', 'Ücretli')
                      : essT('hr.leave.unpaid', 'Ücretsiz'),
                  variant: row.isPaid
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                  size: AppBadgeSize.small,
                ),
                if (!row.active) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  AppBadge(
                    label: essT('common.inactive', 'Pasif'),
                    variant: AppBadgeVariant.error,
                    size: AppBadgeSize.small,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dayText(num d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

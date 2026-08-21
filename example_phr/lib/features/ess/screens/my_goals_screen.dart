import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın kendi performans hedefleri (salt-okuma v1).
///
/// `/hr/performance/my-goals` → her satır başlık + durum rozeti + ilerleme
/// çubuğu gösterir; dokununca detay alt-sayfası (bottom-sheet) açılır.
/// Veri kaynağı: `HrEssService.myGoals()` (web `PerformanceService.getMyGoals`
/// ile birebir sözleşme; `employee_goals`, `staff_id`=ben).
class MyGoalsScreen extends StatefulWidget {
  const MyGoalsScreen({super.key});

  @override
  State<MyGoalsScreen> createState() => _MyGoalsScreenState();
}

class _MyGoalsScreenState extends State<MyGoalsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<EmployeeGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await hrEssService.myGoals();
      if (mounted) {
        setState(() {
          _goals = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load goals', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  void _openDetail(EmployeeGoal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _GoalDetailSheet(goal: goal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.performance.my_goals', 'Hedeflerim'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _loadData),
      ],
      child: RefreshIndicator(
        onRefresh: _loadData,
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
        child: AppErrorView(message: _errorMessage!, onRetry: _loadData),
      );
    }
    if (_goals.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.flag_outlined,
                title: essT('hr.performance.no_goals', 'Hedef bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _goals.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _GoalCard(
        goal: _goals[i],
        onTap: () => _openDetail(_goals[i]),
      ),
    );
  }
}

/// Hedef durum kodu → Türkçe etiket.
String _goalStatusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'done':
      return essT('performance.goal_status.done', 'Tamamlandı');
    case 'cancelled':
    case 'canceled':
      return essT('performance.goal_status.cancelled', 'İptal edildi');
    case 'active':
      return essT('performance.goal_status.active', 'Devam ediyor');
    default:
      return essStatusLabel(status);
  }
}

class _GoalCard extends StatelessWidget {
  final EmployeeGoal goal;
  final VoidCallback onTap;

  const _GoalCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress.clamp(0, 100);
    final ratio = progress / 100.0;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title.isNotEmpty
                        ? goal.title
                        : essT('hr.performance.untitled_goal', 'Başlıksız hedef'),
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _goalStatusLabel(goal.status),
                  variant: essStatusVariant(goal.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            if (goal.cycleName != null && goal.cycleName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                goal.cycleName!,
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      backgroundColor: AppColors.separator(context),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$progress%',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalDetailSheet extends StatelessWidget {
  final EmployeeGoal goal;

  const _GoalDetailSheet({required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress.clamp(0, 100);
    final weightStr = goal.weight == goal.weight.roundToDouble()
        ? goal.weight.toInt().toString()
        : goal.weight.toString();

    return SafeArea(
      top: false,
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.separator(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title.isNotEmpty
                        ? goal.title
                        : essT('hr.performance.untitled_goal', 'Başlıksız hedef'),
                    style: AppTypography.title3,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _goalStatusLabel(goal.status),
                  variant: essStatusVariant(goal.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              label: essT('performance.review.cycle', 'Dönem'),
              value: goal.cycleName ?? '-',
            ),
            _DetailRow(
              label: essT('performance.goal.col_weight', 'Ağırlık'),
              value: '$weightStr%',
            ),
            _DetailRow(
              label: essT('performance.goal.col_progress', 'İlerleme'),
              value: '$progress%',
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / 100.0,
                minHeight: 8,
                backgroundColor: AppColors.separator(context),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            if (goal.description != null && goal.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                essT('performance.goal.description', 'Açıklama'),
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(goal.description!, style: AppTypography.body),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: AppTypography.footnote.copyWith(
                color: AppColors.primaryLabel(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

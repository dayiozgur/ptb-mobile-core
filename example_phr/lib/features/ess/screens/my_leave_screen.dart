import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';
import 'my_leave_form_screen.dart';

/// Çalışan izin ekranı — iki bölüm: **Bakiye** ve **Taleplerim**.
///
/// `/hr/leave/my-balance` → [initialTab]=0 (Bakiye),
/// `/hr/leave/my-requests` → [initialTab]=1 (Taleplerim).
class MyLeaveScreen extends StatefulWidget {
  final int initialTab;

  const MyLeaveScreen({super.key, this.initialTab = 0});

  @override
  State<MyLeaveScreen> createState() => _MyLeaveScreenState();
}

class _MyLeaveScreenState extends State<MyLeaveScreen> {
  late int _tab;

  bool _isLoading = true;
  String? _errorMessage;
  List<LeaveBalance> _balances = [];
  List<LeaveRequestRow> _requests = [];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == 1 ? 1 : 0;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        hrEssService.leaveBalance(),
        hrEssService.myLeaveRequests(),
      ]);
      if (mounted) {
        setState(() {
          _balances = results[0] as List<LeaveBalance>;
          _requests = results[1] as List<LeaveRequestRow>;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load leave data', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MyLeaveFormScreen(balances: _balances),
      ),
    );
    if (created == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.leave.title', 'İzinlerim'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _loadData),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: Text(essT('hr.leave.new_request', 'Yeni izin talebi')),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: AppTabBar(
              tabs: [
                essT('hr.leave.tab_balance', 'Bakiye'),
                essT('hr.leave.tab_requests', 'Taleplerim'),
              ],
              selectedIndex: _tab,
              onTabChanged: (i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
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
        child: AppErrorView(message: _errorMessage!, onRetry: _loadData),
      );
    }
    return _tab == 0 ? _buildBalance() : _buildRequests();
  }

  Widget _buildBalance() {
    if (_balances.isEmpty) {
      return _emptyScroll(
        icon: Icons.beach_access_outlined,
        title: essT('hr.leave.no_balance', 'İzin bakiyesi bulunamadı'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _balances.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _BalanceCard(balance: _balances[i]),
    );
  }

  Widget _buildRequests() {
    if (_requests.isEmpty) {
      return _emptyScroll(
        icon: Icons.event_busy_outlined,
        title: essT('hr.leave.no_requests', 'İzin talebiniz yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RequestCard(request: _requests[i]),
    );
  }

  Widget _emptyScroll({required IconData icon, required String title}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: AppEmptyState(icon: icon, title: title),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final LeaveBalance balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final entitled = balance.entitled;
    final remaining = balance.remaining;
    final used = balance.used;
    final ratio = entitled > 0
        ? (remaining / entitled).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final name = balance.leaveTypeName ??
        essT('hr.leave.leave_type', 'İzin türü');

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: AppTypography.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: balance.isPaid
                      ? essT('hr.leave.paid', 'Ücretli')
                      : essT('hr.leave.unpaid', 'Ücretsiz'),
                  variant: balance.isPaid
                      ? AppBadgeVariant.success
                      : AppBadgeVariant.neutral,
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _fmtNum(remaining),
                  style: AppTypography.title1.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/ ${_fmtNum(entitled)} ${essT('hr.leave.days', 'gün')}',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${essT('hr.leave.used', 'Kullanılan')}: ${_fmtNum(used)}',
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.separator(context),
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            if (balance.pending > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${essT('hr.leave.pending_days', 'Bekleyen')}: ${_fmtNum(balance.pending)} ${essT('hr.leave.days', 'gün')}',
                style: AppTypography.caption2
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _RequestCard extends StatelessWidget {
  final LeaveRequestRow request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final name = request.leaveTypeName ??
        essT('hr.leave.leave_type', 'İzin türü');
    final dc = request.dayCount;
    final dcStr = dc == dc.roundToDouble() ? dc.toInt().toString() : '$dc';

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: AppTypography.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: essStatusLabel(request.status),
                  variant: essStatusVariant(request.status),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.date_range,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    essDateRange(request.startDate, request.endDate),
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                  ),
                ),
                Text(
                  '$dcStr ${essT('hr.leave.days', 'gün')}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (request.note != null && request.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                request.note!,
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (request.decisionNote != null &&
                request.decisionNote!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${essT('hr.leave.decision_note', 'Karar notu')}: ${request.decisionNote!}',
                style: AppTypography.caption2
                    .copyWith(color: AppColors.tertiaryLabel(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

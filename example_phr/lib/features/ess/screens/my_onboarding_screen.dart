import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın oryantasyon (onboarding) görev listesi — kontrol listesi.
///
/// Her satır: başlık, durum rozeti, son tarih; gecikmiş görevler kırmızı.
class MyOnboardingScreen extends StatefulWidget {
  const MyOnboardingScreen({super.key});

  @override
  State<MyOnboardingScreen> createState() => _MyOnboardingScreenState();
}

class _MyOnboardingScreenState extends State<MyOnboardingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<OnboardingTask> _tasks = [];

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
      final rows = await hrEssService.myOnboardingTasks();
      if (mounted) {
        setState(() {
          _tasks = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load onboarding tasks', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  /// Tam-ekran spinner tetiklemeden listeyi yeniler (satır-içi aksiyon sonrası).
  Future<void> _reloadQuiet() async {
    try {
      final rows = await hrEssService.myOnboardingTasks();
      if (mounted) setState(() => _tasks = rows);
    } catch (e) {
      Logger.error('Failed to reload onboarding tasks', e);
    }
  }

  /// Görev durumunu değiştirir (Tamamla / geri al) → backend + sessiz yenile.
  ///
  /// Kartın kendi spinner'ını yönetebilmesi için Future döner ve hata olursa
  /// SnackBar gösterip yeniden fırlatır.
  Future<void> _setStatus(OnboardingTask task, bool done) async {
    final taskId = task.taskId;
    if (taskId == null) return;
    try {
      await hrEssService.completeOnboardingTask(taskId, done: done);
      await _reloadQuiet();
    } catch (e) {
      Logger.error('Failed to update onboarding task', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(essT('common.action_error', 'İşlem başarısız')),
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.onboarding.title', 'Oryantasyonum'),
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
    if (_tasks.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.checklist_rtl,
                title: essT('hr.onboarding.no_tasks', 'Oryantasyon görevi yok'),
              ),
            ),
          ),
        ),
      );
    }

    final done = _tasks
        .where((t) => t.status?.toLowerCase() == 'completed' ||
            t.status?.toLowerCase() == 'done')
        .length;

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _tasks.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ProgressHeader(done: done, total: _tasks.length);
        }
        final task = _tasks[index - 1];
        return _TaskCard(
          task: task,
          onToggle: (nextDone) => _setStatus(task, nextDone),
        );
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int done;
  final int total;

  const _ProgressHeader({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (done / total).clamp(0.0, 1.0).toDouble() : 0.0;
    return AppCard(
      variant: AppCardVariant.filled,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  essT('hr.onboarding.progress', 'İlerleme'),
                  style: AppTypography.subhead
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const Spacer(),
                Text('$done / $total',
                    style: AppTypography.headline
                        .copyWith(color: AppColors.primary)),
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
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  final OnboardingTask task;

  /// Görev durumunu değiştir: `true` → Tamamla ('done'), `false` → geri al
  /// ('pending'). Backend çağrısı + yenileme tamamlanınca Future çözülür.
  final Future<void> Function(bool done) onToggle;

  const _TaskCard({required this.task, required this.onToggle});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _busy = false;

  OnboardingTask get task => widget.task;

  bool get _isDone =>
      task.status?.toLowerCase() == 'completed' ||
      task.status?.toLowerCase() == 'done';

  bool get _actionable => task.taskId != null && !_busy;

  Future<void> _handle(bool done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onToggle(done);
    } catch (_) {
      // Hata SnackBar'ı üst ekranda gösterildi; burada yut, spinner'ı kapat.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _actionable ? () => _handle(!_isDone) : null,
              behavior: HitTestBehavior.opaque,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      _isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _isDone
                          ? AppColors.success
                          : AppColors.tertiaryLabel(context),
                      size: 22,
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title ??
                              essT('hr.onboarding.task', 'Görev'),
                          style: AppTypography.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppBadge(
                        label: essStatusLabel(task.status),
                        variant: essStatusVariant(task.status),
                        size: AppBadgeSize.small,
                      ),
                    ],
                  ),
                  if (task.templateName != null &&
                      task.templateName!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      task.templateName!,
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context)),
                    ),
                  ],
                  if (task.dueDate != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: task.overdue && !_isDone
                              ? AppColors.error
                              : AppColors.tertiaryLabel(context),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${essT('hr.onboarding.due', 'Son tarih')}: ${essDate(task.dueDate)}',
                          style: AppTypography.caption1.copyWith(
                            color: task.overdue && !_isDone
                                ? AppColors.error
                                : AppColors.tertiaryLabel(context),
                            fontWeight: task.overdue && !_isDone
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (task.overdue && !_isDone) ...[
                          const SizedBox(width: 6),
                          Text(
                            essT('hr.onboarding.overdue', 'Gecikmiş'),
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (task.notes != null && task.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      task.notes!,
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.secondaryLabel(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (task.taskId != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: _isDone
                            ? essT('common.completed', 'Tamamlandı')
                            : essT('hr.onboarding.complete', 'Tamamla'),
                        icon: _isDone ? Icons.check : Icons.done_all,
                        variant: _isDone
                            ? AppButtonVariant.success
                            : AppButtonVariant.primary,
                        size: AppButtonSize.small,
                        isFullWidth: false,
                        isLoading: _busy,
                        onPressed: () => _handle(!_isDone),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

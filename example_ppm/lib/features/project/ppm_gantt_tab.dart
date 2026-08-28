import 'dart:math' as math;

import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ppm_common.dart';
import 'gantt_geometry.dart';

/// **PPM Gantt / Zaman Çizelgesi** — projenin task'larını basit bir zaman
/// çizelgesinde gösterir. task'ta yalnız `due_date` olduğundan bar
/// `created_at → due_date` aralığıdır (created_at yoksa/bitişten sonraysa
/// bitiş-3gün başlangıç varsayılır). Salt-okuma, mobil-uyumlu.
class PpmGanttTab extends StatefulWidget {
  final String projectId;
  const PpmGanttTab({super.key, required this.projectId});

  @override
  State<PpmGanttTab> createState() => _PpmGanttTabState();
}

class _PpmGanttTabState extends State<PpmGanttTab> {
  final _ctrl = AsyncViewController();

  Future<List<GenericEntity>> _load() async {
    final cfg = await sl<EntityConfigService>().getByCode('task');
    if (cfg == null) return const [];
    final tid = sl<TenantService>().currentTenantId;
    final ds = sl<EntityDataService>();
    if (tid != null) ds.setTenant(tid);
    final tasks =
        await ds.listEntities(cfg, ancestorId: widget.projectId, limit: 200);
    final withDue = tasks.where((t) => t.dueDate != null).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    return withDue;
  }

  DateTime _start(GenericEntity t) =>
      GanttGeometry.startOf(t.dueDate!, t.createdAt);

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<GenericEntity>>(
      controller: _ctrl,
      load: _load,
      errorFallback: ppmT('ppm.gantt.load_error', 'Zaman çizelgesi yüklenemedi'),
      isEmpty: (d) => d.isEmpty,
      emptyBuilder: (context) => Center(
        child: AppEmptyState(
          icon: Icons.timeline_outlined,
          title: ppmT('ppm.gantt.empty_title', 'Zaman çizelgesi yok'),
          message: ppmT(
              'ppm.gantt.empty_msg', 'Bitiş tarihi olan görev bulunmuyor.'),
        ),
      ),
      builder: (context, tasks) => _gantt(context, tasks),
    );
  }

  Widget _gantt(BuildContext context, List<GenericEntity> tasks) {
    final minD = tasks.map(_start).reduce((a, b) => a.isBefore(b) ? a : b);
    final maxD =
        tasks.map((t) => t.dueDate!).reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = math.max(1, maxD.difference(minD).inDays);
    final brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarih aralığı başlığı.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(minD),
                  style: AppTypography.caption1.copyWith(
                      color: AppColors.textSecondary(brightness))),
              Text('${tasks.length} ${ppmT('ppm.gantt.tasks_unit', 'görev')}',
                  style: AppTypography.caption1.copyWith(
                      color: AppColors.textSecondary(brightness))),
              Text(_fmt(maxD),
                  style: AppTypography.caption1.copyWith(
                      color: AppColors.textSecondary(brightness))),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: tasks.length,
            itemBuilder: (_, i) =>
                _row(context, tasks[i], minD, totalDays, brightness),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, GenericEntity t, DateTime minD,
      int totalDays, Brightness brightness) {
    final s = _start(t);
    final e = t.dueDate!;
    final geo = GanttGeometry.bar(s, e, minD, totalDays);
    final leftFrac = geo.left;
    final widthFrac = geo.width;
    final barColor = _statusColor(t.status);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              t.displayTitle,
              style: AppTypography.caption1
                  .copyWith(color: AppColors.textPrimary(brightness)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(
              height: 22,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.systemGray.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: leftFrac * w,
                        width: math.max(6, widthFrac * w),
                        top: 3,
                        bottom: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _fmtShort(e),
                            style: AppTypography.caption2
                                .copyWith(color: Colors.white),
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (GanttGeometry.classifyStatus(status)) {
      case GanttStatusKind.done:
        return AppColors.success;
      case GanttStatusKind.inProgress:
        return AppColors.primary;
      case GanttStatusKind.blocked:
        return AppColors.error;
      case GanttStatusKind.neutral:
        return AppColors.systemGray;
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

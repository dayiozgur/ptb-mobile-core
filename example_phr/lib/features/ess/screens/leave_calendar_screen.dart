import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// İzin Takvimi — `/hr/leave/calendar`.
///
/// Ay ızgarası (7 sütun) üzerinde izinli günleri renkli noktayla gösterir;
/// altında o ayın izin listesi yer alır. Kapsam RLS ile belirlenir: çalışan
/// kendi + astlarını, yönetici ekibini, admin tüm tenant'ı görür (web
/// `getTeamRequests` ile aynı sözleşme). Harici takvim paketi yok — ızgara
/// `DateTime` matematiğiyle elle kurulur.
class LeaveCalendarScreen extends StatefulWidget {
  const LeaveCalendarScreen({super.key});

  @override
  State<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

// İzin türü id'sine göre kararlı (deterministik) renk paleti.
const List<Color> _typePalette = [
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFD97706),
  Color(0xFFDB2777),
  Color(0xFF7C3AED),
  Color(0xFF0891B2),
  Color(0xFFDC2626),
  Color(0xFF65A30D),
  Color(0xFFC026D3),
  Color(0xFF0D9488),
];

Color _colorForType(String? typeId) {
  if (typeId == null || typeId.isEmpty) return _typePalette.first;
  final h = typeId.codeUnits.fold<int>(0, (a, c) => (a + c) % _typePalette.length);
  return _typePalette[h];
}

const List<String> _weekdayLabels = [
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
  'Paz',
];

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  /// Görüntülenen ayın ilk günü (yerel, gün=1).
  late DateTime _month;

  List<LeaveCalendarEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _loadData();
  }

  // Izgara ilk günü = 1'inci günü içeren haftanın Pazartesi'si.
  DateTime get _gridStart {
    final offset = _month.weekday - DateTime.monday; // Mon=0 … Sun=6
    return _month.subtract(Duration(days: offset));
  }

  // Ayın son günü.
  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 0);

  // Izgara son günü = son günü içeren haftanın Pazar'ı.
  DateTime get _gridEnd {
    final trailing = DateTime.sunday - _monthEnd.weekday; // Sun=0 … Mon=6
    return _monthEnd.add(Duration(days: trailing));
  }

  List<DateTime> get _gridDays {
    final total = _gridEnd.difference(_gridStart).inDays + 1;
    return List.generate(
      total,
      (i) => _gridStart.add(Duration(days: i)),
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await hrCalendarReviewService.leaveCalendar(
        from: _gridStart,
        to: _gridEnd,
      );
      if (mounted) {
        setState(() {
          _entries = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load leave calendar', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  void _stepMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
    _loadData();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Bu ay ile kesişen izinleri başlangıca göre sıralı döndür.
  List<LeaveCalendarEntry> get _monthEntries {
    final list = _entries.where((e) {
      final s = e.startDate, en = e.endDate;
      if (s == null || en == null) return false;
      return !s.isAfter(_monthEnd) && !en.isBefore(_month);
    }).toList()
      ..sort((a, b) => (a.startDate ?? _month).compareTo(b.startDate ?? _month));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.leave.calendar_title', 'İzin Takvimi'),
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
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _buildStepper(context),
        const SizedBox(height: AppSpacing.sm),
        _buildWeekdayRow(context),
        const SizedBox(height: AppSpacing.xs),
        _buildGrid(context),
        const SizedBox(height: AppSpacing.md),
        _buildMonthList(context),
      ],
    );
  }

  Widget _buildStepper(BuildContext context) {
    return Row(
      children: [
        AppIconButton(
          icon: Icons.chevron_left,
          onPressed: () => _stepMonth(-1),
        ),
        Expanded(
          child: Center(
            child: Text(
              essMonthYear(_month.year, _month.month),
              style: AppTypography.headline,
            ),
          ),
        ),
        AppIconButton(
          icon: Icons.chevron_right,
          onPressed: () => _stepMonth(1),
        ),
      ],
    );
  }

  Widget _buildWeekdayRow(BuildContext context) {
    return Row(
      children: _weekdayLabels
          .map(
            (w) => Expanded(
              child: Center(
                child: Text(
                  w,
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.tertiaryLabel(context)),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final days = _gridDays;
    final today = DateTime.now();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: days.map((day) {
        final inMonth = day.month == _month.month;
        final isToday = _sameDay(day, today);
        final dayEntries =
            _entries.where((e) => e.coversDay(day)).toList();
        final dotColors = <Color>[];
        for (final e in dayEntries) {
          final c = _colorForType(e.leaveTypeId);
          if (!dotColors.contains(c)) dotColors.add(c);
          if (dotColors.length >= 3) break;
        }
        return _DayCell(
          day: day,
          inMonth: inMonth,
          isToday: isToday,
          dotColors: dotColors,
        );
      }).toList(),
    );
  }

  Widget _buildMonthList(BuildContext context) {
    final entries = _monthEntries;
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: AppEmptyState(
            icon: Icons.event_available_outlined,
            title: essT('hr.leave.calendar_empty', 'Bu ay izin bulunmuyor'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          essT('hr.leave.calendar_month_list', 'Bu ayki izinler'),
          style: AppTypography.footnote
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        const SizedBox(height: AppSpacing.xs),
        ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LeaveEntryCard(entry: e),
            )),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final List<Color> dotColors;

  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.dotColors,
  });

  @override
  Widget build(BuildContext context) {
    final numColor = inMonth
        ? AppColors.primaryLabel(context)
        : AppColors.tertiaryLabel(context);
    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.cardBackground(context),
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: AppColors.primary, width: 1.4)
            : Border.all(color: AppColors.separator(context), width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: AppTypography.caption1.copyWith(
              color: numColor,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: dotColors
                .map((c) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LeaveEntryCard extends StatelessWidget {
  final LeaveCalendarEntry entry;

  const _LeaveEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dc = entry.dayCount;
    final dcStr = dc == dc.roundToDouble() ? dc.toInt().toString() : '$dc';
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _colorForType(entry.leaveTypeId),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.staffName ??
                        essT('hr.leave.calendar_someone', 'Personel'),
                    style: AppTypography.subheadline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.leaveTypeName ?? essT('hr.leave.leave_type', 'İzin türü')} · ${essDateRange(entry.startDate, entry.endDate)}',
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.secondaryLabel(context)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppBadge(
                  label: essStatusLabel(entry.status),
                  variant: essStatusVariant(entry.status),
                  size: AppBadgeSize.small,
                ),
                const SizedBox(height: 4),
                Text(
                  '$dcStr ${essT('hr.leave.days', 'gün')}',
                  style: AppTypography.caption2
                      .copyWith(color: AppColors.tertiaryLabel(context)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

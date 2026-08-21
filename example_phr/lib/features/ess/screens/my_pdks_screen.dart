import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın içinde bulunulan ay için puantaj (PDKS) günleri — salt-okuma.
///
/// Her satır: tarih, vardiya, çalışılan/beklenen süre ("Xs Ydk"), durum rozeti;
/// tatil/izin günleri işaretlenir.
class MyPdksScreen extends StatefulWidget {
  const MyPdksScreen({super.key});

  @override
  State<MyPdksScreen> createState() => _MyPdksScreenState();
}

class _MyPdksScreenState extends State<MyPdksScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<PdksDay> _days = [];
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await hrEssService.pdksRange(_from, _to);
      if (mounted) {
        setState(() {
          _days = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load pdks range', e);
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
      title: essT('hr.pdks.title', 'Puantajım'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _loadData),
      ],
      // Kartlar (giriş/çıkış + harita) kayıtlarla TEK scroll'da — harita ortada
      // pinlenip kayıt alanını daraltmasın; yukarı kaydırınca doğal akış.
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: GeofenceClockCard(),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: GeofenceMapCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
              child: Row(
                children: [
                  Icon(Icons.calendar_month,
                      size: 16, color: AppColors.secondaryLabel(context)),
                  const SizedBox(width: 6),
                  Text(
                    '${essDate(_from)} — ${essDate(_to)}',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._recordWidgets(),
          ],
        ),
      ),
    );
  }

  /// Gün detayı: o günün tüm ham giriş/çıkış hareketlerini (birden fazla
  /// döngü + kaynak) alt sayfada listeler.
  Future<void> _showDayPunches(PdksDay day) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _DayPunchesSheet(day: day),
    );
  }

  /// Kayıtlar bölümü — ana ListView'a gömülür (kendi scroll'u YOK).
  List<Widget> _recordWidgets() {
    if (_isLoading) {
      return const [
        SizedBox(
            height: 220, child: Center(child: AppLoadingIndicator())),
      ];
    }
    if (_errorMessage != null) {
      return [
        SizedBox(
          height: 220,
          child: Center(
            child: AppErrorView(message: _errorMessage!, onRetry: _loadData),
          ),
        ),
      ];
    }
    if (_days.isEmpty) {
      return [
        SizedBox(
          height: 220,
          child: Center(
            child: AppEmptyState(
              icon: Icons.punch_clock_outlined,
              title: essT('hr.pdks.no_records', 'Puantaj kaydı yok'),
            ),
          ),
        ),
      ];
    }
    final out = <Widget>[];
    for (var i = 0; i < _days.length; i++) {
      out.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: _PdksCard(
          day: _days[i],
          onTap: () => _showDayPunches(_days[i]),
        ),
      ));
      if (i < _days.length - 1) {
        out.add(const SizedBox(height: AppSpacing.sm));
      }
    }
    return out;
  }
}

class _PdksCard extends StatelessWidget {
  final PdksDay day;
  final VoidCallback? onTap;

  const _PdksCard({required this.day, this.onTap});

  ({String label, AppBadgeVariant variant}) _dayTag() {
    if (day.isHoliday) {
      return (label: essT('hr.pdks.holiday', 'Tatil'), variant: AppBadgeVariant.warning);
    }
    if (day.isLeave) {
      return (label: essT('hr.pdks.on_leave', 'İzinli'), variant: AppBadgeVariant.info);
    }
    if (!day.isWorkingDay) {
      return (label: essT('hr.pdks.non_working', 'Çalışma dışı'), variant: AppBadgeVariant.neutral);
    }
    return (label: essStatusLabel(day.status), variant: essStatusVariant(day.status));
  }

  @override
  Widget build(BuildContext context) {
    final tag = _dayTag();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    essDate(day.workDate),
                    style: AppTypography.headline,
                  ),
                ),
                AppBadge(
                  label: tag.label,
                  variant: tag.variant,
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  day.shiftName ?? essT('hr.pdks.no_shift', 'Vardiya yok'),
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const Spacer(),
                Text(
                  '${essDuration(day.workedMinutes)} / ${essDuration(day.expectedMinutes)}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (day.entryTime != null || day.exitTime != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(Icons.login,
                      size: 13, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Text(essTime(day.entryTime),
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context))),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.logout,
                      size: 13, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Text(essTime(day.exitTime),
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.tertiaryLabel(context))),
                ],
              ),
            ],
            if (day.lateMinutes > 0 ||
                day.overtimeMinutes > 0 ||
                day.missingMinutes > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  if (day.lateMinutes > 0)
                    _chip(context, Icons.timer_outlined,
                        '${essT('hr.pdks.late', 'Geç')}: ${essDuration(day.lateMinutes)}',
                        AppColors.error),
                  if (day.overtimeMinutes > 0)
                    _chip(context, Icons.more_time,
                        '${essT('hr.pdks.overtime', 'Fazla')}: ${essDuration(day.overtimeMinutes)}',
                        AppColors.success),
                  if (day.missingMinutes > 0)
                    _chip(context, Icons.remove_circle_outline,
                        '${essT('hr.pdks.missing', 'Eksik')}: ${essDuration(day.missingMinutes)}',
                        AppColors.error),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text,
            style: AppTypography.caption2.copyWith(color: color)),
      ],
    );
  }
}

/// Bir günün ham giriş/çıkış hareketlerini (birden fazla döngü + kaynak) listeleyen
/// alt sayfa. Denetim: aynı gün içinde kaç giriş/çıkış yapıldığı burada görünür.
class _DayPunchesSheet extends StatefulWidget {
  final PdksDay day;
  const _DayPunchesSheet({required this.day});

  @override
  State<_DayPunchesSheet> createState() => _DayPunchesSheetState();
}

class _DayPunchesSheetState extends State<_DayPunchesSheet> {
  bool _loading = true;
  List<AttendanceRecordRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await hrEssService.pdksDayPunches(widget.day.workDate);
    if (mounted) {
      setState(() {
        _rows = rows;
        _loading = false;
      });
    }
  }

  String _sourceLabel(String? s) {
    switch (s) {
      case 'mobile_geo':
        return essT('hr.pdks.source_geo', 'Otomatik (konum)');
      case 'manual':
        return essT('hr.pdks.source_manual', 'Manuel');
      default:
        return s ?? '—';
    }
  }

  AppBadgeVariant _sourceVariant(String? s) =>
      s == 'mobile_geo' ? AppBadgeVariant.success : AppBadgeVariant.neutral;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryLabel(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('${essDate(widget.day.workDate)} — Hareketler',
                style: AppTypography.headline),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: AppLoadingIndicator()),
              )
            else if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  essT('hr.pdks.no_punches', 'Bu gün için hareket kaydı yok'),
                  style: AppTypography.footnote.copyWith(
                      color: AppColors.secondaryLabel(context)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (_, i) => _punchTile(_rows[i], i + 1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _punchTile(AttendanceRecordRow r, int index) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text('$index',
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.primary)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.login,
                          size: 13, color: AppColors.tertiaryLabel(context)),
                      const SizedBox(width: 4),
                      Text(essTime(r.entryTime),
                          style: AppTypography.subhead),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.logout,
                          size: 13, color: AppColors.tertiaryLabel(context)),
                      const SizedBox(width: 4),
                      Text(r.isOpen ? '—' : essTime(r.exitTime),
                          style: AppTypography.subhead.copyWith(
                              color: r.isOpen ? AppColors.warning : null)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_sourceLabel(r.source)} · ${essDuration(r.workedMinutes)}'
                    '${r.isOpen ? ' · açık' : ''}',
                    style: AppTypography.caption2.copyWith(
                        color: AppColors.secondaryLabel(context)),
                  ),
                ],
              ),
            ),
            AppBadge(
              label: _sourceLabel(r.source),
              variant: _sourceVariant(r.source),
              size: AppBadgeSize.small,
            ),
          ],
        ),
      ),
    );
  }
}

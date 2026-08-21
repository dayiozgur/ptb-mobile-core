import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_attendance_common.dart';

/// Devam / Giriş-Çıkış — `/admin/attendance`. Ham `attendance_records`
/// kayıtları (tenant-kapsamlı, salt-okuma): personel, tarih, giriş/çıkış,
/// çalışılan süre, kaynak. İçinde bulunulan ay yüklenir; personel adına göre
/// arama yapılır.
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _search = '';
  List<AttendanceRecordRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await adminAttendanceService.attendanceRecords();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load attendance records', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  List<AttendanceRecordRow> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows
        .where((r) => r.staffName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.attendance.title', 'Devam / Giriş-Çıkış'),
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
            child: AppSearchField(
              controller: _searchController,
              placeholder: essT('hr.attendance.search', 'Personel ara'),
              onChanged: (v) => setState(() => _search = v),
              onClear: () => setState(() => _search = ''),
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
    final items = _filtered;
    if (items.isEmpty) {
      return pdksEmptyScroll(
        icon: Icons.login_outlined,
        title: essT('hr.attendance.no_records', 'Devam kaydı yok'),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _RecordCard(record: items[i]),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final AttendanceRecordRow record;

  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final open = record.isOpen;
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: record.staffName, size: AppAvatarSize.small),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    record.staffName,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppBadge(
                  label: open
                      ? essT('hr.attendance.open', 'Açık')
                      : essT('hr.attendance.completed', 'Tamamlandı'),
                  variant:
                      open ? AppBadgeVariant.warning : AppBadgeVariant.success,
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 13, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  essDate(record.workDate),
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
                const Spacer(),
                Icon(Icons.login,
                    size: 13, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 3),
                Text(essTime(record.entryTime),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context))),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.logout,
                    size: 13, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 3),
                Text(essTime(record.exitTime),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context))),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: [
                if (record.workedMinutes > 0)
                  pdksChip(context, Icons.timelapse,
                      essDuration(record.workedMinutes),
                      AppColors.secondaryLabel(context)),
                if (record.source != null && record.source!.isNotEmpty)
                  pdksChip(context, Icons.source_outlined,
                      _sourceLabel(record.source!),
                      AppColors.tertiaryLabel(context)),
                if (record.location != null && record.location!.isNotEmpty)
                  pdksChip(context, Icons.place_outlined, record.location!,
                      AppColors.tertiaryLabel(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(String src) {
    switch (src.toLowerCase()) {
      case 'manual':
        return essT('hr.attendance.src_manual', 'Elle');
      case 'import':
        return essT('hr.attendance.src_import', 'İçe aktarım');
      default:
        return src;
    }
  }
}

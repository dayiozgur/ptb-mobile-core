import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Basit "yeni izin talebi" formu.
///
/// İzin türü (leave_types tablosundan; çözülemezse [balances]'tan türetilir),
/// başlangıç/bitiş tarihi ve isteğe bağlı not alır; `leave_requests`'e
/// `status='pending'` ile ekler. Başarılı olursa `Navigator.pop(true)`.
class MyLeaveFormScreen extends StatefulWidget {
  /// İzin türü seçenekleri için yedek kaynak (bakiye ekranından gelir).
  final List<LeaveBalance> balances;

  const MyLeaveFormScreen({super.key, this.balances = const []});

  @override
  State<MyLeaveFormScreen> createState() => _MyLeaveFormScreenState();
}

class _LeaveTypeOption {
  final String id;
  final String name;
  const _LeaveTypeOption(this.id, this.name);
}

class _MyLeaveFormScreenState extends State<MyLeaveFormScreen> {
  bool _loadingTypes = true;
  bool _submitting = false;

  List<_LeaveTypeOption> _types = [];
  String? _leaveTypeId;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    // Önce leave_types tablosu (RLS kapsamlı); başarısız olursa bakiyeden türet.
    List<_LeaveTypeOption> options = [];
    try {
      final rows = await supabase
          .from('leave_types')
          .select('id, name')
          .order('name');
      options = (rows as List)
          .cast<Map<String, dynamic>>()
          .where((r) => r['id'] != null)
          .map((r) => _LeaveTypeOption(
                r['id'] as String,
                (r['name'] as String?) ??
                    essT('hr.leave.leave_type', 'İzin türü'),
              ))
          .toList();
    } catch (e) {
      Logger.warning('leave_types fetch failed, using balances: $e');
    }

    if (options.isEmpty) {
      options = widget.balances
          .where((b) => b.leaveTypeId != null)
          .map((b) => _LeaveTypeOption(
                b.leaveTypeId!,
                b.leaveTypeName ?? essT('hr.leave.leave_type', 'İzin türü'),
              ))
          .toList();
    }

    if (mounted) {
      setState(() {
        _types = options;
        _loadingTypes = false;
      });
    }
  }

  bool get _isValid =>
      _leaveTypeId != null && _startDate != null && _endDate != null;

  int _dayCount() {
    if (_startDate == null || _endDate == null) return 1;
    final diff = _endDate!.difference(_startDate!).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    if (_endDate!.isBefore(_startDate!)) {
      _snack(essT('hr.leave.end_before_start',
          'Bitiş tarihi başlangıçtan önce olamaz'));
      return;
    }

    setState(() => _submitting = true);
    try {
      final staffId = await hrEssService.currentStaffId();
      final tenantId = sl<TenantService>().currentTenantId;
      final uid = supabase.auth.currentUser?.id;
      if (staffId == null) {
        throw Exception(essT('hr.leave.no_staff', 'Personel kaydı bulunamadı'));
      }

      final note = _noteController.text.trim();
      await supabase.from('leave_requests').insert({
        'staff_id': staffId,
        if (tenantId != null) 'tenant_id': tenantId,
        'leave_type_id': _leaveTypeId,
        'start_date': _fmtDate(_startDate!),
        'end_date': _fmtDate(_endDate!),
        'status': 'pending',
        'day_count': _dayCount(),
        if (note.isNotEmpty) 'note': note,
        if (uid != null) 'created_by': uid,
      });

      if (mounted) {
        _snack(essT('hr.leave.created', 'İzin talebi oluşturuldu'),
            success: true);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Logger.error('Failed to create leave request', e);
      if (mounted) {
        setState(() => _submitting = false);
        _snack(
            '${essT('hr.leave.create_failed', 'İzin talebi oluşturulamadı')}: $e');
      }
    }
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  void _snack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.leave.new_request', 'Yeni izin talebi'),
      onBack: () => Navigator.of(context).pop(false),
      child: _loadingTypes
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdown<String>(
                    label: essT('hr.leave.leave_type', 'İzin türü'),
                    placeholder: essT('common.select', 'Seçiniz'),
                    prefixIcon: Icons.category_outlined,
                    value: _leaveTypeId,
                    items: _types
                        .map((t) =>
                            AppDropdownItem(value: t.id, label: t.name))
                        .toList(),
                    onChanged: (v) => setState(() => _leaveTypeId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppDatePicker(
                    label: essT('hr.leave.start_date', 'Başlangıç tarihi'),
                    prefixIcon: Icons.event,
                    value: _startDate,
                    onChanged: (d) => setState(() {
                      _startDate = d;
                      if (_endDate != null &&
                          d != null &&
                          _endDate!.isBefore(d)) {
                        _endDate = d;
                      }
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppDatePicker(
                    label: essT('hr.leave.end_date', 'Bitiş tarihi'),
                    prefixIcon: Icons.event_available,
                    value: _endDate,
                    minDate: _startDate,
                    onChanged: (d) => setState(() => _endDate = d),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: essT('hr.leave.note', 'Not (isteğe bağlı)'),
                    placeholder:
                        essT('hr.leave.note_hint', 'Açıklama ekleyin'),
                    controller: _noteController,
                    maxLines: 3,
                  ),
                  if (_isValid) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '${essT('hr.leave.total_days', 'Toplam')}: ${_dayCount()} ${essT('hr.leave.days', 'gün')}',
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.secondaryLabel(context)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: essT('common.submit', 'Gönder'),
                    icon: Icons.check,
                    isLoading: _submitting,
                    onPressed: _isValid ? _submit : null,
                  ),
                ],
              ),
            ),
    );
  }
}

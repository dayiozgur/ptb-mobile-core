import 'dart:convert';

import 'package:flutter/material.dart' hide FormField;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/inputs/app_date_picker.dart';
import '../field_render_context.dart';
import 'field_scaffold.dart';

/// Değeri Map'e çevir (Map ise aynen; JSON string ise decode; aksi → {}).
Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

DateTime? _parseDate(dynamic v) {
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

/// `daterange` → başlangıç + bitiş tarih seçici. Değer: `{"start": iso, "end": iso}`.
class DateRangeFieldWidget extends FieldWidget {
  const DateRangeFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    final field = ctx.field;
    final map = _asMap(ctx.value);
    final start = _parseDate(map['start']);
    final end = _parseDate(map['end']);

    void emit(DateTime? s, DateTime? e) {
      ctx.onChanged(<String, dynamic>{
        'start': s?.toIso8601String(),
        'end': e?.toIso8601String(),
      });
    }

    final brightness = Theme.of(context).brightness;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: ctx.errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Başlangıç',
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppDatePicker(
            mode: AppDatePickerMode.date,
            value: start,
            placeholder: 'gg/aa/yyyy',
            enabled: ctx.enabled,
            maxDate: end,
            onChanged: (d) => emit(d, end),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bitiş',
            style: AppTypography.caption1.copyWith(
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppDatePicker(
            mode: AppDatePickerMode.date,
            value: end,
            placeholder: 'gg/aa/yyyy',
            enabled: ctx.enabled,
            minDate: start,
            onChanged: (d) => emit(start, d),
          ),
        ],
      ),
    );
  }
}

/// `slider_range` → çift-uçlu kaydırıcı. Değer: `{"min":n,"max":n}`.
///
/// Sınırlar `field.validation.min/max`'ten (varsayılan 0..100) gelir.
class SliderRangeFieldWidget extends FieldWidget {
  const SliderRangeFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return _SliderRangeView(ctx: ctx);
  }
}

class _SliderRangeView extends StatefulWidget {
  final FieldRenderContext ctx;

  const _SliderRangeView({required this.ctx});

  @override
  State<_SliderRangeView> createState() => _SliderRangeViewState();
}

class _SliderRangeViewState extends State<_SliderRangeView> {
  late double _lower;
  late double _upper;

  double get _boundMin =>
      (widget.ctx.field.validation.min ?? 0).toDouble();
  double get _boundMax {
    final max = (widget.ctx.field.validation.max ?? 100).toDouble();
    return max > _boundMin ? max : _boundMin + 100;
  }

  @override
  void initState() {
    super.initState();
    _syncFromCtx();
  }

  @override
  void didUpdateWidget(covariant _SliderRangeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromCtx();
  }

  void _syncFromCtx() {
    final map = _asMap(widget.ctx.value);
    final lo = (map['min'] as num?)?.toDouble() ?? _boundMin;
    final hi = (map['max'] as num?)?.toDouble() ?? _boundMax;
    _lower = lo.clamp(_boundMin, _boundMax);
    _upper = hi.clamp(_lower, _boundMax);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    final brightness = Theme.of(context).brightness;
    final divisions =
        (_boundMax - _boundMin) >= 1 ? (_boundMax - _boundMin).round() : null;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          RangeSlider(
            values: RangeValues(_lower, _upper),
            min: _boundMin,
            max: _boundMax,
            divisions: divisions,
            activeColor: AppColors.primary,
            labels: RangeLabels(
              _lower.toStringAsFixed(0),
              _upper.toStringAsFixed(0),
            ),
            onChanged: widget.ctx.enabled
                ? (v) => setState(() {
                      _lower = v.start;
                      _upper = v.end;
                    })
                : null,
            onChangeEnd: widget.ctx.enabled
                ? (v) => widget.ctx.onChanged(<String, dynamic>{
                      'min': _round(v.start),
                      'max': _round(v.end),
                    })
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _lower.toStringAsFixed(0),
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                Text(
                  _upper.toStringAsFixed(0),
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  num _round(double v) {
    if (v == v.roundToDouble()) return v.round();
    return double.parse(v.toStringAsFixed(2));
  }
}

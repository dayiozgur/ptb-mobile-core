import 'dart:convert';

import 'package:flutter/material.dart' hide FormField;
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../widgets/buttons/app_button.dart';
import '../field_render_context.dart';
import 'field_scaffold.dart';

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

/// `location` / `gps_capture` → mevcut konumu yakala. Değer: `{"lat":.., "lng":..}`.
///
/// `geolocator` ile izin ister; reddedilirse çökme YOK, alan içinde hata metni
/// gösterilir.
class LocationFieldWidget extends FieldWidget {
  const LocationFieldWidget();

  @override
  Widget build(BuildContext context, FieldRenderContext ctx) {
    return _LocationFieldView(ctx: ctx);
  }
}

class _LocationFieldView extends StatefulWidget {
  final FieldRenderContext ctx;

  const _LocationFieldView({required this.ctx});

  @override
  State<_LocationFieldView> createState() => _LocationFieldViewState();
}

class _LocationFieldViewState extends State<_LocationFieldView> {
  bool _loading = false;
  String? _localError;

  Future<void> _capture() async {
    setState(() {
      _loading = true;
      _localError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fail('Konum servisleri kapalı. Lütfen etkinleştirin.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _fail('Konum izni reddedildi.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _fail('Konum izni kalıcı olarak reddedildi. Ayarlardan açın.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      widget.ctx.onChanged(<String, dynamic>{
        'lat': position.latitude,
        'lng': position.longitude,
      });
    } catch (e) {
      _fail('Konum alınamadı: $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _localError = message;
    });
  }

  void _clear() {
    setState(() => _localError = null);
    widget.ctx.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.ctx.field;
    final brightness = Theme.of(context).brightness;
    final map = _asMap(widget.ctx.value);
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    final hasValue = lat != null && lng != null;

    return FieldScaffold(
      labelText: field.label,
      required: field.isRequired,
      helpText: field.helpText,
      errorText: widget.ctx.errorText ?? _localError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasValue) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: brightness == Brightness.light
                    ? AppColors.systemGray6
                    : AppColors.surfaceElevatedDark,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                  ),
                  if (widget.ctx.enabled)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.clear,
                          size: 20,
                          color: AppColors.textSecondary(brightness)),
                      onPressed: _clear,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            label: hasValue ? 'Konumu Güncelle' : 'Mevcut Konumu Kullan',
            icon: Icons.my_location,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.medium,
            isFullWidth: false,
            isLoading: _loading,
            onPressed: widget.ctx.enabled ? _capture : null,
          ),
        ],
      ),
    );
  }
}

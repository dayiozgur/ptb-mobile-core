import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/entity/status_transition_rules.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// A transition the user picked, plus the comment it required (if any).
class StatusTransitionChoice {
  final AllowedStatusTransition transition;
  final String? comment;

  const StatusTransitionChoice(this.transition, [this.comment]);
}

String _t(String key, String fallback, [Map<String, String>? params]) {
  var v = sl.isRegistered<LocalizationService>()
      ? sl<LocalizationService>().translate(key)
      : key;
  if (v == key || v.isEmpty) v = fallback;
  params?.forEach((k, p) {
    v = v.replaceAll('{{$k}}', p).replaceAll('{$k}', p);
  });
  return v;
}

/// Generic status-change flow for entity screens (web `ptb-entity-list`
/// board parity, same `fixflow.kanban.*` keys):
///  1. bottom sheet with ONLY the allowed [transitions] (already role/form/
///     wizard filtered by [StatusTransitionRules.allowed]);
///  2. comment prompt when the transition `requires_comment`, otherwise a
///     confirmation when it `requires_confirmation`;
///  3. returns the choice — the caller executes it via the
///     `status-transition` Edge Function.
///
/// Returns null when the user cancels at any step.
Future<StatusTransitionChoice?> showStatusTransitionFlow(
  BuildContext context, {
  required List<AllowedStatusTransition> transitions,
  required String Function(String code) nameOf,
  Color? Function(String code)? colorOf,
  String? currentCode,
}) async {
  final picked = await showModalBottomSheet<AllowedStatusTransition>(
    context: context,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _t('fixflow.mobile.change_status', 'Durumu değiştir'),
                    style: AppTypography.headline,
                  ),
                ),
                if (currentCode != null && currentCode.isNotEmpty)
                  Text(nameOf(currentCode),
                      style: AppTypography.caption1
                          .copyWith(color: AppColors.secondaryLabel(ctx))),
              ]),
            ),
            for (final t in transitions)
              ListTile(
                key: ValueKey('status-transition-${t.toCode}'),
                leading: Icon(Icons.circle,
                    size: 14, color: colorOf?.call(t.toCode) ?? AppColors.primary),
                title: Text(nameOf(t.toCode)),
                trailing: const Icon(Icons.arrow_forward, size: 18),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == null || !context.mounted) return null;

  final message = _t('fixflow.kanban.moving_to', '"{{status}}" durumuna taşınacak',
      {'status': nameOf(picked.toCode)});
  if (picked.requiresComment) {
    final comment = await _promptComment(context, message);
    if (comment == null || comment.trim().isEmpty) return null;
    return StatusTransitionChoice(picked, comment.trim());
  }
  if (picked.requiresConfirmation) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(_t('fixflow.kanban.confirm_move', 'Durum Değişikliği')),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: Text(_t('common.cancel', 'İptal'))),
          TextButton(
              key: const Key('status-transition-confirm'),
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(_t('fixflow.kanban.confirm', 'Onayla'))),
        ],
      ),
    );
    if (ok != true) return null;
  }
  return StatusTransitionChoice(picked);
}

/// Comment prompt. The controller is deliberately not disposed: disposing it
/// while the dialog's exit animation still runs throws "used after dispose";
/// a listener-free controller is garbage-collected.
Future<String?> _promptComment(BuildContext context, String message) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(_t('fixflow.kanban.confirm_move', 'Durum Değişikliği')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('status-transition-comment'),
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _t('fixflow.kanban.comment_required', 'Yorum (zorunlu)'),
              hintText: _t('fixflow.kanban.comment_placeholder',
                  'Durum değişikliği için açıklama yazın...'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(_t('common.cancel', 'İptal'))),
        TextButton(
            key: const Key('status-transition-confirm'),
            onPressed: () => Navigator.of(dctx).pop(ctrl.text.trim()),
            child: Text(_t('fixflow.kanban.confirm', 'Onayla'))),
      ],
    ),
  );
}

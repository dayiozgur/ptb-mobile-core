import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_colors.dart';

/// Shared confirmation UX (web parity: confirm before destructive actions,
/// prompt before leaving a form with unsaved changes). All labels come from
/// translation keys — no hard-coded user-visible strings.

String _t(String key) =>
    sl.isRegistered<LocalizationService>()
        ? sl<LocalizationService>().translate(key)
        : key;

/// Asks the user to confirm a destructive action (delete, remove, revoke…).
///
/// Returns `true` only when the user explicitly confirms. [title] defaults to
/// `confirm.delete_title`, [message] to `confirm.delete`, [confirmLabel] to
/// `common.delete`. Pass already-translated strings.
Future<bool> showDestructiveConfirm(
  BuildContext context, {
  String? title,
  String? message,
  String? confirmLabel,
  bool irreversible = true,
}) async {
  final body = message ?? _t('confirm.delete');
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? _t('confirm.delete_title')),
      content: Text(
        irreversible ? '$body\n\n${_t('confirm.irreversible')}' : body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(_t('common.cancel')),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? _t('common.delete')),
        ),
      ],
    ),
  );
  return result == true;
}

/// Asks whether to discard unsaved changes. `true` = discard and leave.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(_t('confirm.unsaved_title')),
      content: Text(_t('confirm.unsaved_message')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(_t('common.keep_editing')),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(_t('common.discard')),
        ),
      ],
    ),
  );
  return result == true;
}

/// Wraps a form screen and intercepts system back / swipe-back / AppBar back
/// (any `Navigator.maybePop`) while [hasChanges] is true, asking the user to
/// confirm discarding. Screens with a custom back button should call
/// `Navigator.of(context).maybePop()` (not `pop`) so the guard applies.
///
/// After a successful save set [hasChanges] to false (or pop with
/// `Navigator.pop`, which bypasses the guard).
class UnsavedChangesGuard extends StatelessWidget {
  final bool hasChanges;
  final Widget child;

  const UnsavedChangesGuard({
    super.key,
    required this.hasChanges,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) Navigator.of(context).pop(result);
      },
      child: child,
    );
  }
}

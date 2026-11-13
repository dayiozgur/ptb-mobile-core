import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/errors/access_errors.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'app_error_view.dart';

String _t(String key) => sl.isRegistered<LocalizationService>()
    ? sl<LocalizationService>().translate(key)
    : key;

/// Calm "you have no access to this" state — shown when the server refused a
/// read because of the caller's role (42501 / 403), instead of an error view
/// with a retry button that can never succeed. See [AccessErrors].
class AppNoAccessView extends StatelessWidget {
  /// Optional override of the explanation (already translated).
  final String? message;
  final bool compact;

  const AppNoAccessView({super.key, this.message, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 28.0 : 44.0;
    return Semantics(
      container: true,
      child: Padding(
        padding: compact ? AppSpacing.allSm : AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                size: iconSize, color: AppColors.tertiaryLabel(context)),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.md),
            Text(
              _t(AccessErrors.titleKey),
              textAlign: TextAlign.center,
              style: compact ? AppTypography.subhead : AppTypography.headline,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ?? _t(AccessErrors.messageKey),
              textAlign: TextAlign.center,
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ],
        ),
      ),
    );
  }
}

/// **What to show when a load failed** — one decision for every screen:
///
///  * the server refused the read for this role → [AppNoAccessView] (no retry);
///  * anything else (timeout, network, server error) → an error view with
///    **retry**.
///
/// It is always scrollable, so it can sit inside a `RefreshIndicator`. A
/// failed load must never be rendered as the screen's EMPTY state ("nothing
/// pending", "no alarms") — that tells the user something that is not known.
class AppLoadFailedView extends StatelessWidget {
  /// The error the load threw.
  final Object? error;

  /// Re-run the load (hidden for a refusal).
  final VoidCallback? onRetry;

  /// Translated message for the non-refusal case (default `common.load_error`).
  final String? message;

  final bool compact;

  const AppLoadFailedView({
    super.key,
    required this.error,
    this.onRetry,
    this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = AccessErrors.isDenied(error)
        ? AppNoAccessView(compact: compact)
        : AppErrorView(
            message: message ?? _t('common.load_error'),
            onRetry: onRetry,
            compact: compact,
          );
    if (compact) return child;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

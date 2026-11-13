import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/integration/graph_problem.dart';
import '../../../core/localization/localization_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../integrations/microsoft_integration_screen.dart';

/// Translate a keyword that may carry web-style `{{param}}` placeholders
/// (the `m365.*` keys are shared with the web app, which uses double braces;
/// [LocalizationService.translate] only knows `{param}`).
String msText(String key, {Map<String, Object?> params = const {}}) {
  var text = sl.isRegistered<LocalizationService>()
      ? sl<LocalizationService>().translate(key)
      : key;
  params.forEach((k, v) {
    text = text.replaceAll('{{$k}}', '$v').replaceAll('{$k}', '$v');
  });
  return text;
}

/// One-line, translated reason for a failed Microsoft action (send, post,
/// create a meeting…): the page stays where it is and the message says why.
String msProblemToast(GraphProblem problem) => msText(
      problem.toastKey,
      params: {
        'seconds': problem.retryAfterSeconds ?? GraphProblem.defaultRetrySeconds
      },
    );

/// Show [msProblemToast] as an error snackbar.
void showMsProblemSnack(BuildContext context, GraphProblem problem) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(SnackBar(
    content: Text(msProblemToast(problem)),
    backgroundColor: Colors.red.shade700,
  ));
}

/// Open the Microsoft 365 connection screen (connect / reconnect / status).
Future<void> openMicrosoftHub(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MicrosoftIntegrationScreen()),
    );

IconData _iconFor(GraphProblemKind k) {
  switch (k) {
    case GraphProblemKind.notConnected:
      return Icons.link_off;
    case GraphProblemKind.reauth:
      return Icons.sync_problem;
    case GraphProblemKind.missingConsent:
      return Icons.gpp_maybe_outlined;
    case GraphProblemKind.adminConsentRequired:
      return Icons.admin_panel_settings_outlined;
    case GraphProblemKind.forbidden:
      return Icons.lock_outline;
    case GraphProblemKind.throttled:
      return Icons.hourglass_bottom;
    case GraphProblemKind.notFound:
      return Icons.help_outline;
    case GraphProblemKind.conflict:
      return Icons.merge_type;
    case GraphProblemKind.blocked:
      return Icons.block;
    case GraphProblemKind.unavailable:
      return Icons.cloud_off;
    case GraphProblemKind.failed:
      return Icons.error_outline;
  }
}

/// **Honest state for a failed Microsoft 365 load** — the mobile parity of the
/// web `ptb-m365-problem`. Shown INSTEAD of an empty list when mail / files /
/// calendar / Teams / Planner could not be read: it names the reason and
/// offers the step that fixes it.
///
///  * not connected / reconnect / missing consent → **Connect** / **Reconnect**
///    ([onConnect], default: open the Microsoft 365 connection screen);
///  * administrator approval required → explanation only (+ open the
///    connection screen), no pointless reconnect loop;
///  * throttled → **Try again**, disabled until the Retry-After countdown ends;
///  * unavailable / failed / not found / conflict / forbidden → **Try again**;
///  * blocked (policy / subscription) → explanation only.
class MsProblemView extends StatefulWidget {
  final GraphProblem problem;

  /// Re-run the load that failed.
  final VoidCallback? onRetry;

  /// Start connect / reconnect. Null → the view opens the connection screen.
  final VoidCallback? onConnect;

  /// Inline (card-sized) layout instead of a centered full-body state.
  final bool compact;

  const MsProblemView({
    super.key,
    required this.problem,
    this.onRetry,
    this.onConnect,
    this.compact = false,
  });

  @override
  State<MsProblemView> createState() => _MsProblemViewState();
}

class _MsProblemViewState extends State<MsProblemView> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(MsProblemView old) {
    super.didUpdateWidget(old);
    if (!identical(old.problem, widget.problem)) _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    _remaining = widget.problem.kind == GraphProblemKind.throttled
        ? (widget.problem.retryAfterSeconds ?? GraphProblem.defaultRetrySeconds)
        : 0;
    if (_remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _remaining = _remaining > 0 ? _remaining - 1 : 0);
        if (_remaining == 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    final kind = p.kind;
    final params = {'seconds': _remaining > 0 ? _remaining : (p.retryAfterSeconds ?? '')};

    final canRetry = widget.onRetry != null &&
        (p.isRetryable || kind == GraphProblemKind.forbidden);
    final showHub = kind == GraphProblemKind.missingConsent ||
        kind == GraphProblemKind.adminConsentRequired;

    final actions = <Widget>[
      if (p.needsConnect)
        FilledButton.icon(
          key: const ValueKey('ms-problem-connect'),
          onPressed: widget.onConnect ?? () => openMicrosoftHub(context),
          icon: const Icon(Icons.link, size: 18),
          label: Text(msText(kind == GraphProblemKind.notConnected
              ? 'm365.connect.action'
              : 'm365.connect.reconnect')),
        ),
      if (showHub)
        OutlinedButton.icon(
          key: const ValueKey('ms-problem-hub'),
          onPressed: () => openMicrosoftHub(context),
          icon: const Icon(Icons.apps, size: 18),
          label: Text(msText('m365.problem.open_hub')),
        ),
      if (canRetry)
        OutlinedButton.icon(
          key: const ValueKey('ms-problem-retry'),
          onPressed: _remaining > 0 ? null : widget.onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(_remaining > 0
              ? msText('m365.problem.retry_in', params: {'seconds': _remaining})
              : msText('m365.problem.retry')),
        ),
    ];

    final iconSize = widget.compact ? 28.0 : 44.0;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          widget.compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(_iconFor(kind), size: iconSize, color: AppColors.tertiaryLabel(context)),
        SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.md),
        Text(
          msText(p.titleKey, params: params),
          textAlign: widget.compact ? TextAlign.start : TextAlign.center,
          style: widget.compact ? AppTypography.subhead : AppTypography.headline,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          msText(p.hintKey, params: params),
          textAlign: widget.compact ? TextAlign.start : TextAlign.center,
          style: AppTypography.footnote
              .copyWith(color: AppColors.secondaryLabel(context)),
        ),
        if (actions.isNotEmpty) ...[
          SizedBox(height: widget.compact ? AppSpacing.sm : AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment:
                widget.compact ? WrapAlignment.start : WrapAlignment.center,
            children: actions,
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      liveRegion: true,
      child: widget.compact
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: body,
            )
          : Center(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: body,
              ),
            ),
    );
  }
}

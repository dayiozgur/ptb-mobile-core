import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Microsoft integration screen (mobile)** — connect / disconnect the user's
/// Microsoft account and control background sync, mirroring the web
/// `account/integrations` page. The connect flow opens the Microsoft authorize
/// URL in the device browser; `oauth-callback` bounces back into the app via the
/// `<scheme>://oauth-callback` deep link (or the user returns and taps Refresh).
///
/// The redirect defaults to [CoreConfig.oauthRedirectUri] (the app's
/// [CoreConfig.appUrlScheme], e.g. CRM `ptbcrm://oauth-callback`);
/// [deepLinkRedirect] overrides it. When the app is
/// reopened by the deep link, call [refresh] (the host wires an app_links
/// listener); a manual Refresh button is the fallback.
class MicrosoftIntegrationScreen extends StatefulWidget {
  final String? deepLinkRedirect;
  const MicrosoftIntegrationScreen({super.key, this.deepLinkRedirect});

  @override
  State<MicrosoftIntegrationScreen> createState() => _MicrosoftIntegrationScreenState();
}

class _MicrosoftIntegrationScreenState extends State<MicrosoftIntegrationScreen>
    with WidgetsBindingObserver {
  MicrosoftIntegrationService get _svc => sl<MicrosoftIntegrationService>();
  String _t(String k) => sl<LocalizationService>().translate(k);

  IntegrationConnection? _conn;
  bool _loading = true;
  bool _busy = false; // connect / disconnect / sync in flight

  /// The connection row exists but is expired / revoked → "reconnect" state.
  IntegrationConnection? _stale;

  /// The connection could not be read at all → "could not check" (never
  /// "not connected").
  bool _lookupFailed = false;

  /// What the browser leg of the connect flow reported (declined / admin
  /// consent required / failed / org approval granted|declined). Persistent
  /// until dismissed or a connection appears.
  OAuthReturnNotice? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MicrosoftOAuthReturn.notice.addListener(_onOAuthNotice);
    MicrosoftOAuthReturn.completions.addListener(_onOAuthCompleted);
    _takeNotice();
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MicrosoftOAuthReturn.notice.removeListener(_onOAuthNotice);
    MicrosoftOAuthReturn.completions.removeListener(_onOAuthCompleted);
    super.dispose();
  }

  /// Consume the pending OAuth-return notice (set by `DeepLinkService`).
  void _takeNotice() {
    final n = MicrosoftOAuthReturn.notice.value;
    if (n == null) return;
    _notice = n;
    MicrosoftOAuthReturn.notice.value = null;
  }

  void _onOAuthNotice() {
    if (!mounted || MicrosoftOAuthReturn.notice.value == null) return;
    setState(_takeNotice);
  }

  /// The `oauth_complete` hand-off finished → re-read the connection now
  /// (the resume refresh may have run before the link was written).
  void _onOAuthCompleted() {
    if (mounted) refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the browser (deep link or manual) — re-read the connection
    // so a just-completed connect flips the screen to "Connected".
    if (state == AppLifecycleState.resumed && !_busy) refresh();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final lookup = await _svc.lookupConnection();
    if (!mounted) return;
    setState(() {
      _conn = lookup.connection;
      _stale = lookup.stale;
      _lookupFailed = lookup.failed;
      // A connection is there → an older "not completed" notice is obsolete.
      if (_conn != null && (_notice?.isError ?? false)) _notice = null;
      _loading = false;
    });
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  Future<void> _connect() async {
    if (_busy) return;
    final redirect =
        widget.deepLinkRedirect ?? CoreInitializer.config?.oauthRedirectUri;
    if (redirect == null) {
      // App'in custom URL scheme'i yok → tarayıcıdan geri dönülemez.
      Logger.warning('[ms-screen] no appUrlScheme configured; connect disabled');
      _toast(_t('integrations.ms.connect_on_web'), error: true);
      return;
    }
    setState(() {
      _busy = true;
      _notice = null; // a new attempt starts clean
    });
    try {
      final url = await _svc.startConnect(redirectAfter: redirect);
      if (url == null) {
        _toast(_t('integrations.ms.connect_failed'), error: true);
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) _toast(_t('integrations.ms.browser_failed'), error: true);
    } catch (e) {
      Logger.error('[ms-screen] connect failed', e);
      _toast(_t('integrations.ms.connect_failed'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect([IntegrationConnection? target]) async {
    final conn = target ?? _conn;
    if (conn == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('integrations.ms.disconnect')),
        content: Text(_t('integrations.ms.disconnect_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('integrations.ms.disconnect'))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final ok = await _svc.disconnect(conn.id);
    _toast(ok ? _t('integrations.ms.disconnected') : _t('integrations.ms.disconnect_failed'), error: !ok);
    await refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleSync(bool enabled) async {
    final conn = _conn;
    if (conn == null) return;
    setState(() => _busy = true);
    final ok = await _svc.setSyncEnabled(conn.id, enabled);
    if (!ok) _toast(_t('integrations.ms.sync_toggle_failed'), error: true);
    await refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _syncNow(Future<bool> Function() action, String labelKey) async {
    setState(() => _busy = true);
    final ok = await action();
    _toast(ok ? _t('integrations.ms.sync_started') : _t('integrations.ms.sync_failed'), error: !ok);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _t('integrations.ms.title'),
      showBackButton: true,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: _loading
              ? [const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))]
              : [
                  if (_notice != null) ...[_noticeCard(_notice!), const SizedBox(height: AppSpacing.md)],
                  if (_lookupFailed)
                    MsProblemView(
                      problem: const GraphProblem(kind: GraphProblemKind.unavailable),
                      onRetry: refresh,
                      compact: true,
                    )
                  else if (_conn != null)
                    ..._connected(_conn!)
                  else if (_stale != null)
                    ..._needsReconnect(_stale!)
                  else
                    ..._notConnected(),
                ],
        ),
      ),
    );
  }

  /// Persistent, translated result of the browser leg (one message per value).
  Widget _noticeCard(OAuthReturnNotice n) {
    final color = n.isError ? Colors.orange.shade800 : Colors.green.shade700;
    return AppCard(
      key: ValueKey('ms-oauth-notice-${n.code}'),
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(n.isError ? Icons.info_outline : Icons.verified_outlined, color: color, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(_t(n.titleKey), style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text(_t(n.hintKey), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _notice = null),
                child: Text(_t('integrations.apps.oauth_result.dismiss')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The row exists but is expired / revoked: reconnect (data is kept).
  List<Widget> _needsReconnect(IntegrationConnection c) => [
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MsProblemView(
                  problem: const GraphProblem(kind: GraphProblemKind.reauth),
                  onConnect: _connect,
                  compact: true,
                ),
                if (c.accountEmail != null)
                  Text(c.accountEmail!,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _t('integrations.ms.disconnect'),
          icon: Icons.link_off,
          variant: AppButtonVariant.secondary,
          isLoading: _busy,
          onPressed: _busy ? null : () => _disconnect(c),
        ),
      ];

  List<Widget> _notConnected() => [
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.cloud_off, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(_t('integrations.ms.not_connected'),
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text(_t('integrations.ms.connect_hint'),
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: _t('integrations.ms.connect'),
                  icon: Icons.link,
                  isLoading: _busy,
                  onPressed: _busy ? null : _connect,
                ),
              ],
            ),
          ),
        ),
      ];

  List<Widget> _connected(IntegrationConnection c) => [
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_t('integrations.ms.connected'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (c.accountEmail != null)
                        Text(c.accountEmail!,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
                    ]),
                  ),
                ]),
                const Divider(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_t('integrations.ms.autosync')),
                  subtitle: Text(_t('integrations.ms.autosync_hint')),
                  value: c.syncEnabled,
                  onChanged: _busy ? null : _toggleSync,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: _t('integrations.ms.tools')),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(_t('crm.mailbox.title')),
            subtitle: Text(_t('crm.mailbox.subtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MsMailboxScreen()),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: _t('integrations.ms.sync_now')),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Column(children: [
              _syncTile(Icons.mail_outline, 'integrations.ms.sync_mailbox', () => _svc.syncMailbox()),
              _syncTile(Icons.event_outlined, 'integrations.ms.sync_calendar', () => _svc.syncCalendar()),
              _syncTile(Icons.contacts_outlined, 'integrations.ms.sync_contacts', () => _svc.importContacts(), last: true),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _t('integrations.ms.disconnect'),
          icon: Icons.link_off,
          variant: AppButtonVariant.secondary,
          isLoading: _busy,
          onPressed: _busy ? null : () => _disconnect(),
        ),
      ];

  Widget _syncTile(IconData icon, String labelKey, Future<bool> Function() action, {bool last = false}) => Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(_t(labelKey)),
            trailing: const Icon(Icons.sync, size: 18),
            enabled: !_busy,
            onTap: _busy ? null : () => _syncNow(action, labelKey),
          ),
          if (!last) const Divider(height: 1),
        ],
      );
}

import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Microsoft integration screen (mobile)** — connect / disconnect the user's
/// Microsoft account and control background sync, mirroring the web
/// `account/integrations` page. The connect flow opens the Microsoft authorize
/// URL in the device browser; `oauth-callback` bounces back into the app via the
/// `ptbcrm://oauth-callback` deep link (or the user returns and taps Refresh).
///
/// Pass [deepLinkRedirect] as the app's registered redirect URI. When the app is
/// reopened by the deep link, call [refresh] (the host wires an app_links
/// listener); a manual Refresh button is the fallback.
class MicrosoftIntegrationScreen extends StatefulWidget {
  final String deepLinkRedirect;
  const MicrosoftIntegrationScreen({super.key, this.deepLinkRedirect = 'ptbcrm://oauth-callback'});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the browser (deep link or manual) — re-read the connection
    // so a just-completed connect flips the screen to "Connected".
    if (state == AppLifecycleState.resumed && !_busy) refresh();
  }

  Future<void> refresh() async {
    setState(() => _loading = true);
    final conn = await _svc.getConnected();
    if (!mounted) return;
    setState(() {
      _conn = conn;
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
    setState(() => _busy = true);
    try {
      final url = await _svc.startConnect(redirectAfter: widget.deepLinkRedirect);
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

  Future<void> _disconnect() async {
    final conn = _conn;
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
              : (_conn == null ? _notConnected() : _connected(_conn!)),
        ),
      ),
    );
  }

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
          onPressed: _busy ? null : _disconnect,
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

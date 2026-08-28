import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

// SubscriptionScreen, SecurityScreen, AdminSubscriptionService ve SubscriptionInfo
// barrel'dan gelir. Yeni kardeş ekranlar henüz barrel'da olmadığından relative.

/// Hesabım — Hesap merkezi (landing). Web hesap bölümünün mobil karşılığı.
///
/// Üstte geçerli aboneliğin plan + durum özeti (salt-okuma,
/// [AdminSubscriptionService]) gösterilir; altta alt-ekranlara giden
/// navigasyon kartları listelenir. **Satın alma / yazma YOK** (mobilde yasak).
///
/// [embedded] true ise (ör. bir sekme içinde) app-bar gizlenir — HomeScreen
/// ile aynı desen.
class AccountHubScreen extends StatefulWidget {
  const AccountHubScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AccountHubScreen> createState() => _AccountHubScreenState();
}

class _AccountHubScreenState extends State<AccountHubScreen> {
  SubscriptionInfo? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    SubscriptionInfo? sub;
    try {
      final tenantId = sl<TenantService>().currentTenantId;
      sub = await sl<AdminSubscriptionService>().getSubscription(
        tenantId: tenantId,
      );
    } catch (e, st) {
      // Overview kartı opsiyonel — hata hub'ı çökertmez, kart gizlenir.
      Logger.error('AccountHubScreen abonelik özeti okunamadı', e, st);
      sub = null;
    }
    if (!mounted) return;
    setState(() {
      _sub = sub;
      _loading = false;
    });
  }

  // ── Durum paleti (subscription_screen ile aynı) ──────────────────────────────

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return const Color(0xFF059669);
      case 'trial':
        return const Color(0xFF2563EB);
      case 'past_due':
        return const Color(0xFFD97706);
      case 'canceled':
      case 'expired':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'trial':
        return 'Deneme';
      case 'past_due':
        return 'Gecikmiş';
      case 'canceled':
        return 'İptal edildi';
      case 'expired':
        return 'Süresi doldu';
      default:
        return status ?? '—';
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Hesabım',
      showAppBar: !widget.embedded,
      showBackButton: false,
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _buildOverviewCard(context),
            const SizedBox(height: AppSpacing.lg),
            _buildTiles(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    if (_loading) {
      return const AppCard(
        variant: AppCardVariant.outlined,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(child: AppLoadingIndicator()),
        ),
      );
    }

    final sub = _sub;
    final planName = (sub?.planName == null || sub!.planName!.trim().isEmpty)
        ? (sub?.planCode ?? 'Plan yok')
        : sub.planName!.trim();
    final status = sub?.status;
    final statusColor = _statusColor(status);

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.workspace_premium_outlined,
                color: statusColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mevcut Plan',
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  planName,
                  style: AppTypography.title3
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _pill(statusColor, _statusLabel(status)),
        ],
      ),
    );
  }

  Widget _buildTiles(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _tile(context, Icons.workspace_premium_outlined, 'Abonelik',
              'Plan, durum ve kotalar', () => _push(const SubscriptionScreen())),
          _divider(context),
          _tile(context, Icons.toll_outlined, 'Krediler',
              'Bakiye ve hareketler', () => _push(const CreditsScreen())),
          _divider(context),
          _tile(context, Icons.receipt_long_outlined, 'Faturalar',
              'Fatura geçmişi ve özet', () => _push(const InvoicesScreen())),
          _divider(context),
          _tile(context, Icons.cloud_outlined, 'Kullanım & Depolama',
              'Depolama kotası ve kullanım', () => _push(const UsageScreen())),
          _divider(context),
          _tile(context, Icons.shield_outlined, 'Güvenlik',
              'Şifre ve iki adımlı doğrulama',
              () => _push(const SecurityScreen())),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return AppListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: title,
      subtitle: subtitle,
      showChevron: true,
      showDivider: false,
      onTap: onTap,
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, color: AppColors.separator(context));

  Widget _pill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.caption1
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

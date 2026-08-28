import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';


/// Hesap — Abonelik görüntüleyici ekranı (salt-okuma).
///
/// Web hesap abonelik sayfasının mobil karşılığı. Geçerli tenant'ın planı,
/// durumu, deneme/yenileme tarihleri ve plan kotaları (limit + varsa kullanım)
/// gösterilir. [AdminSubscriptionService] üzerinden RLS-scoped okunur.
/// **Satın alma / plan değişimi mobilde sunulmaz** (yasak).
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionInfo? _sub;
  List<QuotaRow> _quotas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tenantId = sl<TenantService>().currentTenantId;
      final service = sl<AdminSubscriptionService>();
      final sub = await service.getSubscription(tenantId: tenantId);
      var quotas = <QuotaRow>[];
      if (sub?.planId != null) {
        quotas = await service.listPlanQuotas(
          planId: sub!.planId!,
          tenantId: tenantId,
        );
      }
      if (!mounted) return;
      setState(() {
        _sub = sub;
        _quotas = quotas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Abonelik yüklenemedi';
        _loading = false;
      });
    }
  }

  // ── Durum paleti ─────────────────────────────────────────────────────────────

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return const Color(0xFF059669); // yeşil
      case 'trial':
        return const Color(0xFF2563EB); // mavi
      case 'past_due':
        return const Color(0xFFD97706); // amber
      case 'canceled':
      case 'expired':
        return const Color(0xFFDC2626); // kırmızı
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

  String _quotaLabel(String? key) {
    if (key == null || key.isEmpty) return '—';
    // snake_case → Başlık Biçimi (web formatQuotaKey benzeri, jenerik).
    return key
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }

  String _formatInt(num? n) {
    if (n == null) return '—';
    final s = n.toInt().toString();
    // Basit binlik ayırıcı (nokta, TR).
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Abonelik',
      showBackButton: true,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(context, Icons.error_outline, _error!, retry: true);
    }
    if (_sub == null) {
      return _buildMessage(
          context, Icons.credit_card_outlined, 'Aktif abonelik yok');
    }

    // CRITICAL: ListView (bounded) — kaydırma içinde unbounded Flex YOK.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _buildPlanCard(context, _sub!),
          if (_quotas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Kotalar',
              style: AppTypography.subhead.copyWith(
                color: AppColors.secondaryLabel(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._quotas.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildQuotaCard(context, q),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, SubscriptionInfo s) {
    final statusColor = _statusColor(s.status);
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  (s.planName == null || s.planName!.trim().isEmpty)
                      ? 'Plan'
                      : s.planName!.trim(),
                  style: AppTypography.title3
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _pill(statusColor, _statusLabel(s.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _infoRow(context, Icons.workspace_premium_outlined, 'Plan',
              (s.planName ?? s.planCode) ?? '—'),
          _infoRow(context, Icons.info_outline, 'Durum',
              _statusLabel(s.status)),
          if (s.isTrial)
            _infoRow(context, Icons.hourglass_bottom_outlined, 'Deneme Bitişi',
                _formatDate(s.trialEndsAt))
          else
            _infoRow(context, Icons.event_repeat_outlined, 'Yenileme',
                _formatDate(s.currentPeriodEnd)),
          if (s.cancelAtPeriodEnd)
            _infoRow(context, Icons.cancel_outlined, 'Dönem Sonunda',
                'İptal edilecek'),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(BuildContext context, QuotaRow q) {
    final fraction = q.usageFraction;
    final limitText = _formatInt(q.quotaValue);
    final unit = (q.quotaUnit == null || q.quotaUnit!.isEmpty)
        ? ''
        : ' ${q.quotaUnit}';
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _quotaLabel(q.quotaKey),
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                q.usedValue != null
                    ? '${_formatInt(q.usedValue)} / $limitText$unit'
                    : '$limitText$unit',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: AppColors.secondaryLabel(context)
                    .withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  fraction >= 1
                      ? const Color(0xFFDC2626)
                      : (fraction >= 0.8
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: AppTypography.subhead
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  AppTypography.subhead.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, IconData icon, String message,
      {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.secondaryLabel(context)),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.body
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          if (retry) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ],
      ),
    );
  }
}

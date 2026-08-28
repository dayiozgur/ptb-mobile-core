import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';


/// Admin — Entegrasyonlar görüntüleyici ekranı.
///
/// Web portal `/admin/integrations` (integration framework + ops-console)
/// özelliğinin mobil, salt-okuma karşılığı. [AdminIntegrationService] üzerinden
/// yapılandırılmış connector'ları (RLS-scoped, ada göre) listeler. Her kart
/// durum rozeti + etkin/pasif + en son çalıştırma/hata taşır; satıra dokununca
/// detay bottom-sheet'inde gösterilir. Yazma / çalıştırma mobilde sunulmaz.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  List<IntegrationRow> _items = [];

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
      final items = await sl<AdminIntegrationService>().listIntegrations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Entegrasyonlar yüklenemedi';
        _loading = false;
      });
    }
  }

  // ── Durum paleti (web badge sınıflarıyla eşleşir) ────────────────────────────

  Color _statusColor(String? status) {
    switch (status) {
      case 'success':
        return const Color(0xFF059669); // yeşil (success)
      case 'running':
        return const Color(0xFF2563EB); // mavi (info)
      case 'error':
      case 'failed':
        return const Color(0xFFDC2626); // kırmızı (danger)
      default:
        return const Color(0xFF6B7280); // gri (secondary)
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'success':
        return 'Başarılı';
      case 'running':
        return 'Çalışıyor';
      case 'error':
      case 'failed':
        return 'Hata';
      default:
        return status == null || status.isEmpty ? 'Çalışmadı' : status;
    }
  }

  /// dd.MM.yyyy HH:mm (TR).
  String _formatDateTime(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Entegrasyonlar',
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
    if (_items.isEmpty) {
      return _buildMessage(
          context, Icons.hub_outlined, 'Kayıt yok');
    }

    // CRITICAL: ListView (bounded) — kaydırma içinde unbounded Flex YOK.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _buildCard(context, _items[i]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IntegrationRow r) {
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: () => _showSheet(context, r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (r.name == null || r.name!.trim().isEmpty)
                ? 'Adsız'
                : r.name!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            r.typeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption1
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(_statusColor(r.lastStatus), _statusLabel(r.lastStatus)),
              _pill(
                r.enabled
                    ? const Color(0xFF059669)
                    : const Color(0xFF6B7280),
                r.enabled ? 'Etkin' : 'Pasif',
              ),
              if (r.lastRunAt != null)
                Text(
                  _formatDateTime(r.lastRunAt),
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
            ],
          ),
          if (r.lastError != null && r.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              r.lastError!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption1
                  .copyWith(color: const Color(0xFFDC2626)),
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

  // ── Detay bottom-sheet (salt-okunur) ──────────────────────────────────────

  void _showSheet(BuildContext context, IntegrationRow r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                (r.name == null || r.name!.trim().isEmpty)
                    ? 'Adsız'
                    : r.name!.trim(),
                style:
                    AppTypography.title3.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _pill(_statusColor(r.lastStatus), _statusLabel(r.lastStatus)),
                  _pill(
                    r.enabled
                        ? const Color(0xFF059669)
                        : const Color(0xFF6B7280),
                    r.enabled ? 'Etkin' : 'Pasif',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (r.kind != null && r.kind!.isNotEmpty)
                _infoRow(ctx, Icons.category_outlined, 'Tür', r.kind!),
              if (r.provider != null && r.provider!.isNotEmpty)
                _infoRow(ctx, Icons.cloud_outlined, 'Sağlayıcı', r.provider!),
              _infoRow(ctx, Icons.schedule_outlined, 'Zamanlama',
                  (r.schedule == null || r.schedule!.trim().isEmpty)
                      ? 'Manuel'
                      : r.schedule!.trim()),
              _infoRow(ctx, Icons.play_circle_outline, 'Son çalıştırma',
                  r.lastRunAt == null ? '—' : _formatDateTime(r.lastRunAt)),
              _infoRow(ctx, Icons.info_outline, 'Durum',
                  _statusLabel(r.lastStatus)),
              if (r.lastError != null && r.lastError!.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Son hata',
                  style: AppTypography.subhead.copyWith(
                    color: AppColors.secondaryLabel(ctx),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  r.lastError!.trim(),
                  style: AppTypography.body
                      .copyWith(color: const Color(0xFFDC2626)),
                ),
              ],
            ],
          ),
        );
      },
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

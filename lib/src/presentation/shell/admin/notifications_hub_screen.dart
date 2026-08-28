import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';


/// Admin — Bildirim Merkezi görüntüleyici ekranı (salt-okuma).
///
/// Web portal `notifications-hub` özelliğinin mobil karşılığı. Web hub'ı bir
/// gönderim formu + gönderilen geçmişi sunar; mobil v1 **yalnız gönderilen
/// yayınları** (broadcasts) listeler — gönderim/işlem mobilde sunulmaz.
/// [AdminNotificationsHubService] üzerinden geçerli kullanıcının gönderdiği
/// yayınlar (RLS-scoped, en yeni önce) alınır; toplu gönderimler tek satırda
/// alıcı sayısıyla gösterilir. Satıra dokununca mesaj detay bottom-sheet'inde
/// açılır.
class NotificationsHubScreen extends StatefulWidget {
  const NotificationsHubScreen({super.key});

  @override
  State<NotificationsHubScreen> createState() => _NotificationsHubScreenState();
}

class _NotificationsHubScreenState extends State<NotificationsHubScreen> {
  List<SentBroadcastRow> _rows = [];
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
      final rows =
          await sl<AdminNotificationsHubService>().listRecentBroadcasts();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Yayınlar yüklenemedi';
        _loading = false;
      });
    }
  }

  // ── Tür paleti (web badge sınıflarıyla eşleşir) ──────────────────────────────

  Color _typeColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'SUCCESS':
        return const Color(0xFF059669); // yeşil
      case 'WARNING':
      case 'ALERT':
        return const Color(0xFFD97706); // amber
      case 'ERROR':
        return const Color(0xFFDC2626); // kırmızı
      case 'SYSTEM':
        return const Color(0xFF7C3AED); // mor (primary)
      case 'REMINDER':
      case 'INFO':
        return const Color(0xFF2563EB); // mavi
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _typeLabel(String? type) {
    switch (type?.toUpperCase()) {
      case 'INFO':
        return 'Bilgi';
      case 'SUCCESS':
        return 'Başarılı';
      case 'WARNING':
        return 'Uyarı';
      case 'ERROR':
        return 'Hata';
      case 'SYSTEM':
        return 'Sistem';
      case 'ALERT':
        return 'Alarm';
      case 'REMINDER':
        return 'Hatırlatma';
      default:
        return type ?? '—';
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
      title: 'Bildirim Merkezi',
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
    if (_rows.isEmpty) {
      return _buildMessage(
          context, Icons.notifications_none_outlined, 'Kayıt yok');
    }

    // CRITICAL: ListView (bounded) — kaydırma içinde unbounded Flex YOK.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _buildCard(context, _rows[i]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, SentBroadcastRow r) {
    final typeColor = _typeColor(r.notificationType);
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: () => _showSheet(context, r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (r.title == null || r.title!.trim().isEmpty)
                ? 'Başlıksız'
                : r.title!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
          if (r.message != null && r.message!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              r.message!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.subhead
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(typeColor, _typeLabel(r.notificationType)),
              _pill(const Color(0xFF6B7280),
                  '${r.recipientCount} alıcı'),
              if (r.createdAt != null)
                Text(
                  _formatDateTime(r.createdAt),
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
            ],
          ),
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

  void _showSheet(BuildContext context, SentBroadcastRow r) {
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
                (r.title == null || r.title!.trim().isEmpty)
                    ? 'Başlıksız'
                    : r.title!.trim(),
                style:
                    AppTypography.title3.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _pill(_typeColor(r.notificationType),
                      _typeLabel(r.notificationType)),
                  _pill(const Color(0xFF6B7280), '${r.recipientCount} alıcı'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (r.firstRecipientName != null &&
                  r.firstRecipientName!.isNotEmpty)
                _infoRow(ctx, Icons.person_outline, 'Alıcı',
                    r.firstRecipientName!),
              if (r.createdAt != null)
                _infoRow(ctx, Icons.event_outlined, 'Gönderim',
                    _formatDateTime(r.createdAt)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Mesaj',
                style: AppTypography.subhead.copyWith(
                  color: AppColors.secondaryLabel(ctx),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                (r.message == null || r.message!.trim().isEmpty)
                    ? 'Mesaj yok'
                    : r.message!.trim(),
                style: AppTypography.body,
              ),
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

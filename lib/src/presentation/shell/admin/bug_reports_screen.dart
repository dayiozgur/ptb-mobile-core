import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../../core/admin/admin_bug_report_service.dart';

/// Admin — Hata Bildirimleri görüntüleyici ekranı.
///
/// Web portal `bug-reports` özelliğinin mobil, salt-okuma karşılığı.
/// [AdminBugReportService] üzerinden hata bildirimlerini (RLS-scoped, en yeni
/// önce) listeler. Her kart durum + öncelik rozeti ve tarih taşır; satıra
/// dokununca açıklama detay bottom-sheet'inde gösterilir. Yazma/durum-değişimi
/// mobilde sunulmaz.
class BugReportsScreen extends StatefulWidget {
  const BugReportsScreen({super.key});

  @override
  State<BugReportsScreen> createState() => _BugReportsScreenState();
}

class _BugReportsScreenState extends State<BugReportsScreen> {
  List<BugReportRow> _reports = [];

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
      final reports = await sl<AdminBugReportService>().listBugReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Hata bildirimleri yüklenemedi';
        _loading = false;
      });
    }
  }

  // ── Durum / öncelik paletleri (web badge sınıflarıyla eşleşir) ───────────────

  Color _statusColor(String? status) {
    switch (status) {
      case 'open':
        return const Color(0xFFDC2626); // kırmızı (danger)
      case 'in_progress':
        return const Color(0xFFD97706); // amber (warning)
      case 'resolved':
        return const Color(0xFF059669); // yeşil (success)
      case 'closed':
        return const Color(0xFF6B7280); // gri (secondary)
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'in_progress':
        return 'İşlemde';
      case 'resolved':
        return 'Çözüldü';
      case 'closed':
        return 'Kapatıldı';
      default:
        return status ?? '—';
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'critical':
        return const Color(0xFFDC2626); // kırmızı
      case 'high':
        return const Color(0xFFD97706); // amber
      case 'medium':
        return const Color(0xFF2563EB); // mavi (info)
      case 'low':
        return const Color(0xFF059669); // yeşil
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _priorityLabel(String? priority) {
    switch (priority) {
      case 'critical':
        return 'Kritik';
      case 'high':
        return 'Yüksek';
      case 'medium':
        return 'Orta';
      case 'low':
        return 'Düşük';
      default:
        return priority ?? '—';
    }
  }

  /// dd.MM.yyyy (TR).
  String _formatDate(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Hata Bildirimleri',
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
    if (_reports.isEmpty) {
      return _buildMessage(
          context, Icons.bug_report_outlined, 'Hata bildirimi bulunamadı');
    }

    // CRITICAL: ListView (bounded) — kaydırma içinde unbounded Flex YOK.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _buildReportCard(context, _reports[i]),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, BugReportRow r) {
    final statusColor = _statusColor(r.status);
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: () => _showReportSheet(context, r),
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
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(statusColor, _statusLabel(r.status)),
              if (r.priority != null && r.priority!.isNotEmpty)
                _pill(_priorityColor(r.priority), _priorityLabel(r.priority)),
              if (r.createdAt != null)
                Text(
                  _formatDate(r.createdAt),
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

  void _showReportSheet(BuildContext context, BugReportRow r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // ListView: bottom-sheet içeriği için bounded, güvenli kaydırma.
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
                  _pill(_statusColor(r.status), _statusLabel(r.status)),
                  if (r.priority != null && r.priority!.isNotEmpty)
                    _pill(_priorityColor(r.priority),
                        _priorityLabel(r.priority)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (r.ticketNumber != null && r.ticketNumber!.isNotEmpty)
                _infoRow(ctx, Icons.confirmation_number_outlined, 'Kayıt No',
                    r.ticketNumber!),
              if (r.type != null && r.type!.isNotEmpty)
                _infoRow(ctx, Icons.category_outlined, 'Tür', r.type!),
              if (r.category != null && r.category!.isNotEmpty)
                _infoRow(ctx, Icons.folder_outlined, 'Kategori', r.category!),
              if (r.reporterName != null && r.reporterName!.isNotEmpty)
                _infoRow(ctx, Icons.person_outline, 'Bildiren',
                    r.reporterName!),
              if (r.createdAt != null)
                _infoRow(ctx, Icons.event_outlined, 'Tarih',
                    _formatDate(r.createdAt)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Açıklama',
                style: AppTypography.subhead.copyWith(
                  color: AppColors.secondaryLabel(ctx),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                (r.description == null || r.description!.trim().isEmpty)
                    ? 'Açıklama yok'
                    : r.description!.trim(),
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

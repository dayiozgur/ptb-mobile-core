import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Hesap → Faturalar görüntüleyici (salt-okuma). Web fatura sayfasının mobil
/// karşılığı: özet çipleri (toplam / ödenen / bekleyen / gecikmiş) + fatura
/// listesi (numara, tarih, tutar, durum rozeti). **Ödeme YOK** (mobilde yasak).
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Invoice> _invoices = const [];
  InvoiceSummary _summary = const InvoiceSummary();
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
      final invoices = await accountService.invoices();
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _summary = InvoiceSummary.fromInvoices(invoices);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Faturalar yüklenemedi';
        _loading = false;
      });
    }
  }

  String _money(num amount, String? currency) {
    final symbol = _currencySymbol(currency ?? _summary.currency);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'TRY':
        return '₺';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      default:
        return '$currency ';
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}.${two(l.month)}.${l.year}';
  }

  AppBadgeVariant _statusVariant(String status) {
    switch (status) {
      case 'paid':
        return AppBadgeVariant.success;
      case 'sent':
      case 'draft':
      case 'pending':
        return AppBadgeVariant.warning;
      case 'overdue':
        return AppBadgeVariant.error;
      case 'void':
        return AppBadgeVariant.neutral;
      default:
        return AppBadgeVariant.info;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Ödendi';
      case 'sent':
        return 'Gönderildi';
      case 'draft':
        return 'Taslak';
      case 'pending':
        return 'Bekliyor';
      case 'overdue':
        return 'Gecikmiş';
      case 'void':
        return 'İptal';
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Faturalar',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(onRefresh: _load, child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _load);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _buildSummary(context),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Fatura Geçmişi',
          style: AppTypography.subhead.copyWith(
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_invoices.isEmpty)
          const AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Fatura yok',
          )
        else
          AppCard(
            child: Column(
              children: [
                for (int i = 0; i < _invoices.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: AppColors.separator(context)),
                  _buildInvoiceRow(context, _invoices[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final s = _summary;
    return Row(
      children: [
        Expanded(
          child: _chip(context, 'Toplam', '${s.totalCount}',
              AppColors.primary, Icons.receipt_outlined),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _chip(context, 'Ödenen', _money(s.paidTotal, s.currency),
              const Color(0xFF059669), Icons.check_circle_outline),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, String value, Color color,
      IconData icon) {
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(BuildContext context, Invoice inv) {
    final number = (inv.invoiceNumber == null || inv.invoiceNumber!.isEmpty)
        ? 'Fatura'
        : inv.invoiceNumber!;
    return AppListTile(
      title: number,
      subtitle: _fmtDate(inv.invoiceDate),
      showDivider: false,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _money(inv.totalAmount, inv.currency),
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          AppBadge(
            label: _statusLabel(inv.status),
            variant: _statusVariant(inv.status),
            size: AppBadgeSize.small,
          ),
        ],
      ),
    );
  }
}

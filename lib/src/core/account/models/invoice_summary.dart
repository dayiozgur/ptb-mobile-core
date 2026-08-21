import 'invoice.dart';

/// Fatura özeti (salt-okuma). Web `BillingService.getInvoiceSummary()` mantığı:
/// `status='void'` atlanır; ödenen toplam, bekleyen toplam (draft/sent/pending)
/// ve gecikmiş adedi türetilir.
class InvoiceSummary {
  final int totalCount;
  final num paidTotal;
  final num pendingTotal;
  final int overdueCount;
  final String currency;

  const InvoiceSummary({
    this.totalCount = 0,
    this.paidTotal = 0,
    this.pendingTotal = 0,
    this.overdueCount = 0,
    this.currency = 'TRY',
  });

  /// Fatura listesinden özet türetir (web ile aynı kurallar).
  factory InvoiceSummary.fromInvoices(List<Invoice> invoices) {
    int total = 0;
    num paid = 0;
    num pending = 0;
    int overdue = 0;
    String currency = 'TRY';

    for (final inv in invoices) {
      if (inv.status == 'void') continue;
      total++;
      switch (inv.status) {
        case 'paid':
          paid += inv.totalAmount;
          break;
        case 'draft':
        case 'sent':
        case 'pending':
          pending += inv.totalAmount;
          break;
        case 'overdue':
          overdue++;
          break;
      }
      if (inv.currency != null && inv.currency!.isNotEmpty) {
        currency = inv.currency!;
      }
    }

    return InvoiceSummary(
      totalCount: total,
      paidTotal: paid,
      pendingTotal: pending,
      overdueCount: overdue,
      currency: currency,
    );
  }
}

/// Fatura görüntü-modeli (salt-okuma).
///
/// Web `BillingService.getInvoices()` → `tenant_invoices` satırı. Durum:
/// `draft | sent | paid | overdue | void`.
class Invoice {
  final String? id;
  final String? invoiceNumber;
  final String status;
  final num totalAmount;
  final String? currency;
  final DateTime? invoiceDate;
  final DateTime? dueDate;

  const Invoice({
    this.id,
    this.invoiceNumber,
    this.status = '',
    this.totalAmount = 0,
    this.currency,
    this.invoiceDate,
    this.dueDate,
  });

  static num _n(dynamic v) => (v is num) ? v : (num.tryParse('${v ?? ''}') ?? 0);

  static DateTime? _d(dynamic v) =>
      v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id']?.toString(),
      invoiceNumber: json['invoice_number']?.toString(),
      status: json['status']?.toString() ?? '',
      totalAmount: _n(json['total_amount']),
      currency: json['currency']?.toString(),
      invoiceDate: _d(json['invoice_date']),
      dueDate: _d(json['due_date']),
    );
  }
}

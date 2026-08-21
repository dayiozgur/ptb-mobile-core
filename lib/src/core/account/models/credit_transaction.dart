/// Kredi hareketi görüntü-modeli (salt-okuma).
///
/// Web `tenant_credit_transactions` satırı. Kolon adları sürüme göre değişebilir:
/// tutar `credit_amount` (fallback `amount`), tür `transaction_type`
/// (fallback `type`/`kind`) alanından savunmacı okunur.
class CreditTransaction {
  final String? id;
  final num amount;
  final String? kind;
  final String? description;
  final DateTime? createdAt;

  const CreditTransaction({
    this.id,
    this.amount = 0,
    this.kind,
    this.description,
    this.createdAt,
  });

  static num _n(dynamic v) => (v is num) ? v : (num.tryParse('${v ?? ''}') ?? 0);

  static DateTime? _d(dynamic v) =>
      v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id']?.toString(),
      amount: _n(json['credit_amount'] ?? json['amount']),
      kind: (json['transaction_type'] ?? json['type'] ?? json['kind'])
          ?.toString(),
      description: json['description']?.toString(),
      createdAt: _d(json['created_at']),
    );
  }
}

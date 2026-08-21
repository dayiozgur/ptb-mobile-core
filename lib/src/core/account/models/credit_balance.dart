/// Kredi bakiyesi görüntü-modeli (salt-okuma).
///
/// Web `BillingService.getCreditBalance()` / `TenantCreditService.getBalance()`
/// ile aynı `tenant_credits` satırını aynalar. Tüm alanlar `num`, yoksa 0.
class CreditBalance {
  final num availableCredits;
  final num totalCredits;
  final num usedCredits;
  final num lifetimePurchasedCredits;
  final num lifetimeBonusCredits;

  const CreditBalance({
    this.availableCredits = 0,
    this.totalCredits = 0,
    this.usedCredits = 0,
    this.lifetimePurchasedCredits = 0,
    this.lifetimeBonusCredits = 0,
  });

  static num _n(dynamic v) => (v is num) ? v : (num.tryParse('${v ?? ''}') ?? 0);

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    return CreditBalance(
      availableCredits: _n(json['available_credits']),
      totalCredits: _n(json['total_credits']),
      usedCredits: _n(json['used_credits']),
      lifetimePurchasedCredits: _n(json['lifetime_purchased_credits']),
      lifetimeBonusCredits: _n(json['lifetime_bonus_credits']),
    );
  }
}

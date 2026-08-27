import 'package:protoolbag_phr/features/expense/scan_expense_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// OCR sonucu → `hr_expense` form seed eşlemesi (title/amount/expense_date/
/// description). Ayrıştırıcı ayrı test edilir; burada eşleme sözleşmesi kilitli.
void main() {
  test('dolu fiş → tüm alanlar eşlenir', () {
    final seed = ScanExpenseScreen.expenseSeed(const ReceiptScanResult(
      merchant: 'MİGROS A.Ş.',
      total: 120.0,
      date: '2026-08-23',
      time: '14:35',
      documentNo: '0042',
      taxNumber: '1234567890',
      vatLines: [VatLine(rate: 20, amount: 20.0)],
    ));
    expect(seed['title'], 'MİGROS A.Ş.');
    expect(seed['amount'], 120.0);
    expect(seed['expense_date'], '2026-08-23');
    expect(seed['description'], contains('VKN/TCKN: 1234567890'));
    expect(seed['description'], contains('KDV %20'));
    expect(seed['description'], contains('Fiş/Belge No: 0042'));
  });

  test('satıcı yoksa başlık "Masraf"; tutar/tarih yoksa anahtar konmaz', () {
    final seed = ScanExpenseScreen.expenseSeed(const ReceiptScanResult());
    expect(seed['title'], 'Masraf');
    expect(seed.containsKey('amount'), isFalse);
    expect(seed.containsKey('expense_date'), isFalse);
  });

  group('lowConfidenceNotices (review-sheet düşük-güven işareti)', () {
    test('eşik-altı alanlar insan-okunur uyarıya çevrilir', () {
      const r = ReceiptScanResult(
          fieldConfidence: {'total': 0.4, 'date': 0.9, 'merchant': 0.3});
      final n = ScanExpenseScreen.lowConfidenceNotices(r);
      expect(n, hasLength(2)); // total + merchant (<0.6); date güvenli
      final joined = n.join(' ');
      expect(joined, contains('Tutar'));
      expect(joined, contains('İşletme'));
      expect(joined, isNot(contains('Tarih')));
    });

    test('hepsi güvenliyse boş liste', () {
      const r = ReceiptScanResult(fieldConfidence: {'total': 0.95, 'date': 0.8});
      expect(ScanExpenseScreen.lowConfidenceNotices(r), isEmpty);
    });
  });
}

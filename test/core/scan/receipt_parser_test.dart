import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Fatura/fiş ayrıştırıcı — doğruluk kalbi. TR sayı/tarih/KDV/VKN + geometri
/// (satır-içi/aynı-satır sağa-hizalı tutar) + aritmetik çapraz-kontrol.
void main() {
  group('parseTurkishAmount (TR: nokta-binlik, virgül-ondalık)', () {
    final cases = <String, double?>{
      '1.234,56': 1234.56,
      '12,50': 12.5,
      '100,00': 100.0,
      '1.234.567,89': 1234567.89,
      '1.234': 1234.0, // binlik ayıracı (3 hane)
      '12.50': 12.5, // İngilizce ondalık (2 hane)
      'TL 45,90': 45.9,
      '₺ 9,99': 9.99,
      'abc': null,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        expect(ReceiptParser.parseTurkishAmount(input), expected);
      });
    });
  });

  group('parseDate → ISO', () {
    test('23.08.2026 → 2026-08-23', () {
      expect(ReceiptParser.parseDate('TARİH: 23.08.2026'), '2026-08-23');
    });
    test('05/01/26 → 2026-01-05 (2 haneli yıl)', () {
      expect(ReceiptParser.parseDate('05/01/26'), '2026-01-05');
    });
    test('geçersiz ay (31.13.2020) → null', () {
      expect(ReceiptParser.parseDate('31.13.2020'), isNull);
    });
    test('tarih yok → null', () {
      expect(ReceiptParser.parseDate('MİGROS A.Ş.'), isNull);
    });
  });

  group('parseTime', () {
    test('SAAT 14:35 → 14:35', () {
      expect(ReceiptParser.parseTime('SAAT 14:35'), '14:35');
    });
    test('9:05 → 09:05', () {
      expect(ReceiptParser.parseTime('9:05'), '09:05');
    });
    test('geçersiz 25:99 → null', () {
      expect(ReceiptParser.parseTime('25:99'), isNull);
    });
  });

  OcrLine line(String t, {double top = 0, double left = 0, double right = 0}) =>
      OcrLine(text: t, top: top, bottom: top + 18, left: left, right: right);

  group('parse — gerçekçi fiş (aynı-satır tutar)', () {
    late ReceiptScanResult r;
    setUp(() {
      r = ReceiptParser.parse([
        line('MİGROS TİCARET A.Ş.', top: 0),
        line('VKN: 1234567890', top: 20),
        line('TARİH: 23.08.2026 SAAT: 14:35', top: 40),
        line('ARA TOPLAM        100,00', top: 100),
        line('KDV %20            20,00', top: 120),
        line('GENEL TOPLAM      120,00', top: 140),
        line('FİŞ NO: 0042', top: 160),
      ]);
    });

    test('genel toplam 120', () => expect(r.total, 120.0));
    test('ara toplam 100', () => expect(r.subTotal, 100.0));
    test('KDV oran 20 / tutar 20', () {
      expect(r.vatLines.single.rate, 20);
      expect(r.vatLines.single.amount, 20.0);
    });
    test('tarih ISO', () => expect(r.date, '2026-08-23'));
    test('saat', () => expect(r.time, '14:35'));
    test('VKN (10 hane)', () => expect(r.taxNumber, '1234567890'));
    test('satıcı ünvanı', () => expect(r.merchant, contains('MİGROS')));
    test('aritmetik tutuyor → uyarı yok', () => expect(r.warnings, isEmpty));
    test('aritmetik tutunca güven yükselir', () {
      expect(r.fieldConfidence['total'], greaterThanOrEqualTo(0.9));
    });
  });

  group('parse — aritmetik tutmuyor → uyarı', () {
    test('ara+KDV ≠ genel toplam', () {
      final r = ReceiptParser.parse([
        line('ARA TOPLAM 100,00', top: 0),
        line('KDV %20 20,00', top: 20),
        line('GENEL TOPLAM 130,00', top: 40),
      ]);
      expect(r.total, 130.0);
      expect(r.warnings, isNotEmpty);
      expect(r.fieldConfidence['total'], lessThan(0.9));
    });
  });

  group('parse — geometri: aynı satırdaki ayrı tutar (en sağdaki)', () {
    test('anahtar solda, tutar sağda, aynı centerY', () {
      final r = ReceiptParser.parse([
        const OcrLine(text: 'GENEL TOPLAM', top: 200, bottom: 220, left: 10, right: 120),
        const OcrLine(text: '150,00', top: 201, bottom: 219, left: 300, right: 380),
      ]);
      expect(r.total, 150.0);
    });
  });

  group('parse — boş / anlamsız', () {
    test('boş liste → isEmpty', () {
      final r = ReceiptParser.parse(const []);
      expect(r.isEmpty, isTrue);
    });
    test('rawText korunur', () {
      final r = ReceiptParser.parse([line('rastgele metin')], rawText: 'ham');
      expect(r.rawText, 'ham');
    });
    test('yeni alanlar varsayılan (fieldBoxes boş / imagePath null)', () {
      const r = ReceiptScanResult();
      expect(r.fieldBoxes, isEmpty);
      expect(r.imagePath, isNull);
    });
  });

  group('parse — fieldBoxes (görüntü-üstü bbox overlay eşlemesi)', () {
    test('aynı-satır anahtar+değer → her alan doğru satıra eşlenir', () {
      final merchantL = line('MİGROS TİCARET A.Ş.', top: 0);
      final vknL = line('VKN: 1234567890', top: 20);
      final dateL = line('TARİH: 23.08.2026 SAAT: 14:35', top: 40);
      final subL = line('ARA TOPLAM        100,00', top: 100);
      final totalL = line('GENEL TOPLAM      120,00', top: 140);
      final docL = line('FİŞ NO: 0042', top: 160);
      final r = ReceiptParser.parse([
        merchantL,
        vknL,
        dateL,
        subL,
        line('KDV %20            20,00', top: 120),
        totalL,
        docL,
      ]);
      // Her alanın kutusu, değeri okunan satırla aynı metni taşır.
      expect(r.fieldBoxes['total']?.text, totalL.text);
      expect(r.fieldBoxes['subTotal']?.text, subL.text);
      expect(r.fieldBoxes['date']?.text, dateL.text);
      expect(r.fieldBoxes['taxNumber']?.text, vknL.text);
      expect(r.fieldBoxes['merchant']?.text, merchantL.text);
      expect(r.fieldBoxes['documentNo']?.text, docL.text);
    });

    test('ayrı-satır tutar → kutu ANAHTAR değil DEĞER satırını gösterir', () {
      const kw = OcrLine(
          text: 'GENEL TOPLAM', top: 200, bottom: 220, left: 10, right: 120);
      const valueLine =
          OcrLine(text: '150,00', top: 201, bottom: 219, left: 300, right: 380);
      final r = ReceiptParser.parse([kw, valueLine]);
      expect(r.total, 150.0);
      // bbox okunan tutarın (sağdaki) gerçek konumunu gösterir.
      expect(r.fieldBoxes['total']?.text, '150,00');
      expect(r.fieldBoxes['total']?.left, 300);
    });

    test('okunmayan alan için kutu yok', () {
      final r = ReceiptParser.parse([line('rastgele metin', top: 0)]);
      expect(r.fieldBoxes.containsKey('total'), isFalse);
      expect(r.fieldBoxes.containsKey('date'), isFalse);
    });
  });

  group('copyWith — geometri korunur', () {
    test('imagePath eklenir, diğer alanlar aynı kalır', () {
      final base = ReceiptParser.parse([
        line('GENEL TOPLAM 120,00', top: 0),
      ]);
      final withImg = base.copyWith(imagePath: '/tmp/receipt.jpg');
      expect(withImg.imagePath, '/tmp/receipt.jpg');
      expect(withImg.total, base.total);
      expect(withImg.fieldBoxes['total']?.text, base.fieldBoxes['total']?.text);
    });
  });
}

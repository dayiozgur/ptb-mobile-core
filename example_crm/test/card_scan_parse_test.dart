import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('CardScanner.parseCardText', () {
    test('tipik kartvizit: ad + unvan + e-posta + telefon', () {
      const raw = '''
Ahmet Yılmaz
Satış Müdürü
Acme Teknoloji A.Ş.
ahmet.yilmaz@acme.com
+90 532 123 45 67
www.acme.com
''';
      final r = CardScanner.parseCardText(raw);
      expect(r.email, 'ahmet.yilmaz@acme.com');
      expect(r.phone, contains('532'));
      expect(r.firstName, 'Ahmet');
      expect(r.lastName, 'Yılmaz');
      expect(r.title, contains('Müdür'));
      expect(r.company, contains('Acme'));
      expect(r.isEmpty, isFalse);
    });

    test('isim satırı yoksa e-postadan ad.soyad türetir', () {
      const raw = '''
GLOBAL SOLUTIONS LTD
mehmet.demir@globalsolutions.com
0212 000 00 00
''';
      final r = CardScanner.parseCardText(raw);
      expect(r.email, 'mehmet.demir@globalsolutions.com');
      expect(r.firstName, 'Mehmet');
      expect(r.lastName, 'Demir');
    });

    test('boş / anlamsız metin → isEmpty', () {
      final r = CardScanner.parseCardText('====\n----');
      expect(r.isEmpty, isTrue);
    });

    test('telefon en az 7 rakam gerektirir (kısa sayı yakalanmaz)', () {
      final r = CardScanner.parseCardText('Oda 12\nDeniz Kaya\ndeniz@x.co');
      expect(r.phone, isNull);
      expect(r.email, 'deniz@x.co');
      expect(r.firstName, 'Deniz');
    });
  });

  group('CardScanner.parseCardLines (bbox/spatial doğruluk)', () {
    test('isim = EN BÜYÜK font, satır sırası değil (firma üstte olsa da)', () {
      // Kartvizit düzeni: logo/firma en üstte (küçük), isim ortada (büyük).
      // Eski "ilk satır = isim" mantığı firmayı isim sanardı; bbox ile isim
      // en büyük fonttan doğru seçilir.
      final lines = [
        const OcrLine(text: 'ACME DESIGN', top: 10, bottom: 30), // h=20 (logo)
        const OcrLine(text: 'Zeynep Ak', top: 60, bottom: 110), // h=50 (en büyük)
        const OcrLine(text: 'Satış Müdürü', top: 120, bottom: 140),
        const OcrLine(text: 'zeynep@acme.com', top: 160, bottom: 175),
      ];
      final r = CardScanner.parseCardLines(lines);
      expect(r.firstName, 'Zeynep');
      expect(r.lastName, 'Ak');
      expect(r.title, contains('Müdür'));
      // Keyword'süz marka (ALL-CAPS) firma olarak yakalanır, isim slotunu çalmaz.
      expect(r.company, 'ACME DESIGN');
      expect(r.email, 'zeynep@acme.com');
    });

    test('web sitesi ayrı alana yazılır (e-posta ile karışmaz)', () {
      final lines = [
        const OcrLine(text: 'Ali Veli', top: 10, bottom: 40),
        const OcrLine(text: 'www.aliveli.com.tr', top: 50, bottom: 65),
        const OcrLine(text: 'ali@aliveli.com.tr', top: 70, bottom: 85),
      ];
      final r = CardScanner.parseCardLines(lines);
      expect(r.firstName, 'Ali');
      expect(r.website, contains('aliveli'));
      expect(r.email, 'ali@aliveli.com.tr');
    });

    test('bbox yoksa (düz metin) üst-satır sırası korunur', () {
      // parseCardText → index'i top yapar; font eşit → ilk isim-adayı = isim.
      final r = CardScanner.parseCardText('Ayşe Kara\nProje Yöneticisi\nayse@x.com');
      expect(r.firstName, 'Ayşe');
      expect(r.lastName, 'Kara');
    });
  });
}

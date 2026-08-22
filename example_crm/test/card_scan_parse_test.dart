import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/contacts/card_scan.dart';

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
}

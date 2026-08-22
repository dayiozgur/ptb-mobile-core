import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_crm/features/contacts/contacts_service.dart';

/// Contact modeli — displayName crash-guard'ı (boş e-posta → '—', .characters
/// StateError'ı önlenir) + fromJson eşleme.
void main() {
  group('Contact.displayName', () {
    test('ad + soyad', () {
      const c = Contact(id: '1', firstName: 'Ali', lastName: 'Veli');
      expect(c.displayName, 'Ali Veli');
    });

    test('yalnız ad', () {
      const c = Contact(id: '1', firstName: 'Ali');
      expect(c.displayName, 'Ali');
    });

    test('ad yok → e-postaya düşer', () {
      const c = Contact(id: '1', email: 'ali@acme.com');
      expect(c.displayName, 'ali@acme.com');
    });

    test('ad yok + e-posta BOŞ STRING → "—" (crash-guard)', () {
      const c = Contact(id: '1', firstName: '', lastName: '', email: '');
      expect(c.displayName, '—');
      // .characters.first çağrısı StateError atmamalı:
      expect(() => c.displayName.characters.first, returnsNormally);
    });
  });

  group('Contact.fromJson', () {
    test('alanları eşler', () {
      final c = Contact.fromJson({
        'id': 'abc',
        'first_name': 'Ayşe',
        'last_name': 'Kaya',
        'email': 'ayse@x.com',
        'phone': '5551112233',
        'title': 'Müdür',
        'company_id': 'comp-1',
        'notes': 'Firma: Acme',
      });
      expect(c.id, 'abc');
      expect(c.firstName, 'Ayşe');
      expect(c.lastName, 'Kaya');
      expect(c.email, 'ayse@x.com');
      expect(c.title, 'Müdür');
      expect(c.companyId, 'comp-1');
      expect(c.displayName, 'Ayşe Kaya');
    });

    test('eksik alanlar güvenli (null/boş)', () {
      final c = Contact.fromJson({'id': 'x'});
      expect(c.firstName, '');
      expect(c.email, isNull);
      expect(c.displayName, '—');
    });
  });
}

import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
// Dahili yardımcı (barrel'da re-export edilmez) — doğrudan src yolundan import.
import 'package:protoolbag_core/src/presentation/dyn_widgets/dyn_widget_helpers.dart';

/// DynWidgetHelpers — dinamik dashboard widget'larının SAF yardımcıları
/// (config-okuma, tip-güvenli num/tarih, tr_TR biçimlendirme, renk paleti).
/// Widget pump'ı gerekmez; deterministik birim testleri.
void main() {
  setUpAll(() async {
    // formatCell/DateFormat('dd.MM.yyyy','tr_TR') tarih-sembolleri gerektirir.
    await initializeDateFormatting('tr_TR', null);
  });

  group('readString', () {
    test('değer var → string', () {
      expect(DynWidgetHelpers.readString({'t': 'Başlık'}, 't'), 'Başlık');
    });
    test('boş string → null', () {
      expect(DynWidgetHelpers.readString({'t': ''}, 't'), isNull);
    });
    test('eksik anahtar → null', () {
      expect(DynWidgetHelpers.readString({}, 't'), isNull);
    });
    test('non-string → toString', () {
      expect(DynWidgetHelpers.readString({'t': 42}, 't'), '42');
    });
  });

  group('readInt', () {
    test('int/num/string parse', () {
      expect(DynWidgetHelpers.readInt({'a': 5}, 'a'), 5);
      expect(DynWidgetHelpers.readInt({'a': 5.9}, 'a'), 5); // toInt (truncate)
      expect(DynWidgetHelpers.readInt({'a': '7'}, 'a'), 7);
    });
    test('parse edilemez / eksik → null', () {
      expect(DynWidgetHelpers.readInt({'a': 'x'}, 'a'), isNull);
      expect(DynWidgetHelpers.readInt({}, 'a'), isNull);
    });
  });

  group('readStringList', () {
    test('liste → boşları eleyerek string listesi', () {
      expect(DynWidgetHelpers.readStringList({'c': ['a', '', 'b', 3]}, 'c'),
          ['a', 'b', '3']);
    });
    test('liste değil → boş liste', () {
      expect(DynWidgetHelpers.readStringList({'c': 'x'}, 'c'), isEmpty);
      expect(DynWidgetHelpers.readStringList({}, 'c'), isEmpty);
    });
  });

  group('toNum', () {
    test('num/bool/virgüllü string', () {
      expect(DynWidgetHelpers.toNum(3), 3);
      expect(DynWidgetHelpers.toNum(true), 1);
      expect(DynWidgetHelpers.toNum(false), 0);
      expect(DynWidgetHelpers.toNum('12,5'), 12.5); // tr ondalık ','
    });
    test('null / NaN / parse-edilemez → null', () {
      expect(DynWidgetHelpers.toNum(null), isNull);
      expect(DynWidgetHelpers.toNum(double.nan), isNull);
      expect(DynWidgetHelpers.toNum('abc'), isNull);
    });
  });

  group('firstNumericKey / firstStringKey', () {
    test('firstNumericKey ilk sayısalı bulur (bool hariç)', () {
      expect(DynWidgetHelpers.firstNumericKey({'name': 'a', 'count': 5}), 'count');
      expect(DynWidgetHelpers.firstNumericKey({'flag': true, 'n': 3}), 'n');
      expect(DynWidgetHelpers.firstNumericKey({'name': 'a'}), isNull);
    });
    test('firstStringKey ilk metni, yoksa ilk anahtarı bulur', () {
      expect(DynWidgetHelpers.firstStringKey({'n': 3, 'name': 'x'}), 'name');
      expect(DynWidgetHelpers.firstStringKey({'n': 3}), 'n'); // metin yok → ilk
      expect(DynWidgetHelpers.firstStringKey({}), isNull);
    });
  });

  group('tryDate', () {
    test('ISO string / DateTime → tarih', () {
      expect(DynWidgetHelpers.tryDate('2026-09-02'), DateTime.parse('2026-09-02'));
      final now = DateTime(2026, 9, 2);
      expect(DynWidgetHelpers.tryDate(now), now);
    });
    test('kısa / geçersiz → null', () {
      expect(DynWidgetHelpers.tryDate('short'), isNull); // len<8
      expect(DynWidgetHelpers.tryDate('not-a-real-date'), isNull); // parse edilemez
      expect(DynWidgetHelpers.tryDate(42), isNull);
    });
  });

  group('formatNumber (tr_TR)', () {
    test('tam sayı → gruplu, ondalıksız', () {
      expect(DynWidgetHelpers.formatNumber(1000), '1.000');
    });
    test('ondalıklı → 2 basamak', () {
      expect(DynWidgetHelpers.formatNumber(1234.5), '1.234,50');
    });
    test('decimals + prefix + suffix', () {
      expect(DynWidgetHelpers.formatNumber(42, decimals: 0, prefix: '₺', suffix: ' KDV'),
          '₺42 KDV');
    });
  });

  group('formatCell', () {
    test('null → em-dash', () => expect(DynWidgetHelpers.formatCell(null), '—'));
    test('bool → Evet/Hayır', () {
      expect(DynWidgetHelpers.formatCell(true), 'Evet');
      expect(DynWidgetHelpers.formatCell(false), 'Hayır');
    });
    test('ISO tarih → dd.MM.yyyy', () {
      expect(DynWidgetHelpers.formatCell('2026-09-02'), '02.09.2026');
    });
    test('metin → aynen', () => expect(DynWidgetHelpers.formatCell('merhaba'), 'merhaba'));
  });

  group('resolveColors / palette', () {
    test('geçerli colors[] → parse edilmiş', () {
      final colors = DynWidgetHelpers.resolveColors({'colors': ['#FF0000', '#00FF00']});
      expect(colors, hasLength(2));
      expect(colors.first, const Color(0xFFFF0000));
    });
    test('#AARRGGBB ve int desteklenir', () {
      final colors = DynWidgetHelpers.resolveColors({'colors': ['#80FF0000', 0xFF123456]});
      expect(colors, [const Color(0x80FF0000), const Color(0xFF123456)]);
    });
    test('boş / geçersiz / eksik → varsayılan 10-renk paleti', () {
      expect(DynWidgetHelpers.resolveColors({}), DynWidgetHelpers.defaultPalette);
      expect(DynWidgetHelpers.resolveColors({'colors': []}), DynWidgetHelpers.defaultPalette);
      expect(DynWidgetHelpers.resolveColors({'colors': ['garbage']}),
          DynWidgetHelpers.defaultPalette);
    });
    test('varsayılan palet 10 renk', () {
      expect(DynWidgetHelpers.defaultPalette, hasLength(10));
    });
  });
}

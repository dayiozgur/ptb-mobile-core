import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// AppClock tenant-tz formatlama testleri. Türkiye UTC+3 (DST yok) → sabit +3.
void main() {
  setUp(() {
    AppClock.ensureInit();
    AppClock.setZone('Europe/Istanbul');
  });

  group('AppClock formatlama', () {
    test('date: UTC → İstanbul-yerel tr tarih', () {
      // 2026-01-05 12:00 UTC → 15:00 İstanbul → 05.01.2026
      expect(AppClock.date(DateTime.utc(2026, 1, 5, 12, 0)), '05.01.2026');
    });

    test('date: gün UTC→+3 ile ilerlerse doğru gün', () {
      // 2026-01-05 22:00 UTC → 01:00 (06 Oca) İstanbul
      expect(AppClock.date(DateTime.utc(2026, 1, 5, 22, 0)), '06.01.2026');
    });

    test('hm: saat +3 kaydırılır', () {
      expect(AppClock.hm(DateTime.utc(2026, 1, 5, 12, 30)), '15:30');
    });

    test('dateTime: tarih + saat', () {
      expect(AppClock.dateTime(DateTime.utc(2026, 1, 5, 12, 30)),
          '05.01.2026 15:30');
    });

    test('dayLabel: kısa tr gün + ay', () {
      // 2026-01-05 = Pazartesi
      expect(AppClock.dayLabel(DateTime.utc(2026, 1, 5, 9, 0)), 'Pzt, 5 Oca');
    });

    test('toTenant: +3 saat', () {
      final t = AppClock.toTenant(DateTime.utc(2026, 6, 15, 10, 0));
      expect(t.hour, 13); // yaz da +3 (Türkiye DST yok)
    });
  });
}

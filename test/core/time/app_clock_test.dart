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

  group('AppClock tenant iş günü (PDKS work_date)', () {
    test('todayYmd: İstanbul gece yarısı sonrası yeni gün (UTC hâlâ dün)', () {
      // 2026-10-24 21:30 UTC → 25.10 00:30 İstanbul
      expect(AppClock.todayYmd(DateTime.utc(2026, 10, 24, 21, 30)), '2026-10-25');
    });

    test('todayYmd: Berlin DST (CEST, UTC+2) — 22:30 UTC = ertesi gün', () {
      AppClock.setZone('Europe/Berlin');
      expect(AppClock.todayYmd(DateTime.utc(2026, 10, 24, 22, 30)), '2026-10-25');
    });

    test('todayYmd: Berlin kış (CET, UTC+1) — 22:30 UTC = aynı gün', () {
      AppClock.setZone('Europe/Berlin');
      expect(AppClock.todayYmd(DateTime.utc(2026, 11, 2, 22, 30)), '2026-11-02');
    });

    test('todayYmd: New York DST geçişi (2026-11-01 05:30 UTC = 00:30 EST)', () {
      AppClock.setZone('America/New_York');
      expect(AppClock.todayYmd(DateTime.utc(2026, 11, 1, 3, 30)), '2026-10-31');
      expect(AppClock.todayYmd(DateTime.utc(2026, 11, 1, 5, 30)), '2026-11-01');
    });

    test('setZone geçersiz ad → Europe/Istanbul fallback', () {
      AppClock.setZone('Not/AZone');
      expect(AppClock.zoneName, 'Europe/Istanbul');
      AppClock.setZone(null);
      expect(AppClock.zoneName, 'Europe/Istanbul');
    });

    test('todayDate: saatsiz tenant-yerel gün', () {
      final d = AppClock.todayDate(DateTime.utc(2026, 10, 24, 21, 30));
      expect([d.year, d.month, d.day, d.hour], [2026, 10, 25, 0]);
    });

    test('takvim günü (yyyy-MM-dd) saat dilimine çevrilmez', () {
      AppClock.setZone('America/New_York');
      final d = DateTime.parse('2026-10-25'); // yerel gece yarısı
      expect(AppClock.isCalendarDate(d), isTrue);
      expect(AppClock.date(d), '25.10.2026');
      expect(AppClock.isCalendarDate(DateTime.utc(2026, 10, 25)), isFalse);
    });
  });

  group('AppClock göreli / saniyeli biçim (PMS)', () {
    final now = DateTime.utc(2026, 1, 5, 21, 30); // İstanbul 06.01 00:30

    test('relativeDayTime: gün sınırı tenant saat dilimine göre', () {
      // 21:10 UTC = 06.01 00:10 İstanbul → "bugün"
      expect(
        AppClock.relativeDayTime(DateTime.utc(2026, 1, 5, 21, 10),
            today: 'Bugün', yesterday: 'Dün', now: now),
        'Bugün 00:10',
      );
      // 20:50 UTC = 05.01 23:50 İstanbul → "dün"
      expect(
        AppClock.relativeDayTime(DateTime.utc(2026, 1, 5, 20, 50),
            today: 'Bugün', yesterday: 'Dün', now: now),
        'Dün 23:50',
      );
      expect(
        AppClock.relativeDayTime(DateTime.utc(2026, 1, 2, 9, 0),
            today: 'Bugün', yesterday: 'Dün', now: now),
        '02.01 12:00',
      );
    });

    test('hms / dateTimeSeconds / format / TenantDateFormat', () {
      final t = DateTime.utc(2026, 1, 5, 12, 30, 7);
      expect(AppClock.hms(t), '15:30:07');
      expect(AppClock.dateTimeSeconds(t), '05.01.2026 15:30:07');
      expect(AppClock.format(t, 'dd/MM HH:mm:ss'), '05/01 15:30:07');
      expect(const TenantDateFormat('dd.MM.yyyy HH:mm').format(t),
          '05.01.2026 15:30');
    });
  });
}

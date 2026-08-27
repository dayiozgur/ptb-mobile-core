import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// PpmMetrics — SAF metrik hesabı (RPC/UI yok). Deterministik.
void main() {
  WorklogEntry log(double h) => WorklogEntry(id: 'x', hoursSpent: h);

  group('totalLogged', () {
    test('saatleri toplar; null 0 sayılır', () {
      expect(
        PpmMetrics.totalLogged([log(2), log(1.5), const WorklogEntry(id: 'n')]),
        3.5,
      );
    });
    test('boş → 0', () => expect(PpmMetrics.totalLogged(const []), 0.0));
  });

  group('remainingWork', () {
    test('tahmin - loglanan', () {
      expect(
        PpmMetrics.remainingWork(totalEstimate: 10, logs: [log(3), log(2)]),
        5.0,
      );
    });
    test('aşım → 0 (negatif olmaz)', () {
      expect(
        PpmMetrics.remainingWork(totalEstimate: 4, logs: [log(6)]),
        0.0,
      );
    });
  });

  group('completionRatio', () {
    test('[0..1] normalize', () {
      expect(
        PpmMetrics.completionRatio(totalEstimate: 8, logs: [log(2)]),
        0.25,
      );
    });
    test('aşımda 1\'e kırpılır', () {
      expect(
        PpmMetrics.completionRatio(totalEstimate: 4, logs: [log(10)]),
        1.0,
      );
    });
    test('totalEstimate <= 0 → 0', () {
      expect(PpmMetrics.completionRatio(totalEstimate: 0, logs: [log(3)]), 0.0);
    });
  });

  group('velocity', () {
    test('ortalama kapanan puan', () {
      expect(PpmMetrics.velocity([10, 20, 30]), 20.0);
    });
    test('boş → 0', () => expect(PpmMetrics.velocity(const []), 0.0));
  });

  group('burndown', () {
    test('ideal doğrusal iner; gerçek korunur', () {
      final s = PpmMetrics.burndown(totalScope: 30, dailyRemaining: [30, 25, 5]);
      expect(s.length, 3);
      expect(s[0].dayIndex, 0);
      expect(s[0].ideal, 30.0);
      expect(s[1].ideal, 15.0); // 30 - (30/2)*1
      expect(s[2].ideal, 0.0);
      expect(s[0].remaining, 30.0);
      expect(s[1].remaining, 25.0);
      expect(s[2].remaining, 5.0);
    });
    test('boş → []', () {
      expect(PpmMetrics.burndown(totalScope: 10, dailyRemaining: const []),
          isEmpty);
    });
    test('tek gün → ideal 0', () {
      final s = PpmMetrics.burndown(totalScope: 10, dailyRemaining: [7]);
      expect(s.single.ideal, 0.0);
      expect(s.single.remaining, 7.0);
    });
  });
}

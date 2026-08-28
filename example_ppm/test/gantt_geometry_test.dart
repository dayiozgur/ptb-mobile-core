import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_ppm/features/project/gantt_geometry.dart';

void main() {
  group('GanttGeometry.startOf', () {
    test('created_at bitişten önce → created kullanılır', () {
      final due = DateTime(2026, 8, 20);
      final created = DateTime(2026, 8, 10);
      expect(GanttGeometry.startOf(due, created), created);
    });

    test('created_at null → bitiş - 3 gün', () {
      final due = DateTime(2026, 8, 20);
      expect(GanttGeometry.startOf(due, null), DateTime(2026, 8, 17));
    });

    test('created_at bitişten sonra → bitiş - 3 gün (geç created yok sayılır)',
        () {
      final due = DateTime(2026, 8, 20);
      final created = DateTime(2026, 8, 25);
      expect(GanttGeometry.startOf(due, created), DateTime(2026, 8, 17));
    });
  });

  group('GanttGeometry.bar', () {
    final minD = DateTime(2026, 1, 1);

    test('normal aralık → orantılı left/width', () {
      // start gün25, due gün75, toplam 100 gün.
      final bar = GanttGeometry.bar(
        minD.add(const Duration(days: 25)),
        minD.add(const Duration(days: 75)),
        minD,
        100,
      );
      expect(bar.left, closeTo(0.25, 1e-9));
      expect(bar.width, closeTo(0.50, 1e-9));
    });

    test('REGRESYON: start maxD\'ye çok yakın (left>0.98) → CRASH ETMEZ', () {
      // Eski `.clamp(0.02, 1.0 - left)` burada ArgumentError fırlatırdı.
      final start = minD.add(const Duration(days: 99));
      final due = minD.add(const Duration(days: 100));
      late GanttBar bar;
      expect(() => bar = GanttGeometry.bar(start, due, minD, 100),
          returnsNormally);
      expect(bar.left, closeTo(0.99, 1e-9));
      // Üst sınır max(0.02, 0.01)=0.02 → genişlik alt-sınıra oturur.
      expect(bar.width, closeTo(0.02, 1e-9));
    });

    test('sıfır-uzunluk task → minimum genişlik (0.02) korunur', () {
      final d = minD.add(const Duration(days: 10));
      final bar = GanttGeometry.bar(d, d, minD, 100);
      expect(bar.width, closeTo(0.02, 1e-9));
    });

    test('totalDays 0 → sıfıra bölme yok (en az 1 gün varsayılır)', () {
      late GanttBar bar;
      expect(() => bar = GanttGeometry.bar(minD, minD, minD, 0),
          returnsNormally);
      expect(bar.left, 0.0);
    });

    test('left daima [0,1] içinde kalır', () {
      final bar = GanttGeometry.bar(
        minD.add(const Duration(days: 500)), // totalDays'ten büyük
        minD.add(const Duration(days: 600)),
        minD,
        100,
      );
      expect(bar.left, 1.0);
    });
  });

  group('GanttGeometry.classifyStatus', () {
    test('done/complete/tamam → done', () {
      expect(GanttGeometry.classifyStatus('Done'), GanttStatusKind.done);
      expect(GanttGeometry.classifyStatus('COMPLETED'), GanttStatusKind.done);
      expect(GanttGeometry.classifyStatus('Tamamlandı'), GanttStatusKind.done);
    });

    test('progress/devam → inProgress', () {
      expect(GanttGeometry.classifyStatus('In Progress'),
          GanttStatusKind.inProgress);
      expect(GanttGeometry.classifyStatus('Devam ediyor'),
          GanttStatusKind.inProgress);
    });

    test('block/engel → blocked', () {
      expect(GanttGeometry.classifyStatus('Blocked'), GanttStatusKind.blocked);
      expect(GanttGeometry.classifyStatus('Engellendi'),
          GanttStatusKind.blocked);
    });

    test('boş/null/bilinmeyen → neutral', () {
      expect(GanttGeometry.classifyStatus(null), GanttStatusKind.neutral);
      expect(GanttGeometry.classifyStatus(''), GanttStatusKind.neutral);
      expect(GanttGeometry.classifyStatus('Backlog'), GanttStatusKind.neutral);
    });
  });
}

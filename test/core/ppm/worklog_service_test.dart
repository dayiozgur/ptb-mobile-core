import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// WorklogService — efor yaz (`fn_ppm_log_work`) + efor listele (`ppm_worklogs`).
/// Ctor-inject (sl gerekmez). Hata → `false`/`[]` (UI'a fırlatmaz).
void main() {
  late SupabaseHarness h;
  late WorklogService service;

  setUp(() {
    h = SupabaseHarness();
    service = WorklogService(supabase: h.client);
  });

  group('logWork', () {
    test('geçerli efor → doğru payload ile RPC + true', () async {
      h.stubRpc('fn_ppm_log_work', result: null);

      final ok = await service.logWork(
        submissionId: 's1',
        hours: 2.5,
        remainingEstimate: 4,
        note: '  ilerleme  ',
      );

      expect(ok, isTrue);
      expect(h.capturedRpcParams('fn_ppm_log_work'), {
        'p_submission_id': 's1',
        'p_hours_spent': 2.5,
        'p_remaining_estimate': 4,
        'p_note': 'ilerleme', // trim edilir
      });
    });

    test('opsiyoneller yoksa payload\'da yer almaz', () async {
      h.stubRpc('fn_ppm_log_work', result: null);

      final ok = await service.logWork(submissionId: 's2', hours: 1);

      expect(ok, isTrue);
      final p = h.capturedRpcParams('fn_ppm_log_work')!;
      expect(p['p_submission_id'], 's2');
      expect(p['p_hours_spent'], 1);
      expect(p.containsKey('p_remaining_estimate'), isFalse);
      expect(p.containsKey('p_note'), isFalse);
    });

    test('boş not gönderilmez', () async {
      h.stubRpc('fn_ppm_log_work', result: null);
      await service.logWork(submissionId: 's3', hours: 1, note: '   ');
      expect(h.capturedRpcParams('fn_ppm_log_work')!.containsKey('p_note'),
          isFalse);
    });

    test('hours <= 0 → RPC çağrılmaz, false', () async {
      h.stubRpc('fn_ppm_log_work', result: null);
      expect(await service.logWork(submissionId: 's4', hours: 0), isFalse);
      expect(await service.logWork(submissionId: 's4', hours: -3), isFalse);
    });

    test('RPC hatası → false (fırlatmaz)', () async {
      h.stubRpc('fn_ppm_log_work', error: Exception('boom'));
      expect(await service.logWork(submissionId: 's5', hours: 1), isFalse);
    });
  });

  group('listWorklogs', () {
    test('satır → model eşleme (yeniden eskiye)', () async {
      h.stubFrom('ppm_worklogs', result: <Map<String, dynamic>>[
        {
          'id': 'w1',
          'submission_id': 's1',
          'hours_spent': 3,
          'remaining_estimate': 5.5,
          'note': 'analiz',
          'created_by': 'u1',
          'created_at': '2026-08-25T09:00:00Z',
        },
      ]);

      final list = await service.listWorklogs('s1');

      expect(list.length, 1);
      final w = list.first;
      expect(w.id, 'w1');
      expect(w.submissionId, 's1');
      expect(w.hoursSpent, 3.0); // int → double
      expect(w.remainingEstimate, 5.5);
      expect(w.note, 'analiz');
      expect(w.createdBy, 'u1');
      expect(w.createdAt, DateTime.parse('2026-08-25T09:00:00Z'));
    });

    test('boş sonuç → []', () async {
      h.stubFrom('ppm_worklogs', result: <Map<String, dynamic>>[]);
      expect(await service.listWorklogs('s1'), isEmpty);
    });

    test('hata → [] (fırlatmaz)', () async {
      h.stubFrom('ppm_worklogs', error: Exception('x'));
      expect(await service.listWorklogs('s1'), isEmpty);
    });
  });

  group('WorklogEntry.fromRow', () {
    test('eksik/null alanlar güvenli', () {
      final w = WorklogEntry.fromRow(const {'id': 'w2'});
      expect(w.id, 'w2');
      expect(w.hoursSpent, isNull);
      expect(w.remainingEstimate, isNull);
      expect(w.note, isNull);
      expect(w.createdAt, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../helpers/supabase_fakes.dart';

/// ErrorReportingService — sahip-altyapı crash/error reporting (web
/// ObservabilityService aynası). Tampon + fingerprint-dedup + toplu flush →
/// `log-client-error` EF. ASLA fırlatmaz; yalnız `enabled` iken ağa gönderir.
void main() {
  late SupabaseHarness h;

  setUp(() => h = SupabaseHarness());

  ErrorReportingService make({bool enabled = true, String? release}) =>
      ErrorReportingService(supabase: h.client, enabled: enabled, release: release);

  group('capture', () {
    test('geçerli hata tamponlanır', () {
      final s = make();
      s.capture(Exception('boom'), contextRef: '/crm/deals');
      expect(s.bufferLength, 1);
    });

    test('aynı fingerprint dedup penceresinde iki kez tamponlanmaz', () {
      final s = make();
      s.capture(Exception('boom'), contextRef: '/x');
      s.capture(Exception('boom'), contextRef: '/x'); // aynı mesaj+ctx → dedup
      expect(s.bufferLength, 1);
    });

    test('farklı context → ayrı fingerprint → ayrı kayıt', () {
      final s = make();
      s.capture(Exception('boom'), contextRef: '/a');
      s.capture(Exception('boom'), contextRef: '/b');
      expect(s.bufferLength, 2);
    });

    test('gürültü (IGNORED) düşürülür', () {
      final s = make();
      s.capture('A RenderFlex overflowed by 42 pixels', contextRef: '/x');
      expect(s.bufferLength, 0);
    });

    test('null/boş hata tamponlanmaz', () {
      final s = make();
      s.capture(null);
      expect(s.bufferLength, 0);
    });

    test('geçersiz level → error\'a düşer (fırlatmaz)', () {
      final s = make();
      s.capture(Exception('x'), level: 'banana', contextRef: '/x');
      expect(s.bufferLength, 1);
    });
  });

  group('flush', () {
    test('enabled + dolu tampon → log-client-error EF çağrılır, doğru gövde', () async {
      h.stubFunction('log-client-error', data: {'ok': true, 'inserted': 1});
      final s = make(release: '1.3.0');
      s.capture(Exception('boom'), contextRef: '/crm/deals');

      await s.flush();

      final body = h.capturedFunctionBody('log-client-error')!;
      final events = body['events'] as List;
      expect(events, hasLength(1));
      final ev = events.first as Map;
      expect(ev['level'], 'error');
      expect((ev['message'] as String).contains('boom'), isTrue);
      expect(ev['context_ref'], '/crm/deals');
      expect(ev['fingerprint'], isNotNull);
      expect(body['release'], '1.3.0');
      expect(s.bufferLength, 0); // gönderilenler tampondan düşer
    });

    test('disabled → ağa GİTMEZ, tampon temizlenir', () async {
      final s = make(enabled: false);
      s.capture(Exception('boom'), contextRef: '/x');
      expect(s.bufferLength, 1);

      await s.flush();

      expect(s.bufferLength, 0);
      // invoke hiç stub'lanmadı → çağrılsaydı mocktail patlardı (ağ-yok kanıtı).
    });

    test('boş tampon → no-op (EF çağrılmaz)', () async {
      final s = make();
      await s.flush(); // patlamamalı
      expect(s.bufferLength, 0);
    });

    test('EF hatası yutulur (flush fırlatmaz)', () async {
      h.stubFunction('log-client-error', error: Exception('network'));
      final s = make();
      s.capture(Exception('boom'), contextRef: '/x');
      await s.flush(); // fırlatmamalı
      expect(s.bufferLength, 0); // batch tampondan alındı
    });
  });
}

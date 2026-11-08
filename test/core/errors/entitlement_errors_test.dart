import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// WP-A: lisans reddi sınıflandırıcısı (PostgREST 25006 / PTB402, EF 402 ERR_ENTITLEMENT).
void main() {
  group('isEntitlementError — PostgrestException', () {
    test('PTB402 → locked', () {
      expect(
        isEntitlementError(const PostgrestException(
            message: 'entitlement_locked', code: 'PTB402')),
        LicenseAccessState.locked,
      );
    });

    test('mesaj entitlement_locked (kod yok) → locked', () {
      expect(
        isEntitlementError(
            const PostgrestException(message: 'entitlement_locked')),
        LicenseAccessState.locked,
      );
    });

    test('25006 read-only transaction → readOnly', () {
      expect(
        isEntitlementError(const PostgrestException(
            message: 'cannot execute INSERT in a read-only transaction',
            code: '25006')),
        LicenseAccessState.readOnly,
      );
    });

    test('ilgisiz PostgREST hatası (RLS 42501) → null', () {
      expect(
        isEntitlementError(const PostgrestException(
            message: 'new row violates row-level security policy',
            code: '42501')),
        isNull,
      );
    });
  });

  group('isEntitlementError — FunctionException', () {
    test('status 402 → readOnly', () {
      expect(
        isEntitlementError(const FunctionException(status: 402)),
        LicenseAccessState.readOnly,
      );
    });

    test('gövdede ERR_ENTITLEMENT (Map, iç içe error) → readOnly', () {
      expect(
        isEntitlementError(const FunctionException(status: 400, details: {
          'error': {'code': 'ERR_ENTITLEMENT', 'message': 'x'}
        })),
        LicenseAccessState.readOnly,
      );
    });

    test('gövdede ERR_ENTITLEMENT (JSON metin) → readOnly', () {
      expect(
        isEntitlementError(const FunctionException(
            status: 403,
            details: '{"error":{"code":"ERR_ENTITLEMENT","message":"x"}}')),
        LicenseAccessState.readOnly,
      );
    });

    test('500 → null', () {
      expect(
        isEntitlementError(
            const FunctionException(status: 500, details: {'error': 'boom'})),
        isNull,
      );
    });
  });

  group('isEntitlementError — sarmalanmış / diğer', () {
    test('AppException.originalError içindeki PTB402 → locked', () {
      expect(
        isEntitlementError(const ServerException(
          message: 'wrapped',
          originalError:
              PostgrestException(message: 'entitlement_locked', code: 'PTB402'),
        )),
        LicenseAccessState.locked,
      );
    });

    test('ServerException statusCode 402 → readOnly', () {
      expect(
        isEntitlementError(
            const ServerException(message: 'x', statusCode: 402)),
        LicenseAccessState.readOnly,
      );
    });

    test('null / düz Exception → null', () {
      expect(isEntitlementError(null), isNull);
      expect(isEntitlementError(Exception('network')), isNull);
    });
  });

  test('LicenseAccessState.fromServer', () {
    expect(LicenseAccessState.fromServer('full'), LicenseAccessState.full);
    expect(LicenseAccessState.fromServer('read_only'),
        LicenseAccessState.readOnly);
    expect(LicenseAccessState.fromServer('locked'), LicenseAccessState.locked);
    expect(LicenseAccessState.fromServer('none'), isNull);
    expect(LicenseAccessState.fromServer(null), isNull);
  });

  test('EntitlementSignals.report yalnız lisans reddinde yayınlar', () async {
    final seen = <LicenseAccessState>[];
    final sub = EntitlementSignals.stream.listen(seen.add);
    expect(EntitlementSignals.report(Exception('x')), isNull);
    expect(
      EntitlementSignals.report(
          const PostgrestException(message: 'ro', code: '25006')),
      LicenseAccessState.readOnly,
    );
    await Future<void>.delayed(Duration.zero);
    expect(seen, [LicenseAccessState.readOnly]);
    await sub.cancel();
  });
}

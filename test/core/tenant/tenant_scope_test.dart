import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/src/core/tenant/tenant_scope.dart';

void main() {
  group('TenantScope', () {
    test('falls back to the active tenant when nothing was set explicitly', () {
      String? active = 'tenant-active';
      final scope = TenantScope(activeTenantId: () => active);

      expect(scope.tenantId, 'tenant-active');
      expect(scope.explicitTenantId, isNull);

      active = 'tenant-switched';
      expect(scope.tenantId, 'tenant-switched',
          reason: 'read-through, not a snapshot');
    });

    test('explicit setTenant value wins over the active tenant', () {
      final scope = TenantScope(activeTenantId: () => 'tenant-active');

      expect(scope.set('tenant-explicit'), isTrue);
      expect(scope.tenantId, 'tenant-explicit');
      expect(scope.set('tenant-explicit'), isFalse,
          reason: 'same value → no change, callers keep their cache');
      expect(scope.set('tenant-other'), isTrue);
    });

    test('clear drops the explicit value and reads the active tenant again',
        () {
      final scope = TenantScope(activeTenantId: () => null)..set('t1');
      scope.clear();

      expect(scope.tenantId, isNull);
      expect(scope.explicitTenantId, isNull);
    });

    test('default source is null when TenantService is not registered', () {
      expect(TenantScope().tenantId, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// RouteAccess — coarse-role rota erişim kuralları (router redirect'in SAF
/// karar katmanı). Erişim-kontrolü doğruluk-kritik; her dal test edilir.
void main() {
  group('isAdminOnly', () {
    test('admin-only prefiksleri → true', () {
      expect(RouteAccess.isAdminOnly('/management/users'), isTrue);
      expect(RouteAccess.isAdminOnly('/mail-system'), isTrue);
      expect(RouteAccess.isAdminOnly('/admin'), isTrue);
      expect(RouteAccess.isAdminOnly('/system/logs'), isTrue);
    });
    test('diğer yollar → false', () {
      expect(RouteAccess.isAdminOnly('/main'), isFalse);
      expect(RouteAccess.isAdminOnly('/portal/tickets'), isFalse);
      expect(RouteAccess.isAdminOnly('/crm/deals'), isFalse);
    });
  });

  group('canAccess', () {
    test('rol null (erken boot) → her yere true (gating ertelenir)', () {
      expect(RouteAccess.canAccess(null, '/admin'), isTrue);
      expect(RouteAccess.canAccess(null, '/portal'), isTrue);
    });

    test('CUSTOMER → yalnız /portal*', () {
      expect(RouteAccess.canAccess(CoarseRoles.customer, '/portal'), isTrue);
      expect(RouteAccess.canAccess(CoarseRoles.customer, '/portal/tickets'), isTrue);
      expect(RouteAccess.canAccess(CoarseRoles.customer, '/main'), isFalse);
      expect(RouteAccess.canAccess(CoarseRoles.customer, '/admin'), isFalse);
    });

    test('admin-only yol → yalnız ADMIN', () {
      expect(RouteAccess.canAccess(CoarseRoles.admin, '/management'), isTrue);
      expect(RouteAccess.canAccess(CoarseRoles.manager, '/management'), isFalse);
      expect(RouteAccess.canAccess(CoarseRoles.user, '/system/logs'), isFalse);
    });

    test('normal yol → MANAGER/USER/ADMIN erişebilir', () {
      expect(RouteAccess.canAccess(CoarseRoles.manager, '/main'), isTrue);
      expect(RouteAccess.canAccess(CoarseRoles.user, '/crm/deals'), isTrue);
      expect(RouteAccess.canAccess(CoarseRoles.admin, '/main'), isTrue);
    });
  });

  group('deniedRedirect', () {
    test('CUSTOMER → /portal', () {
      expect(RouteAccess.deniedRedirect(CoarseRoles.customer), RouteAccess.portalPath);
    });
    test('diğer roller → /main', () {
      expect(RouteAccess.deniedRedirect(CoarseRoles.manager), '/main');
      expect(RouteAccess.deniedRedirect(CoarseRoles.user), '/main');
      expect(RouteAccess.deniedRedirect(null), '/main');
    });
  });
}

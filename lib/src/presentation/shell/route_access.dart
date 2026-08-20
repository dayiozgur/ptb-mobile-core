import 'package:flutter/foundation.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Boot/login sonrası çözülen coarse rolü tutar; router redirect'i bunu
/// senkron okur ve değişince (refreshListenable) yeniden çalışır.
///
/// Shell menüyü yükledikten sonra rolü buraya yazar. Rol null iken
/// (erken boot) rol-bazlı gating ATLANIR — yalnızca auth/tenant/org
/// yönlendirmeleri çalışır.
final ValueNotifier<String?> sessionCoarseRole = ValueNotifier<String?>(null);

/// Coarse-role rota erişim kuralları — menü `roles` filtresiyle aynı
/// vokabüleri (ROLE_ADMIN|MANAGER|USER|CUSTOMER) kullanır.
///
/// Menü SoT: admin-only yol prefiksleri, canlı `platform_menu_items` roles=
/// [ROLE_ADMIN] satırlarından türetilmiştir (PMS: management, mail-system,
/// admin, system logs, tenant-management).
class RouteAccess {
  RouteAccess._();

  /// CUSTOMER'ın erişebildiği tek alan.
  static const String portalPath = '/portal';

  /// Yalnız ROLE_ADMIN görebilen menü yol prefiksleri (menüden türetilmiş).
  static const List<String> adminOnlyPrefixes = [
    '/management',
    '/mail-system',
    '/admin',
    '/system',
  ];

  /// Kimlik doğrulama gerektirmeyen (setup) rotalar.
  static const List<String> setupPaths = [
    '/login',
    '/tenant-select',
    '/organizations',
  ];

  /// Bir yol admin-only mu?
  static bool isAdminOnly(String location) {
    return adminOnlyPrefixes.any((p) => location.startsWith(p));
  }

  /// Verilen rol bu konuma erişebilir mi?
  ///
  /// - CUSTOMER: yalnız `/portal*` (aksi halde false → portala yönlendir).
  /// - admin-only yollar: yalnız ROLE_ADMIN.
  /// - rol null (henüz çözülmedi): true (gating'i ertele).
  static bool canAccess(String? coarseRole, String location) {
    if (coarseRole == null) return true; // erken boot: erteleme

    // CUSTOMER → yalnız portal
    if (coarseRole == CoarseRoles.customer) {
      return location.startsWith(portalPath);
    }

    // Admin-only menü yolları
    if (isAdminOnly(location) && coarseRole != CoarseRoles.admin) {
      return false;
    }

    return true;
  }

  /// Erişim reddedildiğinde hedef rota.
  static String deniedRedirect(String? coarseRole) {
    if (coarseRole == CoarseRoles.customer) return portalPath;
    return '/main';
  }
}

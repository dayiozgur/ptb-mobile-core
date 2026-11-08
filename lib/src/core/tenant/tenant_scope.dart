import '../di/service_locator.dart';
import 'tenant_service.dart';

/// Servisler için tek tenant okuma kaynağı (read-through).
///
/// Eski desen: her servis kendi `_currentTenantId` alanını tutar ve
/// `setTenant` ile elle beslenir; propagasyon kaçarsa servis "tenant yok"
/// sanıp boş döner. [TenantScope] açıkça set edilen değeri korur (geriye
/// dönük uyum: `setTenant` çağıranlar aynı davranışı görür), set edilmemişse
/// aktif [TenantService.currentTenantId]'yi okur.
///
/// Sorgu semantiği değişmez — servis yine `tenantId == null` iken aynı
/// erken-dönüşü yapar; yalnız kaynak tekleşir.
class TenantScope {
  TenantScope({String? Function()? activeTenantId})
      : _active = activeTenantId ?? _fromLocator;

  final String? Function() _active;
  String? _explicit;

  static String? _fromLocator() => sl.isRegistered<TenantService>()
      ? sl<TenantService>().currentTenantId
      : null;

  /// Etkin tenant: açıkça set edilen, yoksa aktif [TenantService] tenant'ı.
  String? get tenantId => _explicit ?? _active();

  /// Yalnız `setTenant` ile açıkça verilen değer (değişim tespiti için).
  String? get explicitTenantId => _explicit;

  /// Açık tenant'ı ayarla. Değer değiştiyse `true` döner (çağıran önbelleği
  /// temizler).
  bool set(String tenantId) {
    if (_explicit == tenantId) return false;
    _explicit = tenantId;
    return true;
  }

  /// Açık tenant'ı bırak (okuma aktif [TenantService]'e düşer).
  void clear() => _explicit = null;
}

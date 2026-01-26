import 'package:dio/dio.dart';

import '../../storage/secure_storage.dart';

/// Tenant interceptor
///
/// Multi-tenant uygulamalar için isteklere tenant bilgisi ekler.
class TenantInterceptor extends Interceptor {
  final SecureStorage _storage;
  final String _headerName;

  TenantInterceptor({
    required SecureStorage storage,
    String headerName = 'X-Tenant-ID',
  })  : _storage = storage,
        _headerName = headerName;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Tenant ID ekle
    final tenantId = await _storage.getTenantId();
    if (tenantId != null) {
      options.headers[_headerName] = tenantId;
    }

    return handler.next(options);
  }
}

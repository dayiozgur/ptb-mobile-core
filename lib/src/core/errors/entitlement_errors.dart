import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'exceptions.dart';

/// Lisans erişim durumu (sunucu `fn_entitlement_state` kararının istemci karşılığı).
///
/// - [full]: normal.
/// - [readOnly]: lisans bitti, ödemesiz süre (grace) içinde. Okuma/dışa aktarma açık,
///   her yazma sunucuda reddedilir (PostgREST SQLSTATE `25006`, EF HTTP 402).
/// - [locked]: ödemesiz süre bitti (ya da platform satın alınmamış). Ürün tabloları/RPC'leri
///   402 `PTB402` döner; hesap/fatura/oturum yolları açık kalır.
enum LicenseAccessState {
  full,
  readOnly,
  locked;

  /// Sunucu metni (`'full' | 'read_only' | 'locked'`) → enum. Bilinmeyen/boş → null.
  static LicenseAccessState? fromServer(String? value) {
    switch (value) {
      case 'full':
        return LicenseAccessState.full;
      case 'read_only':
        return LicenseAccessState.readOnly;
      case 'locked':
        return LicenseAccessState.locked;
    }
    return null;
  }

  /// Yazma yapılabilir mi?
  bool get canWrite => this == LicenseAccessState.full;
}

/// PostgREST'in entitlement hook'u kilitli kiracıya döndüğü hata kodu.
const String kEntitlementLockedCode = 'PTB402';

/// Hook'un PTB402 ile birlikte döndüğü mesaj.
const String kEntitlementLockedMessage = 'entitlement_locked';

/// Postgres SQLSTATE: read-only transaction (salt-okunur kiracıya yazma).
const String kReadOnlyTransactionCode = '25006';

/// Edge Function'ların lisans reddinde döndüğü hata kodu.
const String kEntitlementEdgeCode = 'ERR_ENTITLEMENT';

/// Bir hatanın lisans (entitlement) reddi olup olmadığını sınıflandırır.
///
/// Dönüş: lisans reddi değilse `null`; aksi halde hatanın işaret ettiği durum:
/// - `PostgrestException` kod `PTB402` ya da mesaj `entitlement_locked` → [LicenseAccessState.locked]
/// - `PostgrestException` kod `25006` (read-only transaction) → [LicenseAccessState.readOnly]
/// - `FunctionException` status 402 ya da gövdede `ERR_ENTITLEMENT` →
///   [LicenseAccessState.readOnly] (EF yanıtı salt-okunur ile kilitliyi ayırt etmez;
///   kesin durum `platform-context` yenilemesinden gelir — en az iddialı varsayım budur).
/// - [AppException] ise `originalError` içine bakılır (servisler hatayı sarmalayabilir).
LicenseAccessState? isEntitlementError(Object? error) =>
    _classify(error, depth: 0);

LicenseAccessState? _classify(Object? error, {required int depth}) {
  if (error == null || depth > 3) return null;

  if (error is PostgrestException) {
    final code = error.code?.trim();
    if (code == kEntitlementLockedCode ||
        error.message.contains(kEntitlementLockedMessage)) {
      return LicenseAccessState.locked;
    }
    if (code == kReadOnlyTransactionCode ||
        error.message.contains('read-only transaction')) {
      return LicenseAccessState.readOnly;
    }
    return null;
  }

  if (error is FunctionException) {
    if (error.status == 402 || _mentionsEdgeCode(error.details)) {
      return LicenseAccessState.readOnly;
    }
    return null;
  }

  if (error is ServerException) {
    if (error.statusCode == 402 ||
        error.code == kEntitlementLockedCode ||
        error.code == kEntitlementEdgeCode) {
      return error.code == kEntitlementLockedCode
          ? LicenseAccessState.locked
          : LicenseAccessState.readOnly;
    }
  }

  if (error is AppException) {
    return _classify(error.originalError, depth: depth + 1);
  }

  return null;
}

bool _mentionsEdgeCode(Object? details) {
  if (details == null) return false;
  if (details is Map) {
    if (details['code'] == kEntitlementEdgeCode) return true;
    final nested = details['error'];
    if (nested is Map && nested['code'] == kEntitlementEdgeCode) return true;
    return false;
  }
  if (details is String) {
    if (!details.contains(kEntitlementEdgeCode)) return false;
    try {
      return _mentionsEdgeCode(jsonDecode(details));
    } catch (_) {
      return true; // düz metinde kod geçiyor
    }
  }
  return false;
}

/// Uygulama genelinde görülen lisans reddi sinyalleri.
///
/// Herhangi bir yazma yolu lisans reddi aldığında [report] çağrılır (ya da hata
/// `Logger.error/warning` ile loglandığında otomatik yakalanır — bkz.
/// `EntitlementService.start`). `EntitlementService` bu akışı dinleyip lisansı
/// yeniler, böylece salt-okunur bandı / kilit ekranı görünür.
class EntitlementSignals {
  EntitlementSignals._();

  static final StreamController<LicenseAccessState> _controller =
      StreamController<LicenseAccessState>.broadcast();

  /// Görülen lisans reddi durumları.
  static Stream<LicenseAccessState> get stream => _controller.stream;

  /// [error] lisans reddiyse sinyal yayınlar ve durumu döndürür; değilse `null`.
  static LicenseAccessState? report(Object? error) {
    final state = isEntitlementError(error);
    if (state != null) _controller.add(state);
    return state;
  }
}

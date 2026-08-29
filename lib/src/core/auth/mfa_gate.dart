import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Factor, FactorType, FactorStatus;

import '../di/service_locator.dart';
import '../utils/logger.dart';

/// Step-up durumu — router redirect'in (senkron) danışacağı tek gerçek kaynak.
///  - [none]      : engelleme yok (izin ver).
///  - [challenge] : verified TOTP faktörü var → 6-hane kod doğrulaması iste.
///  - [enroll]    : politika MFA istiyor ama verified faktör yok → kayıt iste.
enum MfaStepUp { none, challenge, enroll }

/// MFA politika zorlaması için SENKRON-okunabilir kapı (web `mfa-stepup.guard`
/// mobil karşılığı). go_router `redirect` senkron olduğundan, asenkron
/// değerlendirme login/cold-start sırasında BİR KEZ yapılır ([evaluate]) ve
/// sonucu burada saklanır; redirect yalnız bu senkron durumu okur.
///
/// FAIL-OPEN ZORUNLU SÖZLEŞME (web guard ile birebir): kapı YALNIZCA
/// POZİTİF olarak (politika rol için MFA istiyor) VE (oturum AÇIKÇA 'aal1')
/// doğrulandığında engeller. Eksik oturum/profil/politika, off/optional,
/// bilinmeyen/aal2, timeout veya HERHANGİ bir hata → izin ver ([none]).
/// Bir arama tökezlemesi kullanıcıyı ASLA kilitlememelidir.
class MfaGate {
  MfaGate._();
  static final MfaGate instance = MfaGate._();

  /// Güncel step-up kararı (varsayılan: engelleme yok).
  MfaStepUp state = MfaStepUp.none;

  /// [MfaStepUp.challenge] durumunda doğrulanacak verified TOTP faktör id'si.
  String? challengeFactorId;

  /// Her [evaluate]/[clear] çağrısında artar. App'ler bunu router'ın
  /// `refreshListenable`'ına merge ederek redirect'i yeniden tetikler.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _bump() => revision.value++;

  /// Login/cold-start sonrası MFA gereksinimini değerlendirir ve [state]'i kurar.
  ///
  /// FAIL-OPEN: tüm gövde try/catch ile sarılıdır → HERHANGİ bir hata → [none].
  /// Mantık (web `isMfaRequired` + step-up guard ile birebir):
  ///   1. tenantId null → none.
  ///   2. policy = getMfaPolicy; !isMfaRequired(policy, role) → none.
  ///   3. aal = getCurrentAal(); aal != 'aal1' (aal2/bilinmeyen/null) → none.
  ///   4. Gerekli + aal1: verified faktör varsa → challenge (verified totp id),
  ///      yoksa → enroll.
  Future<void> evaluate({
    required String? tenantId,
    required String? role,
  }) async {
    try {
      if (tenantId == null || tenantId.isEmpty) {
        _set(MfaStepUp.none);
        return;
      }

      final auth = authService;
      final policy = await auth.getMfaPolicy(tenantId);
      if (!auth.isMfaRequired(policy, role)) {
        _set(MfaStepUp.none);
        return;
      }

      final aal = await auth.getCurrentAal();
      // Yalnız AÇIKÇA 'aal1' engeller; aal2/bilinmeyen/null → izin ver.
      if (aal != 'aal1') {
        _set(MfaStepUp.none);
        return;
      }

      // MFA gerekli ve oturum aal1: faktör var mı?
      final hasVerified = await auth.hasVerifiedFactor();
      if (hasVerified) {
        final factors = await auth.listMfaFactors();
        final Factor? totp = factors.firstWhereOrNullVerifiedTotp();
        _set(MfaStepUp.challenge, factorId: totp?.id);
        return;
      }

      _set(MfaStepUp.enroll);
    } catch (e) {
      // FAIL-OPEN: değerlendirme hiçbir koşulda kullanıcıyı kilitlemez.
      Logger.warning('MfaGate.evaluate failed (fail-open → none): $e');
      _set(MfaStepUp.none);
    }
  }

  void _set(MfaStepUp next, {String? factorId}) {
    state = next;
    challengeFactorId = factorId;
    _bump();
  }

  /// Senkron redirect kararı. Engelleme yoksa null; aksi halde '/mfa-gate'.
  /// Zaten '/mfa-gate' üzerindeyse null (yönlendirme döngüsünü önler).
  String? redirectFor(String loc) {
    if (state == MfaStepUp.none) return null;
    if (loc.startsWith('/mfa-gate')) return null;
    return '/mfa-gate';
  }

  /// Step-up tamamlandığında (veya oturum kapandığında) kapıyı temizler.
  void clear() {
    state = MfaStepUp.none;
    challengeFactorId = null;
    _bump();
  }
}

extension _VerifiedTotpPick on List<Factor> {
  /// Verified + TOTP olan ilk faktör (yoksa null).
  Factor? firstWhereOrNullVerifiedTotp() {
    for (final f in this) {
      if (f.status == FactorStatus.verified && f.factorType == FactorType.totp) {
        return f;
      }
    }
    return null;
  }
}

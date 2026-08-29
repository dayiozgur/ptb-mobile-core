import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Factor, FactorType, FactorStatus;

import '../di/service_locator.dart';
import '../utils/logger.dart';

/// Step-up durumu — router redirect'in (senkron) danışacağı tek gerçek kaynak.
///  - [none]           : engelleme yok (izin ver).
///  - [challenge]      : verified TOTP faktörü var → 6-hane kod doğrulaması iste.
///  - [emailChallenge] : etkin e-posta 2FA faktörü var (TOTP yok) → e-posta ile
///    kod gönderilir → 6-hane kod doğrulaması iste.
///  - [enroll]         : politika MFA istiyor ama hiç faktör yok → kayıt iste
///    (TOTP-QR veya e-posta).
enum MfaStepUp { none, challenge, emailChallenge, enroll }

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

  /// Tenant politikası e-posta 2FA'ya izin veriyor mu? Enroll ekranı buna göre
  /// "E-posta ile kod" seçeneğini gösterir. Politika `allowed_factors` belirtmezse
  /// (null) izin verilmiş sayılır; aksi halde listede 'email' olmalıdır.
  bool policyAllowsEmail = false;

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
  ///   4. Gerekli + aal1: e-posta 2FA bu oturum için zaten tatmin edildiyse
  ///      (isEmailMfaSatisfied) → none. Aksi halde: verified TOTP faktörü varsa
  ///      → challenge (verified totp id); yoksa etkin e-posta faktörü varsa
  ///      → emailChallenge; hiçbiri yoksa → enroll.
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

      // Enroll ekranının e-posta seçeneğini gösterip göstermeyeceğini politika
      // belirler. `allowed_factors` yoksa (null) izin verilmiş sayılır.
      policyAllowsEmail = _policyAllowsEmail(policy);

      final aal = await auth.getCurrentAal();
      // Yalnız AÇIKÇA 'aal1' engeller; aal2/bilinmeyen/null → izin ver.
      if (aal != 'aal1') {
        _set(MfaStepUp.none);
        return;
      }

      // MFA gerekli ve oturum aal1. Önce e-posta 2FA bu oturum için zaten
      // tatmin edilmiş mi? (native TOTP aal2 VEYA bu oturum için geçerli
      // e-posta-doğrulaması). Tatminse engelleme yok.
      if (await auth.isEmailMfaSatisfied()) {
        _set(MfaStepUp.none);
        return;
      }

      // Doğrulanmamış: hangi ikinci faktörle step-up isteyelim?
      // 1) verified TOTP → challenge (gotrue aal2'ye yükseltir).
      final hasVerified = await auth.hasVerifiedFactor();
      if (hasVerified) {
        final factors = await auth.listMfaFactors();
        final Factor? totp = factors.firstWhereOrNullVerifiedTotp();
        _set(MfaStepUp.challenge, factorId: totp?.id);
        return;
      }

      // 2) TOTP yok ama etkin e-posta faktörü var → e-posta ile kod (ekran
      //    açılışta otomatik gönderir).
      if (await auth.emailFactorEnabled()) {
        _set(MfaStepUp.emailChallenge);
        return;
      }

      // 3) Hiç faktör yok → kayıt (ekran TOTP-QR veya e-posta seçtirir).
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

  /// Politikanın `allowed_factors`'ına bakarak e-posta faktörüne izin verilip
  /// verilmediğini belirler. null/eksik → izin var; liste 'email' içermeli.
  /// Tolerant: farklı şekilleri (List / virgüllü String) kabul eder.
  bool _policyAllowsEmail(Map<String, dynamic>? policy) {
    if (policy == null) return false;
    final raw = policy['allowed_factors'];
    if (raw == null) return true; // belirtilmemiş → izin var
    if (raw is List) {
      return raw.map((e) => e.toString().toLowerCase()).contains('email');
    }
    if (raw is String) {
      return raw.toLowerCase().contains('email');
    }
    return false;
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

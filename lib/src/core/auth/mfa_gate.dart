import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FactorType, FactorStatus;

import '../di/service_locator.dart';
import '../permission/permission_service.dart' show CoarseRoles;
import '../utils/logger.dart';
import 'mfa_requirement.dart';

/// Step-up state — the single source the (synchronous) router redirect reads.
///  - [none]           : nothing to do (let the user in).
///  - [challenge]      : a verified authenticator (TOTP) factor exists → ask
///    for its 6-digit code.
///  - [emailChallenge] : no authenticator, but a mailed code is possible (an
///    active e-mail factor, or e-mail is an allowed factor) → mail a code and
///    ask for it.
///  - [enroll]         : a second factor is required and none is set up →
///    enrolment (authenticator QR or mailed code).
///  - [unavailable]    : the requirement could not be read for a user who is
///    (or appears to be) an administrator → retry / sign-out state. Never a
///    silent pass.
enum MfaStepUp { none, challenge, emailChallenge, enroll, unavailable }

/// The operations [MfaGate] needs. Production delegates to [AuthService];
/// tests pass a fake.
abstract class MfaGateBackend {
  /// `fn_my_mfa_requirement()`. Must THROW when it cannot be read.
  Future<MfaRequirement> myRequirement();

  /// 'aal1' | 'aal2' | null (unknown).
  Future<String?> currentAal();

  /// Has this session already passed the mailed-code factor?
  Future<bool> emailSatisfied();

  /// Id of a verified authenticator (TOTP) factor, or null.
  Future<String?> verifiedTotpFactorId();

  /// Does the user have an active, verified e-mail factor?
  Future<bool> emailFactorEnabled();
}

class _AuthServiceMfaBackend implements MfaGateBackend {
  const _AuthServiceMfaBackend();

  @override
  Future<MfaRequirement> myRequirement() => authService.getMyMfaRequirement();

  @override
  Future<String?> currentAal() => authService.getCurrentAal();

  @override
  Future<bool> emailSatisfied() => authService.isEmailMfaSatisfied();

  @override
  Future<String?> verifiedTotpFactorId() async {
    final factors = await authService.listMfaFactors();
    for (final f in factors) {
      if (f.status == FactorStatus.verified &&
          f.factorType == FactorType.totp) {
        return f.id;
      }
    }
    return null;
  }

  @override
  Future<bool> emailFactorEnabled() => authService.emailFactorEnabled();
}

/// Synchronously readable second-factor gate — the mobile counterpart of the
/// web `mfa-stepup.guard`. go_router's `redirect` is synchronous, so the async
/// evaluation runs once at sign-in / cold start ([evaluate]) and the result is
/// kept here; the redirect only reads [state].
///
/// Source of truth: `fn_my_mfa_requirement()` (same as the web). Platform
/// operators and active `admin` / `super_admin` holders ALWAYS need a second
/// factor; a tenant `mfa_policy` can widen it to every member.
///
///   not required                          → none
///   required, no verified factor          → enroll
///   required, session aal2                → none
///   required, mailed code already passed  → none
///   required, otherwise                   → challenge / emailChallenge
///
/// Failure direction (identical to the web guard):
///  - administrators (the requirement says privileged, or — when the lookup
///    itself failed — the locally loaded coarse role is `ROLE_ADMIN`) fail
///    CLOSED: [MfaStepUp.unavailable], a retry / sign-out state;
///  - everyone else fails OPEN: a lookup hiccup never locks out a normal user.
class MfaGate {
  MfaGate._();
  static final MfaGate instance = MfaGate._();

  /// Upper bound for each network lookup during the evaluation, so a stalled
  /// request can never hang sign-in or cold start.
  static const Duration lookupTimeout = Duration(seconds: 8);

  /// Backend used by [evaluate] when none is passed (tests override it).
  @visibleForTesting
  MfaGateBackend backend = const _AuthServiceMfaBackend();

  /// Current step-up decision (default: nothing to do).
  MfaStepUp state = MfaStepUp.none;

  /// Verified authenticator factor to challenge in [MfaStepUp.challenge].
  String? challengeFactorId;

  /// Does the requirement allow the mailed-code factor? The enrolment screen
  /// offers "code by e-mail" only then. Always true for administrators.
  bool policyAllowsEmail = false;

  /// Whether the last evaluation saw a privileged (administrator) requirement.
  bool privileged = false;

  /// Coarse role passed to the last [evaluate] — reused by [retry].
  String? _lastRole;

  /// Incremented on every [evaluate] / [clear]. Apps merge it into the
  /// router's `refreshListenable` so the redirect runs again.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void _bump() => revision.value++;

  /// Evaluates the second-factor requirement after sign-in / cold start and
  /// sets [state]. Never throws.
  ///
  /// [role] is the locally loaded coarse role; it only matters when the
  /// requirement cannot be read (a `ROLE_ADMIN` then fails closed).
  /// [tenantId] is kept for source compatibility and is no longer used — the
  /// server function resolves the caller's tenant itself.
  Future<void> evaluate({
    String? tenantId,
    required String? role,
    MfaGateBackend? backend,
  }) async {
    _lastRole = role;
    final b = backend ?? this.backend;
    final locallyPrivileged = role == CoarseRoles.admin;
    try {
      final MfaRequirement req;
      try {
        req = await b.myRequirement().timeout(lookupTimeout);
      } catch (e) {
        Logger.warning('MfaGate: requirement unavailable '
            '(${locallyPrivileged ? 'administrator → retry state' : 'fail-open'}): $e');
        privileged = locallyPrivileged;
        _set(locallyPrivileged ? MfaStepUp.unavailable : MfaStepUp.none);
        return;
      }

      privileged = req.privileged;
      policyAllowsEmail = req.allowsEmail;

      if (!req.required) {
        _set(MfaStepUp.none);
        return;
      }

      if (!req.hasVerifiedFactor) {
        _set(MfaStepUp.enroll);
        return;
      }

      final aal = await _bounded(b.currentAal(), null);
      if (aal == 'aal2') {
        _set(MfaStepUp.none);
        return;
      }

      // The mailed code is a custom factor that never shows in the aal.
      // A failed lookup counts as "not satisfied" (at most one extra code).
      if (await _bounded(b.emailSatisfied(), false)) {
        _set(MfaStepUp.none);
        return;
      }

      // Unknown aal for a non-administrator (tenant policy only) keeps the
      // historical fail-open, as on the web.
      if (aal == null && !req.privileged) {
        _set(MfaStepUp.none);
        return;
      }

      final totpId = await _bounded<String?>(b.verifiedTotpFactorId(), null);
      if (totpId != null && totpId.isNotEmpty) {
        _set(MfaStepUp.challenge, factorId: totpId);
        return;
      }

      if (req.allowsEmail || await _bounded(b.emailFactorEnabled(), false)) {
        _set(MfaStepUp.emailChallenge);
        return;
      }

      // A verified factor exists that the app cannot challenge (e.g. a
      // passkey) and the mailed code is not allowed → offer an authenticator.
      _set(MfaStepUp.enroll);
    } catch (e) {
      Logger.warning('MfaGate.evaluate failed: $e');
      final closed = privileged || locallyPrivileged;
      _set(closed ? MfaStepUp.unavailable : MfaStepUp.none);
    }
  }

  /// Evaluates again with the role of the last [evaluate] (retry button of
  /// the [MfaStepUp.unavailable] state).
  Future<void> retry({MfaGateBackend? backend}) =>
      evaluate(role: _lastRole, backend: backend);

  Future<T> _bounded<T>(Future<T> f, T fallback) async {
    try {
      return await f.timeout(lookupTimeout);
    } catch (_) {
      return fallback;
    }
  }

  void _set(MfaStepUp next, {String? factorId}) {
    state = next;
    challengeFactorId = factorId;
    _bump();
  }

  /// Synchronous redirect decision: null when nothing is pending, otherwise
  /// '/mfa-gate' (null when already there, to avoid a loop).
  String? redirectFor(String loc) {
    if (state == MfaStepUp.none) return null;
    if (loc.startsWith('/mfa-gate')) return null;
    return '/mfa-gate';
  }

  /// Clears the gate when the step-up is complete (or on sign-out).
  void clear() {
    state = MfaStepUp.none;
    challengeFactorId = null;
    privileged = false;
    _bump();
  }
}

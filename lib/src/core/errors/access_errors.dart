import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../localization/localization_service.dart';
import 'exceptions.dart';

/// **"You are not allowed" is not an error.**
///
/// The server narrows what a role may read or write (row-level security,
/// column grants, tenant-admin-only RPCs — e.g. managers no longer have
/// tenant-wide access to staff documents, KVKK consents, performance reviews,
/// goals or the leave ledger; salary / IBAN / national-id writes are
/// tenant-admin only). When such a rule refuses a call the app must show a
/// calm, translated "no access" state — never a red "could not load — retry"
/// loop and never the raw exception text.
///
/// Reads that RLS simply filters return an EMPTY result (no exception): that is
/// the normal empty-by-design state and needs nothing from here.
class AccessErrors {
  AccessErrors._();

  /// Keyword keys.
  static const String titleKey = 'common.no_access.title';
  static const String messageKey = 'common.no_access.message';

  /// One-line text for a refused ACTION (already in the keywords table).
  static const String actionKey = 'error.no_permission';

  static final RegExp _deniedText = RegExp(
    r'permission denied|row-level security|insufficient[_ ]privilege|not authori[sz]ed|forbidden|access denied',
    caseSensitive: false,
  );

  /// Did the server refuse the call because the caller is not allowed?
  ///
  ///  * PostgREST / Postgres `42501` (insufficient_privilege: RLS violation on
  ///    a write, revoked table / column grant, an RPC that raises it);
  ///  * HTTP 403 from PostgREST or an Edge Function;
  ///  * the app's own [AuthorizationException].
  ///
  /// A 401 (expired session) is NOT "no access" — that is a sign-in problem.
  static bool isDenied(Object? error) {
    if (error == null) return false;
    if (error is PostgrestException) {
      if (error.code == '42501' || error.code == '403') return true;
      return _deniedText.hasMatch(error.message);
    }
    if (error is FunctionException) {
      if (error.status == 403) return true;
      final d = error.details;
      if (d is Map) {
        final code = d['code'];
        if (code == 'ERR_FORBIDDEN' || code == '42501') return true;
      }
      return false;
    }
    if (error is AuthorizationException) return true;
    return false;
  }

  static String _t(String key, String fallback) {
    if (!sl.isRegistered<LocalizationService>()) return fallback;
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  /// User-facing one-liner for a FAILED ACTION: the translated "no permission"
  /// text when the server refused it, else the caller's own [fallback] text.
  /// Never the raw exception (it carries SQL / policy names).
  static String actionMessage(Object? error, {required String fallback}) =>
      isDenied(error)
          ? _t(actionKey, 'You do not have permission to perform this action')
          : fallback;
}

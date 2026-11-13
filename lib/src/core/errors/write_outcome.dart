import 'access_errors.dart';

/// Result of a write that must not throw into the UI.
///
/// `denied` is kept apart from `failed` because the server now refuses writes a
/// role may not do (row-level security, permission triggers, `42501`): the UI
/// shows a calm "no permission" text for it instead of "failed — try again".
enum WriteOutcome {
  ok,
  denied,
  failed;

  bool get isOk => this == WriteOutcome.ok;

  /// `denied` for an error the server raised because the caller is not
  /// allowed ([AccessErrors.isDenied]), else `failed`.
  static WriteOutcome fromError(Object error) =>
      AccessErrors.isDenied(error) ? WriteOutcome.denied : WriteOutcome.failed;
}

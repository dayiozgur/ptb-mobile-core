import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reusable Supabase test doubles for the mobile-core service unit tests.
///
/// The real `supabase_flutter` builders (`SupabaseQueryBuilder`,
/// `PostgrestFilterBuilder`, `PostgrestTransformBuilder`) are fluent AND
/// `Future`-implementing, which makes them awkward to drive with plain
/// `mocktail` stubs. This helper provides:
///
///  * [MockSupabaseClient] / [MockGoTrueClient] / [MockFunctionsClient] /
///    [MockUser] — thin `mocktail` mocks for the injectable seams.
///  * [FakeQueryBuilder] + [FakeFilterBuilder] — hand-rolled fakes that record
///    every fluent call and resolve to a preconfigured value (or throw a
///    preconfigured error) when finally `await`ed. Generic-narrowing methods
///    (`select` / `single` / `maybeSingle`) return correctly-typed children so
///    the runtime type checks the SDK performs on `noSuchMethod` results pass.
///  * [SupabaseHarness] — wires the above together and exposes small `stubFrom`
///    / `stubRpc` / `stubFunction` helpers plus captured-argument accessors.
///
/// Deterministic: no network, no real Supabase, no timers.

// ignore_for_file: subtype_of_sealed_class

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockUser extends Mock implements User {}

/// Fake for the object returned by `client.from(table)`
/// (`SupabaseQueryBuilder` == `PostgrestQueryBuilder<dynamic>`).
///
/// `select()` returns a `PostgrestFilterBuilder<PostgrestList>`, the write
/// verbs (`insert`/`update`/`upsert`/`delete`) return
/// `PostgrestFilterBuilder<dynamic>`. All of them carry the configured
/// [result]/[error] onward so the eventual `await` resolves correctly.
class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  FakeQueryBuilder({this.result, this.error, List<Invocation>? calls})
      : calls = calls ?? <Invocation>[];

  final dynamic result;
  final Object? error;
  final List<Invocation> calls;

  FakeFilterBuilder<R> _child<R>() =>
      FakeFilterBuilder<R>(result: result, error: error, calls: calls);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    calls.add(_SyntheticInvocation(#select, [columns]));
    return _child<PostgrestList>();
  }

  @override
  PostgrestFilterBuilder<dynamic> insert(Object values,
      {bool defaultToNull = true}) {
    calls.add(_SyntheticInvocation(#insert, [values]));
    return _child<dynamic>();
  }

  @override
  PostgrestFilterBuilder<dynamic> upsert(Object values,
      {String? onConflict,
      bool ignoreDuplicates = false,
      bool defaultToNull = true}) {
    calls.add(_SyntheticInvocation(#upsert, [values]));
    return _child<dynamic>();
  }

  @override
  PostgrestFilterBuilder<dynamic> update(Map values) {
    calls.add(_SyntheticInvocation(#update, [values]));
    return _child<dynamic>();
  }

  @override
  PostgrestFilterBuilder<dynamic> delete() {
    calls.add(_SyntheticInvocation(#delete, const []));
    return _child<dynamic>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return _child<dynamic>();
  }
}

/// Fake for `PostgrestFilterBuilder<T>` (which is also a
/// `PostgrestTransformBuilder<T>` and a `Future<T>`).
///
/// Every filter/transform method (`eq`, `neq`, `or`, `inFilter`, `order`,
/// `limit`, `range`, ...) is handled by [noSuchMethod], which records the call
/// and returns `this` — valid because those methods all declare a
/// `Filter/Transform<T>` return type. The three generic-narrowing methods are
/// overridden explicitly to hand back a correctly-typed child.
class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeFilterBuilder({this.result, this.error, List<Invocation>? calls})
      : calls = calls ?? <Invocation>[];

  final dynamic result;
  final Object? error;
  final List<Invocation> calls;

  FakeFilterBuilder<R> _cast<R>() =>
      FakeFilterBuilder<R>(result: result, error: error, calls: calls);

  Future<dynamic> _future() =>
      error != null ? Future<dynamic>.error(error!) : Future<dynamic>.value(result);

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) {
    calls.add(_SyntheticInvocation(#select, [columns]));
    return _cast<PostgrestList>();
  }

  @override
  PostgrestTransformBuilder<PostgrestMap> single() {
    calls.add(_SyntheticInvocation(#single, const []));
    return _cast<PostgrestMap>();
  }

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() {
    calls.add(_SyntheticInvocation(#maybeSingle, const []));
    return _cast<PostgrestMap?>();
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return _future().then((v) => onValue(v as T), onError: onError);
  }

  @override
  Stream<T> asStream() => _future().asStream().map((v) => v as T);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) {
    return _future().then((v) => v as T).catchError(onError, test: test);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return _future().then((v) => v as T).whenComplete(action);
  }

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) {
    return _future().then((v) => v as T).timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return this;
  }
}

/// Records a synthesized fluent call (name + positional args) so tests can
/// assert on chain shape without relying on `mocktail`'s `verify` for the
/// hand-rolled fakes.
class _SyntheticInvocation implements Invocation {
  _SyntheticInvocation(this.memberName, this.positionalArguments);

  @override
  final Symbol memberName;
  @override
  final List<dynamic> positionalArguments;
  @override
  Map<Symbol, dynamic> get namedArguments => const {};
  @override
  List<Type> get typeArguments => const [];
  @override
  bool get isAccessor => false;
  @override
  bool get isGetter => false;
  @override
  bool get isMethod => true;
  @override
  bool get isSetter => false;
}

/// Convenience wrapper that wires a [MockSupabaseClient] to the fakes and the
/// auth/functions seams, with terse stub + capture helpers.
class SupabaseHarness {
  SupabaseHarness() {
    when(() => client.auth).thenReturn(auth);
    when(() => client.functions).thenReturn(functions);
    when(() => auth.currentUser).thenReturn(null);
  }

  final MockSupabaseClient client = MockSupabaseClient();
  final MockGoTrueClient auth = MockGoTrueClient();
  final MockFunctionsClient functions = MockFunctionsClient();

  /// The most recent [FakeQueryBuilder] handed out per table (so tests can read
  /// back the recorded [FakeQueryBuilder.calls]).
  final Map<String, FakeQueryBuilder> queryByTable = {};

  /// Register a signed-in user (or clear it with `id: null`).
  void stubCurrentUser({String? id}) {
    if (id == null) {
      when(() => auth.currentUser).thenReturn(null);
      return;
    }
    final user = MockUser();
    when(() => user.id).thenReturn(id);
    when(() => auth.currentUser).thenReturn(user);
  }

  /// Stub `client.from(table)` to resolve chains to [result] (or throw [error]).
  void stubFrom(String table, {dynamic result, Object? error}) {
    when(() => client.from(table)).thenAnswer((_) {
      final qb = FakeQueryBuilder(result: result, error: error);
      queryByTable[table] = qb;
      return qb;
    });
  }

  /// Stub `client.rpc(fn, ...)` (with or without params) to resolve to [result]
  /// (or throw [error]).
  void stubRpc(String fn, {dynamic result, Object? error}) {
    when(() => client.rpc<dynamic>(fn, params: any(named: 'params')))
        .thenAnswer((_) => FakeFilterBuilder<dynamic>(result: result, error: error));
    when(() => client.rpc<dynamic>(fn))
        .thenAnswer((_) => FakeFilterBuilder<dynamic>(result: result, error: error));
  }

  /// Stub `client.functions.invoke(name, ...)` to return a [FunctionResponse]
  /// with [data]/[status], or throw [error] (typically a [FunctionException]).
  void stubFunction(String name,
      {dynamic data, int status = 200, Object? error}) {
    if (error != null) {
      when(() => functions.invoke(name, body: any(named: 'body')))
          .thenThrow(error);
      return;
    }
    when(() => functions.invoke(name, body: any(named: 'body'))).thenAnswer(
      (_) async => FunctionResponse(data: data, status: status),
    );
  }

  /// The body sent to the last matching `functions.invoke(name, ...)` call.
  Map<String, dynamic>? capturedFunctionBody(String name) {
    final captured =
        verify(() => functions.invoke(name, body: captureAny(named: 'body')))
            .captured;
    if (captured.isEmpty) return null;
    return captured.last as Map<String, dynamic>?;
  }

  /// The params map sent to the last matching `client.rpc(fn, params: ...)`.
  Map<String, dynamic>? capturedRpcParams(String fn) {
    final captured =
        verify(() => client.rpc<dynamic>(fn, params: captureAny(named: 'params')))
            .captured;
    if (captured.isEmpty) return null;
    return captured.last as Map<String, dynamic>?;
  }
}

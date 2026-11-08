import '../../helpers/supabase_fakes.dart';

/// Kayıtlı fluent çağrılardan [name] olanların konumsal argümanları.
List<List<dynamic>> callsNamed(SupabaseHarness h, String table, String name) {
  final qb = h.queryByTable[table];
  if (qb == null) return const [];
  final sym = Symbol(name);
  return qb.calls
      .where((c) => c.memberName == sym)
      .map((c) => c.positionalArguments)
      .toList();
}

/// `eq(col, val)` çağrısı yapıldı mı?
bool hasEq(SupabaseHarness h, String table, String col, Object? val) =>
    callsNamed(h, table, 'eq').any((a) => a.length == 2 && a[0] == col && a[1] == val);

/// Tek bir insert payload'ı (Map).
Map<String, dynamic> insertedPayload(SupabaseHarness h, String table) {
  final ins = callsNamed(h, table, 'insert');
  return Map<String, dynamic>.from(ins.single.first as Map);
}

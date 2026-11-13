import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// `staffs` columns whose SELECT is revoked for the `authenticated` role
/// (verified on the live database, 2026-11-13). ONE of them in a select list
/// fails the whole query with 42501 — the read path for the special-category
/// ones is the RPC `fn_staff_sensitive(p_staff_id)`, for payroll identity
/// `fn_staff_personnel_get(p_staff_id)`.
const _revoked = <String>{
  'address',
  'gender',
  'marital_status',
  'blood_type',
  'military_status',
  'emergency_contact_name',
  'emergency_contact_phone',
  'emergency_contact_relation',
  'birth_date',
  'gross_salary',
  'tc_kimlik_no',
  'iban',
  'sgk_sicil_no',
  'is_partner',
};

Set<String> _columns(String select) => select
    // drop embedded resources: positions!fk(name), staffs(name, …)
    .replaceAll(RegExp(r'[\w!:]+\([^)]*\)'), '')
    .split(',')
    .map((c) => c.trim().split(':').last.trim())
    .where((c) => c.isNotEmpty)
    .toSet();

void main() {
  test('StaffService select list has no revoked column', () {
    final cols = _columns(StaffService.staffReadableColumns);
    expect(cols.intersection(_revoked), isEmpty);
    expect(cols, containsAll(<String>['id', 'name', 'email', 'phone', 'town']));
  });

  test('no `.from(\'staffs\')` query in the code base selects a revoked column '
      'or `*`', () {
    final roots = <String>[
      'lib',
      'example_pms/lib',
      'example_phr/lib',
      'example_crm/lib',
      'example_ppm/lib',
      'example_fixflow/lib',
      'example_pem/lib',
    ].where((r) => Directory(r).existsSync());

    // `.from('staffs')` … `.select(` <adjacent string literals> `)`
    final query = RegExp(
      r"\.from\(\s*'staffs'\s*\)\s*\.select\(((?:\s*(?://[^\n]*\n\s*)*'[^']*'\s*,?)*)\s*\)",
    );
    final literal = RegExp(r"'([^']*)'");
    final offenders = <String>[];
    var seen = 0;

    for (final root in roots) {
      for (final f in Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = f.readAsStringSync();
        for (final m in query.allMatches(src)) {
          seen++;
          final select =
              literal.allMatches(m.group(1)!).map((l) => l.group(1)!).join();
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          if (select.trim().isEmpty || select.trim() == '*') {
            offenders.add('${f.path}:$line selects * (42501)');
            continue;
          }
          final bad = _columns(select).intersection(_revoked);
          if (bad.isNotEmpty) offenders.add('${f.path}:$line → $bad');
        }
      }
    }
    expect(seen, greaterThan(5), reason: 'the scan must actually see queries');
    expect(offenders, isEmpty,
        reason: 'read these through fn_staff_sensitive / fn_staff_personnel_get');
  });

  test('StaffService reads through the constant (no inline column list)', () {
    final src = File('lib/src/core/staff/staff_service.dart').readAsStringSync();
    final inline = RegExp(r"\.from\('staffs'\)\s*\.select\(\s*'")
        .allMatches(src)
        .length;
    expect(inline, 0);
    expect('.select(_staffColumns)'.allMatches(src).length,
        greaterThanOrEqualTo(5),
        reason: 'reads and RETURNING selects all use the grant-safe list');
    expect(RegExp(r"\.select\(\s*\)").hasMatch(
            src.substring(0, src.indexOf('// STAFF TYPES'))),
        isFalse,
        reason: 'no `select()` (= *) on staffs');
  });
}

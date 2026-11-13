import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Screens whose hard-coded Turkish texts became keywords in mobile wave 3
/// (admin / account screens a tenant admin uses, org chart, the PPM and
/// entity write messages). Every key they ask for must have a built-in
/// tr / en / de fallback, so the screen never shows a raw key before the
/// proposed keywords are seeded (docs/proposed-sql/20261115_mobile_wave3_keywords.sql).
const _files = [
  'lib/src/presentation/shell/admin/user_management_screen.dart',
  'lib/src/presentation/shell/admin/staff_roster_screen.dart',
  'lib/src/presentation/shell/admin/roles_screen.dart',
  'lib/src/presentation/shell/admin/audit_log_screen.dart',
  'lib/src/presentation/shell/admin/subscription_screen.dart',
  'lib/src/presentation/shell/account/account_hub_screen.dart',
  'lib/src/presentation/shell/account/usage_screen.dart',
  'lib/src/presentation/shell/account/credits_screen.dart',
  'lib/src/presentation/shell/account/invoices_screen.dart',
  'lib/src/presentation/shell/orgchart/org_chart_screen.dart',
  'lib/src/presentation/shell/entities/entity_kanban_screen.dart',
  'lib/src/presentation/shell/entities/backlog_screen.dart',
  'lib/src/presentation/dynamic_form/fields/choice_fields.dart',
];

final _key = RegExp(r"""(?:_t|translate)\(\s*'([a-z0-9_]+(?:\.[a-z0-9_]+)+)'""");

void main() {
  test('wave-3 screens: every keyword has tr / en / de fallbacks', () {
    final missing = <String>[];
    for (final path in _files) {
      final src = File(path).readAsStringSync();
      final keys = _key.allMatches(src).map((m) => m.group(1)!).toSet();
      expect(keys, isNotEmpty, reason: path);
      for (final locale in [
        AppLocale.turkish,
        AppLocale.english,
        AppLocale.german,
      ]) {
        final map = AppLocalizations.getTranslations(locale);
        for (final k in keys) {
          if (!map.containsKey(k)) missing.add('$path: $k (${locale.name})');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}

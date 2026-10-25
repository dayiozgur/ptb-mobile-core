import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Guard: a literal `translate('a.b')` / `.tr('a.b')` call without a fallback
/// shows the RAW KEY when the keyword is missing from the DB. Every such key
/// must exist in the static fallback map (tr + en) so the UI never shows a
/// raw dotted key (web parity: keywords DB, dotted keys).
void main() {
  test('literal translate() keys exist in the tr/en fallback maps', () {
    final tr = AppLocalizations.getTranslations(AppLocale.turkish);
    final en = AppLocalizations.getTranslations(AppLocale.english);
    final pattern =
        RegExp(r"(?:translate|\.tr)\(\s*'([a-z0-9_]+(?:\.[a-z0-9_]+)+)'");

    final roots = <String>[
      'lib',
      'example_pms/lib',
      'example_phr/lib',
      'example_crm/lib',
      'example_ppm/lib',
    ].where((r) => Directory(r).existsSync());

    final missing = <String>{};
    for (final root in roots) {
      for (final f in Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final m in pattern.allMatches(f.readAsStringSync())) {
          final key = m.group(1)!;
          if (!tr.containsKey(key) || !en.containsKey(key)) {
            missing.add('$key (${f.path})');
          }
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'Add these keys to app_localizations.dart (and keywords DB)');
  });
}

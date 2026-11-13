import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Ratchet against new hard-coded Turkish UI texts** in the shared screens
/// (`lib/src/presentation`).
///
/// UI texts come from the keywords table (`translate(key)`, with the built-in
/// tr / en / de fallbacks in `app_localizations.dart`). A string literal that
/// contains a Turkish-specific letter (ç ğ ı ö ş ü and capitals) is counted
/// per file, except:
///  * comments;
///  * a fallback literal right after a dotted key literal
///    (`_t('crm.contact.title', 'Kişi')`, also when the formatter moved it to
///    the next line) — the key is what is shown when it is seeded;
///  * log / exception messages (`Logger.`, `debugPrint`, `Exception(`).
///
/// Turkish words written without those letters ("Ayarlar") are not seen; the
/// check is a cheap heuristic, not a parser. It never asks for more than the
/// baseline in `turkish_literals_baseline.json`: a file may only go down.
/// When a file goes down, lower its number (or run with
/// `UPDATE_TR_BASELINE=1` to rewrite the baseline).
void main() {
  test('no new hard-coded Turkish literals in lib/src/presentation', () {
    final counts = scanTurkishLiterals(Directory('lib/src/presentation'));
    final baselineFile = File('test/lint/turkish_literals_baseline.json');

    if (Platform.environment['UPDATE_TR_BASELINE'] == '1') {
      final sorted = Map.fromEntries(
          counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      baselineFile.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
      return;
    }

    final baseline = (jsonDecode(baselineFile.readAsStringSync()) as Map)
        .map((k, v) => MapEntry(k as String, v as int));
    final grown = <String>[];
    counts.forEach((file, n) {
      final allowed = baseline[file] ?? 0;
      if (n > allowed) grown.add('$file: $n (baseline $allowed)');
    });
    expect(grown, isEmpty,
        reason: 'New hard-coded Turkish UI text. Use a keyword with tr/en/de '
            'fallbacks in app_localizations.dart and add the key to the '
            'proposed keywords SQL.\n${grown.join('\n')}');
  });
}

final RegExp _turkish = RegExp('[çğıöşüÇĞİÖŞÜ]');
final RegExp _literal = RegExp(r"'(?:[^'\\\n]|\\.)*'" r'|"(?:[^"\\\n]|\\.)*"');
final RegExp _keyBefore =
    RegExp(r"""['"][a-z0-9_]+(\.[a-z0-9_]+)+['"]\s*,\s*$""");

/// file path → number of counted literals (files with zero are omitted).
Map<String, int> scanTurkishLiterals(Directory root) {
  final out = <String, int>{};
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final lines = f.readAsLinesSync();
    var n = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
      if (line.contains('Logger.') ||
          line.contains('debugPrint') ||
          line.contains('Exception(')) {
        continue;
      }
      for (final m in _literal.allMatches(line)) {
        final before = line.substring(0, m.start);
        // A trailing `// comment` (quotes balanced before it) ends the code.
        final slash = before.indexOf('//');
        if (slash >= 0 &&
            "'".allMatches(before.substring(0, slash)).length.isEven &&
            '"'.allMatches(before.substring(0, slash)).length.isEven) {
          break;
        }
        if (!_turkish.hasMatch(m.group(0)!)) continue;
        final prev = before.trim().isEmpty && i > 0 ? lines[i - 1] : before;
        if (_keyBefore.hasMatch(prev)) continue;
        // Continuation line of a multi-line fallback string.
        if (before.trim().isEmpty &&
            i > 0 &&
            _literal.hasMatch(lines[i - 1]) &&
            lines[i - 1].trimRight().endsWith("'")) {
          continue;
        }
        n++;
      }
    }
    if (n > 0) out[f.path] = n;
  }
  return out;
}

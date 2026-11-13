import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:protoolbag_core/protoolbag_core.dart';

import '../helpers/widget_test_helpers.dart';

/// Relative times come from the keywords in the UI language; dates and
/// numbers follow the UI language instead of a fixed Turkish locale.
void main() {
  final now = DateTime(2026, 11, 14, 12);

  setUpAll(() async {
    for (final l in AppLocale.values) {
      await initializeDateFormatting(l.intlLocale, null);
    }
  });

  tearDown(() async {
    Intl.defaultLocale = null;
    await sl.reset();
  });

  test('AppLocale.intlLocale (English = en_GB, as on the web)', () {
    expect(AppLocale.turkish.intlLocale, 'tr_TR');
    expect(AppLocale.english.intlLocale, 'en_GB');
    expect(AppLocale.german.intlLocale, 'de_DE');
    expect(AppLocale.italian.intlLocale, 'it_IT');
  });

  test('without a localization service: English texts', () {
    expect(
        RelativeTime.past(now.subtract(const Duration(minutes: 5)), now: now),
        '5 minutes ago');
    expect(RelativeTime.past(now.subtract(const Duration(days: 1)), now: now),
        'Yesterday');
    expect(RelativeTime.future(now.add(const Duration(hours: 2)), now: now),
        'In 2 hours');
    expect(RelativeTime.duration(const Duration(minutes: 90)), '1 h 30 min');
  });

  test('Turkish and German texts from the built-in fallbacks', () {
    registerFake<LocalizationService>(buildFakeLocalization(
        overrides: AppLocalizations.getTranslations(AppLocale.turkish)));
    expect(
        RelativeTime.past(now.subtract(const Duration(minutes: 5)), now: now),
        '5 dakika önce');
    expect(RelativeTime.past(now.subtract(const Duration(days: 14)), now: now),
        '2 hafta önce');

    registerFake<LocalizationService>(buildFakeLocalization(
        overrides: AppLocalizations.getTranslations(AppLocale.german),
        locale: AppLocale.german));
    expect(RelativeTime.past(now.subtract(const Duration(hours: 3)), now: now),
        'vor 3 Stunden');
  });

  test('Formatters and DateTime extensions follow Intl.defaultLocale', () {
    final d = DateTime(2026, 8, 3);
    Intl.defaultLocale = AppLocale.turkish.intlLocale;
    expect(d.formattedLong, '3 Ağustos 2026');
    expect(Formatters.number(1234567), '1.234.567');

    Intl.defaultLocale = AppLocale.english.intlLocale;
    expect(d.formattedLong, '3 August 2026');
    expect(Formatters.number(1234567), '1,234,567');

    Intl.defaultLocale = AppLocale.german.intlLocale;
    expect(d.formattedLong, '3. August 2026');
  });
}

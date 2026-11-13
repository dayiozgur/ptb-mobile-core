import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_phr/features/ess/ess_common.dart';

/// Pure ESS formatting/label helpers (ess_common.dart). These need neither the
/// service locator (essT) nor tenant-clock init, so they are asserted directly —
/// the STORY-0088 "app testleri" gap. Dates and numbers follow the UI language
/// (Intl.defaultLocale); the tests pin it.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });
  setUp(() => Intl.defaultLocale = 'tr_TR');
  tearDown(() => Intl.defaultLocale = null);

  group('essMoney', () {
    test('formats Turkish currency (₺, . thousands, , decimals)', () {
      expect(essMoney(1234.56), '₺1.234,56');
    });
    test('pads to two decimals', () {
      expect(essMoney(5), '₺5,00');
    });
    test('zero', () {
      expect(essMoney(0), '₺0,00');
    });
    test('follows the UI language (English separators)', () {
      Intl.defaultLocale = 'en_GB';
      expect(essMoney(1234.56), '₺1,234.56');
    });
  });

  group('essMonthYear', () {
    test('valid month+year → Turkish month name', () {
      expect(essMonthYear(2026, 8), 'Ağustos 2026');
      expect(essMonthYear(2026, 1), 'Ocak 2026');
      expect(essMonthYear(2026, 12), 'Aralık 2026');
    });
    test('English UI → English month name', () {
      Intl.defaultLocale = 'en_GB';
      expect(essMonthYear(2026, 8), 'August 2026');
    });
    test('null year → joins available parts', () {
      expect(essMonthYear(null, 8), '8');
    });
    test('out-of-range month → falls back (no crash)', () {
      expect(essMonthYear(2026, 13), '13/2026');
      expect(essMonthYear(2026, 0), '0/2026');
    });
  });

  // No LocalizationService registered → the built-in English texts.
  group('essDuration', () {
    test('minutes only', () => expect(essDuration(45), '45 min'));
    test('whole hours', () => expect(essDuration(120), '2 h'));
    test('hours + minutes', () => expect(essDuration(90), '1 h 30 min'));
    test('zero / negative → 0', () {
      expect(essDuration(0), '0 s');
      expect(essDuration(-5), '0 s');
    });
  });

  group('essStatusVariant', () {
    test('success family', () {
      expect(essStatusVariant('approved'), AppBadgeVariant.success);
      expect(essStatusVariant('COMPLETED'),
          AppBadgeVariant.success); // case-insensitive
      expect(essStatusVariant('active'), AppBadgeVariant.success);
    });
    test('info family', () {
      expect(essStatusVariant('pending'), AppBadgeVariant.info);
      expect(essStatusVariant('in_progress'), AppBadgeVariant.info);
    });
    test('warning family', () {
      expect(essStatusVariant('on_hold'), AppBadgeVariant.warning);
      expect(essStatusVariant('review'), AppBadgeVariant.warning);
    });
    test('error family', () {
      expect(essStatusVariant('rejected'), AppBadgeVariant.error);
      expect(essStatusVariant('failed'), AppBadgeVariant.error);
    });
    test('unknown / null → neutral', () {
      expect(essStatusVariant('something_else'), AppBadgeVariant.neutral);
      expect(essStatusVariant(null), AppBadgeVariant.neutral);
    });
  });

  group('essStatusLabel (sl-free branches)', () {
    test('unknown status passes through unchanged', () {
      expect(essStatusLabel('custom_code'), 'custom_code');
    });
    test('null → dash', () {
      expect(essStatusLabel(null), '-');
    });
  });

  group('essDateRange (null branches, no clock)', () {
    test('both null → dash', () {
      expect(essDateRange(null, null), '-');
    });
  });
}

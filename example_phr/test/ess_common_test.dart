import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:protoolbag_phr/features/ess/ess_common.dart';

/// Pure ESS formatting/label helpers (ess_common.dart). These need neither the
/// service locator (essT) nor tenant-clock init, so they are asserted directly —
/// the STORY-0088 "app testleri" gap. Currency/number symbols are embedded in
/// intl for tr_TR, so essMoney is deterministic without initializeDateFormatting.
void main() {
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
  });

  group('essMonthYear', () {
    test('valid month+year → Turkish month name', () {
      expect(essMonthYear(2026, 8), 'Ağustos 2026');
      expect(essMonthYear(2026, 1), 'Ocak 2026');
      expect(essMonthYear(2026, 12), 'Aralık 2026');
    });
    test('null year → joins available parts', () {
      expect(essMonthYear(null, 8), '8');
    });
    test('out-of-range month → falls back (no crash)', () {
      expect(essMonthYear(2026, 13), '13/2026');
      expect(essMonthYear(2026, 0), '0/2026');
    });
  });

  group('essDuration', () {
    test('minutes only', () => expect(essDuration(45), '45dk'));
    test('whole hours', () => expect(essDuration(120), '2s'));
    test('hours + minutes', () => expect(essDuration(90), '1s 30dk'));
    test('zero / negative → 0dk', () {
      expect(essDuration(0), '0dk');
      expect(essDuration(-5), '0dk');
    });
  });

  group('essStatusVariant', () {
    test('success family', () {
      expect(essStatusVariant('approved'), AppBadgeVariant.success);
      expect(essStatusVariant('COMPLETED'), AppBadgeVariant.success); // case-insensitive
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

import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('AppVersionGate.compare', () {
    test('numeric, not lexicographic', () {
      expect(AppVersionGate.compare('1.10.0', '1.9.3'), greaterThan(0));
      expect(AppVersionGate.compare('1.2', '1.2.0'), 0);
      expect(AppVersionGate.compare('1.2.0+45', '1.2.0'), 0);
      expect(AppVersionGate.compare('1.2.0-beta', '1.2.1'), lessThan(0));
      expect(AppVersionGate.compare('2.0.0', '10.0.0'), lessThan(0));
    });
  });

  group('AppVersionGate.evaluate', () {
    test('no row / no column / empty value → no minimum (no-op)', () {
      expect(AppVersionGate.evaluate('1.0.0', null).updateRequired, isFalse);
      expect(AppVersionGate.evaluate('1.0.0', {'brand_name': 'X'}).updateRequired,
          isFalse);
      expect(
          AppVersionGate.evaluate('1.0.0', {AppVersionGate.configKey: ' '})
              .updateRequired,
          isFalse);
    });

    test('below minimum → update required; equal/above → ok', () {
      final row = {AppVersionGate.configKey: '1.4.0'};
      expect(AppVersionGate.evaluate('1.3.9', row).updateRequired, isTrue);
      expect(AppVersionGate.evaluate('1.4.0', row).updateRequired, isFalse);
      expect(AppVersionGate.evaluate('1.5.0', row).updateRequired, isFalse);
    });
  });
}

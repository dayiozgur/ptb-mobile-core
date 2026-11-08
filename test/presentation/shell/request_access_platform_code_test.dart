import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// WP-D: erişim talebi `platform_code` = aktif platform (sabit 'PMS' değil).
void main() {
  test('aktif platform kodu kullanılır (örnek app main() setActivePlatform)', () {
    final ctx = PlatformContext()..setActivePlatform('crm-id', code: 'CRM');
    expect(resolveAccessRequestPlatformCode(ctx), 'CRM');
  });

  test('kod büyük harfe normalize edilir', () {
    final ctx = PlatformContext()..setActivePlatform('x', code: 'fixflow');
    expect(resolveAccessRequestPlatformCode(ctx), 'FIXFLOW');
  });

  test('PMS app (setActivePlatform çağırmaz) → PlatformContext varsayılanı PMS', () {
    expect(resolveAccessRequestPlatformCode(PlatformContext()), 'PMS');
    expect(PlatformContext().activePlatformId, PlatformContext.pmsPlatformId);
  });

  test('PlatformContext yok / boş kod → PMS geri dönüşü', () {
    expect(resolveAccessRequestPlatformCode(null), 'PMS');
    expect(
        resolveAccessRequestPlatformCode(
            PlatformContext(initialPlatformCode: '  ')),
        'PMS');
  });
}

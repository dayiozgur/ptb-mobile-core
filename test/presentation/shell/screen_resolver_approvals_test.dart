import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// WP-D: PMS/CRM/FixFlow DB menülerinin onay öğesi `/workflow/approvals`
/// generic onay-inbox'a çözülür; `/fixflow/approvals` çekirdekte YOK (FixFlow
/// modülü kendisi kaydeder).
MenuItem _item(String path) => MenuItem(itemKey: path, title: path, path: path);

void main() {
  setUp(ScreenResolver.reset);

  for (final path in ['/workflow/approvals', '/workflow/inbox', '/approvals']) {
    test('$path → ApprovalsInboxScreen', () {
      expect(ScreenResolver.resolve(_item(path)), isA<ApprovalsInboxScreen>());
      expect(ScreenResolver.hasScreen(path), isTrue);
    });
  }

  test('büyük/küçük harf duyarsız', () {
    expect(ScreenResolver.resolve(_item('/Workflow/Approvals')),
        isA<ApprovalsInboxScreen>());
  });

  test('/fixflow/approvals çekirdekte generic inbox DEĞİL', () {
    expect(ScreenResolver.resolve(_item('/fixflow/approvals')),
        isNot(isA<ApprovalsInboxScreen>()));
  });

  test('kayıtlı domain resolver (ör. PHR izin onayı) önce kazanır', () {
    const marker = ComingSoonScreen(titleKey: 'phr', path: '/workflow/approvals');
    ScreenResolver.addResolver(
        (i) => i.path == '/workflow/approvals' ? marker : null);
    expect(identical(ScreenResolver.resolve(_item('/workflow/approvals')), marker),
        isTrue);
  });
}

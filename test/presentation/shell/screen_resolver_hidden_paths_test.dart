import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Domain çözümleyicilerin "mobilde gizli" ilan ettiği yollar: çekirdeğin
/// `/admin*` nötr yedeği (ComingSoon) bunları menüye SOKMAZ.
MenuItem _item(String path) => MenuItem(itemKey: path, title: path, path: path);

void main() {
  setUp(ScreenResolver.reset);
  tearDown(ScreenResolver.reset);

  test('without registration the /admin fallback makes the path visible', () {
    expect(ScreenResolver.hasScreen('/admin/energy/tariffs'), isTrue);
    expect(ScreenResolver.isHiddenOnMobile('/admin/energy/tariffs'), isFalse);
  });

  test('hidden path → hasScreen false (pruned from menus)', () {
    ScreenResolver.hideOnMobile(['/admin/energy/tariffs']);
    expect(ScreenResolver.hasScreen('/admin/energy/tariffs'), isFalse);
    // normalization: case, query, trailing slash
    expect(ScreenResolver.hasScreen('/Admin/Energy/Tariffs/?x=1'), isFalse);
    // exact match only — siblings / children still use the fallback
    expect(ScreenResolver.hasScreen('/admin/energy/bills'), isTrue);
    expect(ScreenResolver.hasScreen('/admin/energy/tariffs/new'), isTrue);
  });

  test('a domain resolver that maps the path still wins', () {
    ScreenResolver.hideOnMobile(['/admin/energy/tariffs']);
    ScreenResolver.addResolver(
        (i) => i.path == '/admin/energy/tariffs' ? const SizedBox() : null);
    expect(ScreenResolver.hasScreen('/admin/energy/tariffs'), isTrue);
    expect(ScreenResolver.resolve(_item('/admin/energy/tariffs')),
        isA<SizedBox>());
  });

  test('resolving a hidden path never crashes → generic ComingSoon', () {
    ScreenResolver.hideOnMobile(['/admin/energy/tariffs']);
    final w = ScreenResolver.resolve(_item('/admin/energy/tariffs'));
    expect(w, isA<ComingSoonScreen>());
    expect((w as ComingSoonScreen).titleKey, '/admin/energy/tariffs',
        reason: 'item title, not the neutral nav.admin fallback');
  });

  test('reset clears hidden paths', () {
    ScreenResolver.hideOnMobile(['/admin/x']);
    ScreenResolver.reset();
    expect(ScreenResolver.isHiddenOnMobile('/admin/x'), isFalse);
  });
}

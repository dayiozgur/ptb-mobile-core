import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/src/core/platform/builder_platform_filter.dart';
import 'package:protoolbag_core/src/core/reporting/page_service.dart';

import '../../helpers/supabase_fakes.dart';

void main() {
  const pid = 'f0113c6e-8000-4298-a07c-0fd90e406a7a';

  group('BuilderPlatformFilter', () {
    test('orFilter mirrors the web filter string', () {
      expect(
        BuilderPlatformFilter.orFilter(pid),
        'platform_id.eq.$pid,'
        'and(platform_id.is.null,or(platform_ids.is.null,platform_ids.cs.{$pid}))',
      );
    });

    test('scopedOnlyOrFilter excludes shared-with-all rows (entity menu)', () {
      expect(
        BuilderPlatformFilter.scopedOnlyOrFilter(pid),
        'platform_id.eq.$pid,'
        'and(platform_id.is.null,platform_ids.cs.{$pid})',
      );
    });

    test('known platform → single or() with exclusive/all/listed branches', () {
      final q = FakeFilterBuilder<dynamic>();
      BuilderPlatformFilter.apply(q, pid);
      expect(q.calls, hasLength(1));
      expect(q.calls.single.memberName, #or);
      expect(q.calls.single.positionalArguments.first,
          BuilderPlatformFilter.orFilter(pid));
    });

    for (final unknown in <String?>[null, '']) {
      test('unknown platform ($unknown) → shared-to-all rows only', () {
        final q = FakeFilterBuilder<dynamic>();
        BuilderPlatformFilter.apply(q, unknown);
        expect(q.calls.map((c) => c.memberName), [#isFilter, #isFilter]);
        expect(q.calls.map((c) => c.positionalArguments),
            [['platform_id', null], ['platform_ids', null]]);
      });
    }
  });

  group('PageService.getByCode', () {
    test('uses the builder platform filter on pb_page_templates', () async {
      final h = SupabaseHarness();
      h.stubFrom('pb_page_templates', result: null);
      await PageService(h.client).getByCode('home', platformId: pid);
      final calls = h.queryByTable['pb_page_templates']!.calls;
      final or = calls.where((c) => c.memberName == #or).toList();
      expect(or, hasLength(1));
      expect(or.single.positionalArguments.first,
          BuilderPlatformFilter.orFilter(pid));
    });
  });
}

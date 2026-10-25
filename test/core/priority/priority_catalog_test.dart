import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Canlı `priorities` tablosunun şekli (platform + pasif UNDEFINED + carel
/// vendor satırları). Kurallar web `alarm-priorities.service.ts` ile aynı.
List<Priority> _rows() => [
      for (final j in <Map<String, dynamic>>[
        {'id': 'p-crit', 'code': 'critical', 'name': 'Kritik', 'color': '#DC3545', 'level': 1, 'vendor': null, 'active': true, 'priority_class': 'severity'},
        {'id': 'p-high', 'code': 'high', 'name': 'Yüksek', 'color': '#FD7E14', 'level': 2, 'vendor': null, 'active': true, 'priority_class': 'severity'},
        {'id': 'p-low', 'code': 'low', 'name': 'Düşük', 'color': '#198754', 'level': 4, 'vendor': null, 'active': true, 'priority_class': 'severity'},
        {'id': 'p-tech', 'code': 'technical', 'name': 'Teknik', 'color': '#6c757d', 'level': null, 'vendor': null, 'active': true, 'priority_class': 'technical'},
        {'id': 'p-undef', 'code': 'UNDEFINED', 'name': 'Undefined', 'color': '#8dcfb3', 'level': null, 'vendor': null, 'active': null, 'priority_class': 'severity'},
        {'id': 'c-vh', 'code': 'VERYHIGH', 'name': 'Very High', 'color': '#ce6d6a', 'level': 1, 'vendor': 'carel', 'vendor_level': 1, 'active': null, 'priority_class': 'severity'},
        {'id': 'c-tech', 'code': 'TECHNICAL', 'name': 'Technical', 'color': '#839bda', 'level': 0, 'vendor': 'carel', 'vendor_level': 0, 'active': null, 'priority_class': 'technical'},
        {'id': 'c-med', 'code': 'MEDIUM', 'name': 'Medium', 'color': '#facb86', 'level': 3, 'vendor': 'carel', 'vendor_level': 3, 'active': null, 'priority_class': 'severity'},
      ])
        Priority.fromJson(j),
    ];

void main() {
  final catalog = PriorityCatalog(_rows());

  test('platform: yalnız vendor IS NULL AND active=true, severity level sırası + teknik sonda', () {
    expect(catalog.platform.map((p) => p.id).toList(),
        ['p-crit', 'p-high', 'p-low', 'p-tech']);
  });

  test('resolve: vendor satırı vendor_level ile platform satırına eşlenir', () {
    expect(catalog.resolve('c-vh')?.id, 'p-crit');
    expect(catalog.resolve('p-high')?.id, 'p-high');
  });

  test('resolve: eşleşmeyen teknik vendor satırı platform teknik satırına düşer', () {
    expect(catalog.resolve('c-tech')?.id, 'p-tech');
  });

  test('resolve: platformda karşılığı olmayan / pasif / bilinmeyen → null', () {
    expect(catalog.resolve('c-med'), isNull); // platform medium yok
    expect(catalog.resolve('p-undef'), isNull); // active NULL
    expect(catalog.resolve('nope'), isNull);
    expect(catalog.resolve(null), isNull);
  });

  test('renk YALNIZ color kolonu; çözülemeyen → nötr gri (severity türetilmez)', () {
    expect(catalog.colorOf('c-vh'), const Color(0xFFDC3545));
    expect(catalog.colorOf('c-med'), AppColors.systemGray);
    const noColor = Priority(id: 'x', code: 'critical', level: 1);
    expect(noColor.displayColor, AppColors.systemGray);
  });

  test('etiket: alarm.priority.<code> çevirisi, yoksa satır adı', () {
    String tr(String k) => {'alarm.priority.critical': 'Critical'}[k] ?? k;
    expect(catalog.labelOf('c-vh', tr), 'Critical');
    expect(catalog.resolve('p-high')!.localizedLabel(tr), 'Yüksek');
    expect(catalog.labelOf('c-med', tr), 'alarm.priority.undefined');
    expect(priorityLabelKey('  HIGH '), 'alarm.priority.high');
    expect(priorityLabelKey(null), 'alarm.priority.undefined');
  });

  test('resolvedMap + distinctSorted: ham id → platform; tekil liste', () {
    final m = catalog.resolvedMap();
    expect(m['c-vh']?.id, 'p-crit');
    expect(m.containsKey('c-med'), isFalse);
    expect(PriorityCatalog.distinctSorted(m.values).map((p) => p.id).toList(),
        ['p-crit', 'p-high', 'p-low', 'p-tech']);
  });

  test('cache roundtrip (toJson → fromJson) vendor/active bilgisini korur', () {
    final again = PriorityCatalog(_rows().map((p) => Priority.fromJson(p.toJson())));
    expect(again.platform.map((p) => p.id).toList(),
        ['p-crit', 'p-high', 'p-low', 'p-tech']);
    expect(again.resolve('c-vh')?.id, 'p-crit');
  });
}

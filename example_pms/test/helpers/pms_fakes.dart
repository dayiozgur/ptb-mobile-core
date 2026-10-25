import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// PMS widget testleri için mocktail dublörleri + sl kayıt yardımcıları.
/// Gerçek Supabase / ağ / zamanlayıcı yok; fikstürler `DateTime.utc` ile
/// saat-dilimi bağımsızdır (CI TZ=UTC).

class MockLocalizationService extends Mock implements LocalizationService {}

class MockAlarmService extends Mock implements AlarmService {}

class MockPriorityService extends Mock implements PriorityService {}

class MockRealtimeService extends Mock implements RealtimeService {}

class MockTenantService extends Mock implements TenantService {}

class MockOrganizationService extends Mock implements OrganizationService {}

class MockSiteService extends Mock implements SiteService {}

class MockControllerService extends Mock implements ControllerService {}

class MockVariableService extends Mock implements VariableService {}

class MockIoTLogService extends Mock implements IoTLogService {}

/// Bilinen anahtarlar için sabit metin; diğerleri anahtarın kendisi (+params).
MockLocalizationService fakeLocalization([Map<String, String> table = const {}]) {
  final loc = MockLocalizationService();
  when(() => loc.translate(any(), params: any(named: 'params')))
      .thenAnswer((inv) {
    final key = inv.positionalArguments.first as String;
    var text = table[key] ?? key;
    final params = inv.namedArguments[#params] as Map<String, dynamic>?;
    params?.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  });
  when(() => loc.translate(any())).thenAnswer((inv) {
    final key = inv.positionalArguments.first as String;
    return table[key] ?? key;
  });
  when(() => loc.currentLocale).thenReturn(AppLocale.turkish);
  return loc;
}

void registerFake<T extends Object>(T instance) {
  if (sl.isRegistered<T>()) sl.unregister<T>();
  sl.registerSingleton<T>(instance);
}

/// Canlı `priorities` şekli: platform critical/high + carel VERYHIGH (level 1).
List<Priority> fixturePriorities() => [
      Priority.fromJson(const {
        'id': 'p-crit', 'code': 'critical', 'name': 'Kritik', 'color': '#DC3545',
        'level': 1, 'vendor': null, 'active': true, 'priority_class': 'severity',
      }),
      Priority.fromJson(const {
        'id': 'p-high', 'code': 'high', 'name': 'Yüksek', 'color': '#FD7E14',
        'level': 2, 'vendor': null, 'active': true, 'priority_class': 'severity',
      }),
      Priority.fromJson(const {
        'id': 'c-vh', 'code': 'VERYHIGH', 'name': 'Very High', 'color': '#ce6d6a',
        'level': 1, 'vendor': 'carel', 'vendor_level': 1, 'active': null,
        'priority_class': 'severity',
      }),
    ];

const kCritical = Color(0xFFDC3545);
const kHigh = Color(0xFFFD7E14);

/// Test sarmalayıcısı (MaterialApp + Scaffold messenger).
Widget wrap(Widget child) => MaterialApp(home: child);

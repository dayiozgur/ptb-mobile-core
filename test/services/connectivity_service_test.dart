import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  // API drift: `ConnectivityState` was renamed to `ConnectivityInfo` and its
  // `connectionType` field is now `type`; it gained a `checkedAt` timestamp and
  // lost the `copyWith`/equality/`ConnectionType.hasConnection` helpers. The
  // `online` factory now takes a named `type:` argument. `ConnectionType` and
  // `ConnectivityStatus` are now plain enums (no `.value`/`.isWifi`/`.isOnline`
  // getters), so those checks are expressed against `ConnectivityInfo` instead.
  group('ConnectivityStatus', () {
    test('has expected members', () {
      expect(ConnectivityStatus.values, contains(ConnectivityStatus.online));
      expect(ConnectivityStatus.values, contains(ConnectivityStatus.offline));
      expect(ConnectivityStatus.values, contains(ConnectivityStatus.unknown));
    });
  });

  group('ConnectionType', () {
    test('has expected members', () {
      expect(ConnectionType.values, contains(ConnectionType.wifi));
      expect(ConnectionType.values, contains(ConnectionType.mobile));
      expect(ConnectionType.values, contains(ConnectionType.ethernet));
      expect(ConnectionType.values, contains(ConnectionType.none));
      expect(ConnectionType.values, contains(ConnectionType.unknown));
    });
  });

  group('ConnectivityInfo', () {
    test('creates correctly', () {
      final info = ConnectivityInfo(
        status: ConnectivityStatus.online,
        type: ConnectionType.wifi,
        checkedAt: DateTime(2024, 1, 15),
      );

      expect(info.status, ConnectivityStatus.online);
      expect(info.type, ConnectionType.wifi);
    });

    test('isOnline returns correct value', () {
      final onlineInfo = ConnectivityInfo.online(type: ConnectionType.wifi);
      expect(onlineInfo.isOnline, true);

      final offlineInfo = ConnectivityInfo.offline();
      expect(offlineInfo.isOnline, false);
    });

    test('isOffline returns correct value', () {
      final onlineInfo = ConnectivityInfo.online(type: ConnectionType.wifi);
      expect(onlineInfo.isOffline, false);

      final offlineInfo = ConnectivityInfo.offline();
      expect(offlineInfo.isOffline, true);
    });

    test('unknown factory creates unknown state', () {
      final info = ConnectivityInfo.unknown();

      expect(info.status, ConnectivityStatus.unknown);
      expect(info.type, ConnectionType.unknown);
      expect(info.isOnline, false);
      expect(info.isOffline, false);
    });

    test('online factory creates online state', () {
      final info = ConnectivityInfo.online(type: ConnectionType.wifi);

      expect(info.status, ConnectivityStatus.online);
      expect(info.type, ConnectionType.wifi);
    });

    test('offline factory creates offline state', () {
      final info = ConnectivityInfo.offline();

      expect(info.status, ConnectivityStatus.offline);
      expect(info.type, ConnectionType.none);
    });

    test('toString returns descriptive string', () {
      final info = ConnectivityInfo(
        status: ConnectivityStatus.online,
        type: ConnectionType.wifi,
        checkedAt: DateTime(2024, 1, 15),
      );

      final str = info.toString();

      expect(str.contains('online'), true);
      expect(str.contains('wifi'), true);
    });
  });
}

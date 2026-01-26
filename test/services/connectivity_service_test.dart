import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('ConnectivityStatus', () {
    test('has correct values', () {
      expect(ConnectivityStatus.online.isOnline, true);
      expect(ConnectivityStatus.offline.isOnline, false);
      expect(ConnectivityStatus.unknown.isOnline, false);
    });

    test('isOffline returns correct value', () {
      expect(ConnectivityStatus.online.isOffline, false);
      expect(ConnectivityStatus.offline.isOffline, true);
      expect(ConnectivityStatus.unknown.isOffline, false);
    });
  });

  group('ConnectionType', () {
    test('has correct values', () {
      expect(ConnectionType.wifi.value, 'wifi');
      expect(ConnectionType.mobile.value, 'mobile');
      expect(ConnectionType.ethernet.value, 'ethernet');
      expect(ConnectionType.none.value, 'none');
    });

    test('isWifi returns correct value', () {
      expect(ConnectionType.wifi.isWifi, true);
      expect(ConnectionType.mobile.isWifi, false);
    });

    test('isMobile returns correct value', () {
      expect(ConnectionType.mobile.isMobile, true);
      expect(ConnectionType.wifi.isMobile, false);
    });

    test('hasConnection returns correct value', () {
      expect(ConnectionType.wifi.hasConnection, true);
      expect(ConnectionType.mobile.hasConnection, true);
      expect(ConnectionType.ethernet.hasConnection, true);
      expect(ConnectionType.none.hasConnection, false);
    });
  });

  group('ConnectivityState', () {
    test('creates correctly', () {
      final state = ConnectivityState(
        status: ConnectivityStatus.online,
        connectionType: ConnectionType.wifi,
      );

      expect(state.status, ConnectivityStatus.online);
      expect(state.connectionType, ConnectionType.wifi);
    });

    test('isOnline returns correct value', () {
      final onlineState = ConnectivityState(
        status: ConnectivityStatus.online,
        connectionType: ConnectionType.wifi,
      );
      expect(onlineState.isOnline, true);

      final offlineState = ConnectivityState(
        status: ConnectivityStatus.offline,
        connectionType: ConnectionType.none,
      );
      expect(offlineState.isOnline, false);
    });

    test('isOffline returns correct value', () {
      final onlineState = ConnectivityState(
        status: ConnectivityStatus.online,
        connectionType: ConnectionType.wifi,
      );
      expect(onlineState.isOffline, false);

      final offlineState = ConnectivityState(
        status: ConnectivityStatus.offline,
        connectionType: ConnectionType.none,
      );
      expect(offlineState.isOffline, true);
    });

    test('copyWith creates correct copy', () {
      final state = ConnectivityState(
        status: ConnectivityStatus.online,
        connectionType: ConnectionType.wifi,
      );

      final copy = state.copyWith(
        status: ConnectivityStatus.offline,
      );

      expect(copy.status, ConnectivityStatus.offline);
      expect(copy.connectionType, ConnectionType.wifi);
    });

    test('unknown factory creates unknown state', () {
      final state = ConnectivityState.unknown();

      expect(state.status, ConnectivityStatus.unknown);
      expect(state.connectionType, ConnectionType.none);
    });

    test('online factory creates online state', () {
      final state = ConnectivityState.online(ConnectionType.wifi);

      expect(state.status, ConnectivityStatus.online);
      expect(state.connectionType, ConnectionType.wifi);
    });

    test('offline factory creates offline state', () {
      final state = ConnectivityState.offline();

      expect(state.status, ConnectivityStatus.offline);
      expect(state.connectionType, ConnectionType.none);
    });

    test('equality works correctly', () {
      final state1 = ConnectivityState(
        status: ConnectivityStatus.online,
        connectionType: ConnectionType.wifi,
      );
      final state2 = ConnectivityState(
        status: ConnectivityStatus.online,
        connectionType: ConnectionType.wifi,
      );
      final state3 = ConnectivityState(
        status: ConnectivityStatus.offline,
        connectionType: ConnectionType.none,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('toString returns descriptive string', () {
      final state = ConnectivityState(
        status: ConnectivityStatus.online,
        connectionType: ConnectionType.wifi,
      );

      final str = state.toString();

      expect(str.contains('online'), true);
      expect(str.contains('wifi'), true);
    });
  });
}

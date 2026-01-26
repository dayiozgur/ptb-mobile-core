import 'dart:async';
import 'dart:io';

import '../utils/logger.dart';

/// Bağlantı durumu
enum ConnectivityStatus {
  /// Online - İnternet bağlantısı var
  online,

  /// Offline - İnternet bağlantısı yok
  offline,

  /// Unknown - Bağlantı durumu bilinmiyor
  unknown,
}

/// Bağlantı türü
enum ConnectionType {
  /// WiFi bağlantısı
  wifi,

  /// Mobil veri bağlantısı
  mobile,

  /// Ethernet bağlantısı
  ethernet,

  /// Bağlantı yok
  none,

  /// Bilinmiyor
  unknown,
}

/// Bağlantı bilgisi
class ConnectivityInfo {
  final ConnectivityStatus status;
  final ConnectionType type;
  final DateTime checkedAt;

  const ConnectivityInfo({
    required this.status,
    required this.type,
    required this.checkedAt,
  });

  factory ConnectivityInfo.unknown() => ConnectivityInfo(
        status: ConnectivityStatus.unknown,
        type: ConnectionType.unknown,
        checkedAt: DateTime.now(),
      );

  factory ConnectivityInfo.offline() => ConnectivityInfo(
        status: ConnectivityStatus.offline,
        type: ConnectionType.none,
        checkedAt: DateTime.now(),
      );

  factory ConnectivityInfo.online({ConnectionType type = ConnectionType.unknown}) =>
      ConnectivityInfo(
        status: ConnectivityStatus.online,
        type: type,
        checkedAt: DateTime.now(),
      );

  bool get isOnline => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;

  @override
  String toString() =>
      'ConnectivityInfo(status: $status, type: $type, checkedAt: $checkedAt)';
}

/// Bağlantı servisi
///
/// İnternet bağlantısını izler ve durumu raporlar.
///
/// Örnek kullanım:
/// ```dart
/// final connectivity = ConnectivityService();
/// await connectivity.initialize();
///
/// // Anlık kontrol
/// final isOnline = await connectivity.checkConnectivity();
///
/// // Stream ile dinleme
/// connectivity.statusStream.listen((info) {
///   print('Bağlantı durumu: ${info.status}');
/// });
/// ```
class ConnectivityService {
  // State
  ConnectivityInfo _currentInfo = ConnectivityInfo.unknown();
  Timer? _periodicCheckTimer;
  bool _isInitialized = false;

  // Stream controllers
  final _statusController = StreamController<ConnectivityInfo>.broadcast();

  // Config
  Duration _checkInterval = const Duration(seconds: 30);
  List<String> _testHosts = ['google.com', '8.8.8.8', 'cloudflare.com'];
  Duration _timeout = const Duration(seconds: 5);

  // ============================================
  // GETTERS
  // ============================================

  /// Mevcut bağlantı bilgisi
  ConnectivityInfo get currentInfo => _currentInfo;

  /// Online mı?
  bool get isOnline => _currentInfo.isOnline;

  /// Offline mı?
  bool get isOffline => _currentInfo.isOffline;

  /// Bağlantı durumu stream'i
  Stream<ConnectivityInfo> get statusStream => _statusController.stream;

  /// Başlatıldı mı?
  bool get isInitialized => _isInitialized;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Servisi başlat
  ///
  /// [checkInterval] - Periyodik kontrol aralığı
  /// [testHosts] - Test edilecek host listesi
  /// [timeout] - Bağlantı test timeout'u
  Future<void> initialize({
    Duration? checkInterval,
    List<String>? testHosts,
    Duration? timeout,
  }) async {
    if (_isInitialized) return;

    if (checkInterval != null) _checkInterval = checkInterval;
    if (testHosts != null) _testHosts = testHosts;
    if (timeout != null) _timeout = timeout;

    // İlk kontrol
    await checkConnectivity();

    // Periyodik kontrol başlat
    _startPeriodicCheck();

    _isInitialized = true;
    Logger.info('ConnectivityService initialized');
  }

  void _startPeriodicCheck() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(_checkInterval, (_) {
      checkConnectivity();
    });
  }

  // ============================================
  // CONNECTIVITY CHECK
  // ============================================

  /// Bağlantı durumunu kontrol et
  ///
  /// Birden fazla host'a bağlanmayı dener.
  /// Herhangi birine bağlanabilirse online kabul edilir.
  Future<bool> checkConnectivity() async {
    try {
      for (final host in _testHosts) {
        try {
          final result = await InternetAddress.lookup(host).timeout(_timeout);
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            _updateStatus(ConnectivityInfo.online());
            return true;
          }
        } catch (_) {
          // Bu host'a bağlanamadı, sonrakini dene
          continue;
        }
      }

      // Hiçbir host'a bağlanamadı
      _updateStatus(ConnectivityInfo.offline());
      return false;
    } catch (e) {
      Logger.error('Connectivity check failed', e);
      _updateStatus(ConnectivityInfo.offline());
      return false;
    }
  }

  /// Belirli bir URL'e bağlantı kontrolü
  Future<bool> checkUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final result = await InternetAddress.lookup(uri.host).timeout(_timeout);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _updateStatus(ConnectivityInfo newInfo) {
    final oldStatus = _currentInfo.status;
    _currentInfo = newInfo;

    // Sadece durum değiştiğinde bildir
    if (oldStatus != newInfo.status) {
      Logger.info('Connectivity changed: ${oldStatus.name} -> ${newInfo.status.name}');
      _statusController.add(newInfo);
    }
  }

  // ============================================
  // RETRY HELPER
  // ============================================

  /// Online olana kadar bekle
  ///
  /// [maxWait] - Maksimum bekleme süresi
  /// [checkInterval] - Kontrol aralığı
  Future<bool> waitForConnection({
    Duration maxWait = const Duration(minutes: 5),
    Duration checkInterval = const Duration(seconds: 5),
  }) async {
    if (isOnline) return true;

    final completer = Completer<bool>();
    Timer? timeoutTimer;
    StreamSubscription? subscription;

    // Timeout timer
    timeoutTimer = Timer(maxWait, () {
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    // Status dinle
    subscription = statusStream.listen((info) {
      if (info.isOnline) {
        timeoutTimer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    // Periyodik kontrol
    Timer.periodic(checkInterval, (timer) async {
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }
      await checkConnectivity();
    });

    return completer.future;
  }

  /// Fonksiyonu online olunca çalıştır
  ///
  /// Eğer online ise hemen çalıştırır.
  /// Offline ise online olunca çalıştırır.
  Future<T?> executeWhenOnline<T>(
    Future<T> Function() action, {
    Duration maxWait = const Duration(minutes: 5),
  }) async {
    if (isOnline) {
      return await action();
    }

    final connected = await waitForConnection(maxWait: maxWait);
    if (connected) {
      return await action();
    }

    return null;
  }

  // ============================================
  // CLEANUP
  // ============================================

  /// Servisi durdur
  void dispose() {
    _periodicCheckTimer?.cancel();
    _statusController.close();
    _isInitialized = false;
    Logger.debug('ConnectivityService disposed');
  }
}

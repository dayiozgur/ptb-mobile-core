import 'dart:async';

import 'package:flutter/foundation.dart';

import '../di/service_locator.dart';
import '../utils/logger.dart';
import 'realtime_service.dart';

/// **Realtime yenileme yardımcısı** — bir tabloya postgres-changes aboneliği
/// kurup, değişimde (insert/update/delete) debounce'lu SESSİZ yeniden-yükleme
/// tetikler. Liste/inbox ekranlarına canlı-yenileme eklemek için tek satırlık
/// adopsiyon (aksi halde her ekran subscribe/debounce/dispose'u kopyalıyordu).
///
/// Kullanım:
/// ```dart
/// final _rt = RealtimeRefresher();
/// // initState:
/// _rt.start(table: 'form_submissions', onChange: () { if (mounted) _load(silent: true); });
/// // dispose:
/// _rt.dispose();
/// ```
class RealtimeRefresher {
  static int _seq = 0;

  final Duration debounce;
  final String _key = 'rr${_seq++}'; // benzersiz channel (ekran-başı bağımsız)
  String? _subId;
  Timer? _timer;

  RealtimeRefresher({this.debounce = const Duration(milliseconds: 800)});

  /// [table] değişimlerine abone ol; her değişimde [onChange] (debounce'lu).
  /// Zaten aboneyse yok sayar. Hata olursa sessizce geçer (canlı-yenileme
  /// opsiyoneldir — manuel pull-to-refresh her hâlde çalışır).
  void start({
    required String table,
    required VoidCallback onChange,
    String? filter,
  }) {
    if (_subId != null) return;
    try {
      final sub = sl<RealtimeService>().subscribe<Map<String, dynamic>>(
        table: table,
        filter: filter,
        channelKey: _key,
        fromJson: (m) => m,
        onChange: (_) {
          _timer?.cancel();
          _timer = Timer(debounce, onChange);
        },
      );
      _subId = sub.id;
    } catch (e) {
      Logger.warning('RealtimeRefresher start hata ($table): $e');
    }
  }

  void dispose() {
    _timer?.cancel();
    final id = _subId;
    if (id != null) sl<RealtimeService>().unsubscribe(id);
    _subId = null;
  }
}

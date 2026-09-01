import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../platform/platform_context.dart';

/// Tek yakalanmış çalışma-zamanı hatası (`error_events` satırının istemci-yüzü).
/// Web `ObservabilityService.CapturedEvent` ile birebir alan seti.
class CapturedError {
  final String level; // 'error' | 'warn' | 'fatal'
  final String message;
  final String? stack;
  final String? contextRef;
  final String? fingerprint;
  final Map<String, dynamic> meta;

  const CapturedError({
    required this.level,
    required this.message,
    this.stack,
    this.contextRef,
    this.fingerprint,
    this.meta = const {},
  });

  Map<String, dynamic> toJson() => {
        'level': level,
        'message': message,
        if (stack != null) 'stack': stack,
        if (contextRef != null) 'context_ref': contextRef,
        if (fingerprint != null) 'fingerprint': fingerprint,
        'meta': meta,
      };
}

/// **Mobil crash/error reporting** — sahip-altyapı (harici APM yok), web
/// `ObservabilityService` (packages/app-shell) aynası. Yakalanan çalışma-zamanı
/// hataları tamponlanır, fingerprint ile tekilleştirilir ve toplu olarak
/// `log-client-error` Edge Function'ına gönderilir (sunucu tenant/user'ı
/// JWT'den türetir, `error_events`'e service_role ile yazar — tablo
/// istemci-INSERT'e RLS ile KAPALI, tek yol bu EF'tir).
///
/// SERT KURALLAR (web ile aynı):
///  - ASLA fırlatmaz — loglama uygulamayı kıramaz; her yol try/catch korumalı.
///  - Yalnız [enabled] iken (varsayılan `kReleaseMode`) ağa gönderir; debug'da
///    tamponu düşürür (gürültü/maliyet yok) → testte `enabled: true` ile zorla.
///  - Best-effort: dedup penceresi + tampon-cap + batch-cap hacmi sınırlar;
///    ağ hatasında sessizce düşer.
///
/// GLOBAL YAKALAMA (gözlemleyici, akışı DEĞİŞTİRMEZ): [installGlobalHandlers]
///  - `FlutterError.onError` → yakala + (debug) `presentError` ile yine bas.
///  - `PlatformDispatcher.instance.onError` → yakala + `false` dön (platform
///    varsayılan davranışı korunur; hata "yutulmaz").
///  - Periyodik flush timer'ı.
class ErrorReportingService {
  final SupabaseClient _supabase;
  final bool enabled;
  final String? release;

  ErrorReportingService({
    required SupabaseClient supabase,
    bool? enabled,
    this.release,
  })  : _supabase = supabase,
        enabled = enabled ?? kReleaseMode;

  static const int _maxBuffer = 30;
  static const int _batch = 50;
  static const Duration _flushEvery = Duration(seconds: 10);
  static const Duration _dedupWindow = Duration(seconds: 60);
  static const int _seenCap = 200;

  final List<CapturedError> _buffer = [];
  final Map<String, DateTime> _seen = {}; // fingerprint -> son yakalama
  bool _started = false;
  bool _flushing = false;
  Timer? _timer;

  /// Çerçeve/framework gürültüsü — eyleme-dönük olmayan bilinen zararsızlar.
  static const List<String> _ignored = [
    'A RenderFlex overflowed',
    'setState() called after dispose',
    'Looking up a deactivated widget',
    'mouse_tracker',
  ];

  @visibleForTesting
  int get bufferLength => _buffer.length;

  /// Bir çalışma-zamanı hatası yakala. Her yerden güvenle çağrılabilir; asla
  /// fırlatmaz. [contextRef] = ekran/route etiketi (fingerprint'e girer).
  void capture(
    Object? error, {
    StackTrace? stackTrace,
    String level = 'error',
    String? contextRef,
    Map<String, dynamic>? extraMeta,
  }) {
    try {
      _ensureStarted();
      final lvl = const {'error', 'warn', 'fatal'}.contains(level) ? level : 'error';
      final message = _messageOf(error);
      if (message.isEmpty) return;
      if (_ignored.any(message.contains)) return;

      final stack = stackTrace?.toString();
      final fingerprint = _hash('$message|${contextRef ?? ''}');

      final now = DateTime.now();
      final last = _seen[fingerprint];
      if (last != null && now.difference(last) < _dedupWindow) return; // yakın tekrar → atla
      _remember(fingerprint, now);

      if (_buffer.length >= _maxBuffer) _buffer.removeAt(0);
      _buffer.add(CapturedError(
        level: lvl,
        message: message.length > 2000 ? message.substring(0, 2000) : message,
        stack: stack != null && stack.length > 8000 ? stack.substring(0, 8000) : stack,
        contextRef: contextRef == null || contextRef.length <= 500
            ? contextRef
            : contextRef.substring(0, 500),
        fingerprint: fingerprint,
        meta: {'platform': _platformName(), ...?extraMeta},
      ));
    } catch (_) {
      /* observability ASLA fırlatmamalı */
    }
  }

  /// Tamponu ingest EF'ine boşalt. Fire-and-forget; tüm hataları yutar.
  Future<void> flush() async {
    if (_flushing || _buffer.isEmpty) return;
    if (!enabled) {
      _buffer.clear(); // debug: asla gönderme
      return;
    }
    _flushing = true;
    final batch = _buffer.take(_batch).toList();
    _buffer.removeRange(0, batch.length);
    try {
      await _supabase.functions.invoke('log-client-error', body: {
        'events': batch.map((e) => e.toJson()).toList(),
        'platform_code': _platformCode(),
        if (release != null) 'release': release,
      });
    } catch (_) {
      /* ağ hatasında düş — loglama uygulamayı kırmaz */
    } finally {
      _flushing = false;
    }
  }

  /// Global hata yakalayıcıları (gözlemleyici) + periyodik flush'ı kur.
  /// Idempotent. Akışı DEĞİŞTİRMEZ (mevcut varsayılan davranış korunur).
  void installGlobalHandlers() {
    _ensureStarted();
    final priorFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      capture(
        details.exception,
        stackTrace: details.stack,
        level: 'fatal',
        contextRef: details.library,
        extraMeta: {'kind': 'FlutterError'},
      );
      // Mevcut davranışı koru: debug'da yine konsola bas / önceki handler.
      if (priorFlutterOnError != null) {
        priorFlutterOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    final priorPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      capture(error, stackTrace: stack, extraMeta: {'kind': 'PlatformDispatcher'});
      // false → hata "yutulmadı"; platform/zone varsayılanı yine çalışır.
      return priorPlatformOnError?.call(error, stack) ?? false;
    };
  }

  void _ensureStarted() {
    if (_started) return;
    _started = true;
    try {
      _timer = Timer.periodic(_flushEvery, (_) => unawaited(flush()));
    } catch (_) {
      /* timer kurulamazsa yalnız manuel flush */
    }
  }

  void _remember(String fp, DateTime now) {
    _seen[fp] = now;
    if (_seen.length > _seenCap) {
      final oldest = _seen.keys.first;
      _seen.remove(oldest);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  static String _messageOf(Object? error) {
    if (error == null) return '';
    final s = error.toString().trim();
    return s.startsWith('Instance of ') ? error.runtimeType.toString() : s;
  }

  String? _platformCode() {
    try {
      return sl.isRegistered<PlatformContext>()
          ? sl<PlatformContext>().activePlatformCode
          : null;
    } catch (_) {
      return null;
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // ios / android / ...
  }

  /// Stabil 32-bit hash (web `ObservabilityService.hash` aynası: 31-mul).
  static String _hash(String s) {
    int h = 0;
    for (int i = 0; i < s.length; i++) {
      h = (0x1fffffff & (h * 31)) + s.codeUnitAt(i);
      h &= 0xffffffff;
    }
    return h.toRadixString(16);
  }
}

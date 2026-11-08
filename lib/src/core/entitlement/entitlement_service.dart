import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/offline_sync_service.dart';
import '../errors/entitlement_errors.dart';
import '../platform/platform_context.dart';
import '../tenant/tenant_model.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';

/// `platform-context` Edge Function'ının `license` nesnesi (salt-okuma görüntü modeli).
///
/// Sunucu şekli (`supabase/functions/platform-context/index.ts`):
/// `{ accessState?, graceUntil?, isActive, isTrial, status, subscribedAt, trialStartsAt,
///    trialEndsAt, expiresAt, autoUpgrade, customLimits, lockedVersionId,
///    plan: { plan_code, plan_name, price_monthly } | null }`.
/// `accessState`/`graceUntil` sunucu okuyamadığında YOKTUR.
@immutable
class PlatformLicense {
  /// Ham sunucu kararı: `'full' | 'read_only' | 'locked' | 'none'` ya da null.
  final String? accessStateRaw;
  final DateTime? graceUntil;
  final bool isActive;
  final bool isTrial;

  /// `platform_tenants.status` (ör. `active | trial | suspended | expired`).
  final String? status;
  final DateTime? subscribedAt;
  final DateTime? trialStartsAt;
  final DateTime? trialEndsAt;
  final DateTime? expiresAt;
  final String? planCode;
  final String? planName;
  final num? priceMonthly;

  const PlatformLicense({
    this.accessStateRaw,
    this.graceUntil,
    this.isActive = false,
    this.isTrial = false,
    this.status,
    this.subscribedAt,
    this.trialStartsAt,
    this.trialEndsAt,
    this.expiresAt,
    this.planCode,
    this.planName,
    this.priceMonthly,
  });

  /// Sunucu kararı (enum). `none`/yok → null.
  LicenseAccessState? get serverAccessState =>
      LicenseAccessState.fromServer(accessStateRaw);

  /// Web `isPlatformEntitled()` ile aynı: aktif ve (active|trial).
  bool get isEntitled => isActive && (status == 'active' || status == 'trial');

  /// Plan kodu → [SubscriptionPlan] (platform ön eki atılır: `pms_professional` → professional).
  SubscriptionPlan? get plan => SubscriptionPlan.fromPlanCode(planCode);

  factory PlatformLicense.fromJson(Map<String, dynamic> json) {
    DateTime? d(String key) {
      final v = json[key];
      return v is String ? DateTime.tryParse(v) : null;
    }

    Map<String, dynamic>? plan;
    final rawPlan = json['plan'];
    if (rawPlan is Map) {
      plan = rawPlan.cast<String, dynamic>();
    } else if (rawPlan is List && rawPlan.isNotEmpty && rawPlan.first is Map) {
      plan = (rawPlan.first as Map).cast<String, dynamic>();
    }

    return PlatformLicense(
      accessStateRaw: json['accessState'] as String?,
      graceUntil: d('graceUntil'),
      isActive: json['isActive'] == true,
      isTrial: json['isTrial'] == true,
      status: json['status'] as String?,
      subscribedAt: d('subscribedAt'),
      trialStartsAt: d('trialStartsAt'),
      trialEndsAt: d('trialEndsAt'),
      expiresAt: d('expiresAt'),
      planCode: plan?['plan_code'] as String?,
      planName: plan?['plan_name'] as String?,
      priceMonthly: plan?['price_monthly'] as num?,
    );
  }
}

/// Bir platform için son çözülen lisans bağlamı.
@immutable
class EntitlementSnapshot {
  /// Hangi platform kodu için (PMS/CRM/FIXFLOW...).
  final String? platformCode;

  /// `platform-context` başarıyla okundu mu? (false = bilinmiyor → fail-open)
  final bool loaded;

  /// Lisans satırı. `loaded && license == null` = platform satın alınmamış.
  final PlatformLicense? license;
  final DateTime? fetchedAt;

  const EntitlementSnapshot({
    this.platformCode,
    this.loaded = false,
    this.license,
    this.fetchedAt,
  });

  /// Bağlam yüklenmemiş (bilinmiyor) durum.
  static const EntitlementSnapshot unknown = EntitlementSnapshot();

  /// Sunucu yanıtından (`platform-context` gövdesi) kur.
  factory EntitlementSnapshot.fromContext(
    String platformCode,
    Map<String, dynamic> body, {
    DateTime? fetchedAt,
  }) {
    final rawLicense = body['license'];
    return EntitlementSnapshot(
      platformCode: platformCode,
      loaded: true,
      license: rawLicense is Map
          ? PlatformLicense.fromJson(rawLicense.cast<String, dynamic>())
          : null,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  /// Shell'in bu platformu nasıl ele alacağı — web
  /// `PlatformContextService.accessLevel()` ile aynı karar:
  ///   • bağlam yok (soğuk açılış / EF hatası) → full (fail-open; zorlama sunucuda)
  ///   • bağlam var, lisans yok → locked (platform satın alınmamış)
  ///   • aktif + (active|trial) → full
  ///   • aksi halde sunucu `read_only` diyorsa read_only, değilse locked
  LicenseAccessState get accessState {
    if (!loaded) return LicenseAccessState.full;
    final lic = license;
    if (lic == null) return LicenseAccessState.locked;
    if (lic.isEntitled) return LicenseAccessState.full;
    return lic.serverAccessState == LicenseAccessState.readOnly
        ? LicenseAccessState.readOnly
        : LicenseAccessState.locked;
  }
}

/// `platform-context` çağrısı (test için enjekte edilebilir).
typedef PlatformContextFetcher = Future<Map<String, dynamic>?> Function(
    String platformCode);

/// Aktif platformun lisans durumunu çözer, önbellekler ve yayınlar.
///
/// Kaynak: `platform-context` EF (kullanıcı JWT'si, `?platformCode=`). `fn_entitlement_state`
/// authenticated'a açık DEĞİL, çağrılmaz. Bu servis yalnız hangi ekranın gösterileceğini
/// seçer; asıl zorlama sunucudadır (yazma 25006 / 402).
///
/// Yenileme: [start] ile (giriş sonrası shell açılışı), platform değişiminde, uygulama
/// öne geldiğinde (resume) ve herhangi bir yazma lisans reddi aldığında
/// ([EntitlementSignals] / `Logger` hata gözlemcisi).
class EntitlementService with WidgetsBindingObserver {
  final PlatformContext _platformContext;
  final PlatformContextFetcher _fetcher;
  final OfflineSyncService? _offlineSync;
  final TenantService? _tenantService;

  /// Önbellek ömrü (zorlamasız [refresh] bu süre içinde ağa gitmez).
  final Duration cacheTtl;

  /// Hata kaynaklı yenilemeler arası en az süre (hata fırtınasında EF'i dövmemek için).
  final Duration errorRefreshInterval;

  final ValueNotifier<LicenseAccessState> _access =
      ValueNotifier<LicenseAccessState>(LicenseAccessState.full);
  final StreamController<LicenseAccessState> _accessController =
      StreamController<LicenseAccessState>.broadcast();

  EntitlementSnapshot _snapshot = EntitlementSnapshot.unknown;

  /// Çalışma anında görülen lisans reddi (sunucu bağlamı henüz yansıtmıyorsa).
  LicenseAccessState? _observed;

  Future<LicenseAccessState>? _inFlight;
  DateTime? _lastErrorRefresh;
  bool _started = false;
  StreamSubscription<String>? _platformSub;
  StreamSubscription<LicenseAccessState>? _signalSub;

  EntitlementService({
    required PlatformContext platformContext,
    SupabaseClient? supabase,
    PlatformContextFetcher? fetcher,
    OfflineSyncService? offlineSync,
    TenantService? tenantService,
    this.cacheTtl = const Duration(minutes: 5),
    this.errorRefreshInterval = const Duration(seconds: 10),
  })  : assert(supabase != null || fetcher != null,
            'supabase veya fetcher verilmeli'),
        _platformContext = platformContext,
        _fetcher = fetcher ?? _edgeFetcher(supabase!),
        _offlineSync = offlineSync,
        _tenantService = tenantService;

  static PlatformContextFetcher _edgeFetcher(SupabaseClient supabase) {
    return (code) async {
      final res = await supabase.functions.invoke(
        'platform-context',
        method: HttpMethod.get,
        queryParameters: {'platformCode': code},
      );
      final data = res.data;
      if (data is Map) return data.cast<String, dynamic>();
      return null;
    };
  }

  // ============================================
  // GETTERS
  // ============================================

  /// Etkin erişim durumu (dinlenebilir).
  ValueListenable<LicenseAccessState> get accessStateListenable => _access;

  /// Etkin erişim durumu.
  LicenseAccessState get accessState => _access.value;

  /// Erişim durumu değişiklikleri.
  Stream<LicenseAccessState> get accessStateStream => _accessController.stream;

  /// Son çözülen bağlam.
  EntitlementSnapshot get snapshot => _snapshot;

  /// Aktif platformun lisansı (bağlam yoksa ya da satın alınmamışsa null).
  PlatformLicense? get license => _snapshot.license;

  /// Yazma yapılabilir mi?
  bool get canWrite => accessState.canWrite;

  // ============================================
  // LIFECYCLE
  // ============================================

  /// Dinleyicileri bağla ve lisansı hemen yenile (giriş sonrası shell açılışında çağrılır).
  /// Tekrar çağrılırsa yalnız zorlamalı yenileme yapar.
  Future<LicenseAccessState> start() {
    if (!_started) {
      _started = true;
      _platformSub = _platformContext.platformStream.listen((_) {
        refresh(force: true);
      });
      _signalSub = EntitlementSignals.stream.listen(_onObserved);
      Logger.addErrorObserver(_onLoggedError);
      try {
        WidgetsBinding.instance.addObserver(this);
      } catch (_) {
        // Binding yok (saf-Dart test) → resume yenilemesi yok.
      }
    }
    return refresh(force: true);
  }

  /// Dinleyicileri çöz (shell kapanınca / çıkışta). Durum bilinmiyor'a döner.
  void stop() {
    if (!_started) return;
    _started = false;
    _platformSub?.cancel();
    _platformSub = null;
    _signalSub?.cancel();
    _signalSub = null;
    Logger.removeErrorObserver(_onLoggedError);
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _snapshot = EntitlementSnapshot.unknown;
    _observed = null;
    // Çıkışta kuyruğu yeniden başlatma: oturum yok.
    _publish(resumeQueue: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(force: true);
  }

  // ============================================
  // REFRESH
  // ============================================

  /// Lisansı `platform-context`'ten yeniden çöz.
  ///
  /// [force] false ise önbellek ([cacheTtl]) geçerliyken ağa gidilmez. Ağ/EF hatasında
  /// önceki bağlam korunur (hiç yoksa fail-open: full). Eşzamanlı çağrılar tek isteğe
  /// birleştirilir.
  Future<LicenseAccessState> refresh({bool force = false}) {
    return _refresh(force: force, keepObserved: false);
  }

  Future<LicenseAccessState> _refresh({
    required bool force,
    required bool keepObserved,
  }) {
    final code = _platformContext.activePlatformCode;
    if (code == null || code.isEmpty) {
      _snapshot = EntitlementSnapshot.unknown;
      if (!keepObserved) _observed = null;
      _publish();
      return Future.value(accessState);
    }

    // Platform değiştiyse eski platformun durumu yeni platforma taşınmaz.
    if (_snapshot.platformCode != null && _snapshot.platformCode != code) {
      _snapshot = EntitlementSnapshot.unknown;
      _observed = null;
      _publish();
    }

    final fetchedAt = _snapshot.fetchedAt;
    if (!force &&
        _snapshot.loaded &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < cacheTtl) {
      return Future.value(accessState);
    }

    final pending = _inFlight;
    if (pending != null) return pending;

    final future = _doFetch(code, keepObserved: keepObserved);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<LicenseAccessState> _doFetch(String code,
      {required bool keepObserved}) async {
    try {
      final body = await _fetcher(code);
      // Yanıt gelene kadar platform değişmiş olabilir.
      if (_platformContext.activePlatformCode != code) return accessState;
      if (body == null) {
        Logger.warning(
            'EntitlementService: platform-context boş yanıt ($code)');
        return accessState;
      }
      _snapshot = EntitlementSnapshot.fromContext(code, body);
      final computed = _snapshot.accessState;
      // Sunucu bağlamı reddi zaten yansıtıyorsa ya da bu yenileme hata kaynaklı
      // değilse gözlenen durum düşer; hata kaynaklı yenileme "full" dönerse gözlenen
      // red (sunucunun gerçek cevabı) korunur.
      if (!keepObserved || computed != LicenseAccessState.full) {
        _observed = null;
      }
      _applyPlan();
    } on FunctionException catch (e) {
      if (e.status == 404) {
        // Platform kodu sunucuda yok → bilinmiyor (fail-open).
        _snapshot = EntitlementSnapshot(platformCode: code);
      } else {
        Logger.debug(
            'EntitlementService: platform-context okunamadı (${e.status}) — önceki durum korunur');
      }
    } catch (e) {
      Logger.debug(
          'EntitlementService: platform-context okunamadı — önceki durum korunur: $e');
    }
    _publish();
    return accessState;
  }

  // ============================================
  // OBSERVED ENTITLEMENT ERRORS
  // ============================================

  /// Bir yazma hatasını bildir: lisans reddiyse durumu günceller, yenileme tetikler ve
  /// `true` döner.
  bool reportError(Object? error) {
    final state = isEntitlementError(error);
    if (state == null) return false;
    _onObserved(state);
    return true;
  }

  void _onLoggedError(Object error) {
    final state = isEntitlementError(error);
    if (state != null) _onObserved(state);
  }

  void _onObserved(LicenseAccessState state) {
    _observed = _worse(_observed, state);
    _publish();
    final now = DateTime.now();
    final last = _lastErrorRefresh;
    if (_inFlight == null &&
        (last == null || now.difference(last) >= errorRefreshInterval)) {
      _lastErrorRefresh = now;
      _refresh(force: true, keepObserved: true);
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  static LicenseAccessState _worse(
      LicenseAccessState? a, LicenseAccessState b) {
    if (a == null) return b;
    return a.index >= b.index ? a : b;
  }

  void _applyPlan() {
    final tenantService = _tenantService;
    if (tenantService == null) return;
    try {
      tenantService.setLicensePlan(_snapshot.license?.plan);
    } catch (_) {}
  }

  void _publish({bool resumeQueue = true}) {
    final effective = _worse(_observed, _snapshot.accessState);
    if (_access.value == effective) return;
    final previous = _access.value;
    _access.value = effective;
    if (!_accessController.isClosed) _accessController.add(effective);
    Logger.info('Entitlement access: ${previous.name} → ${effective.name}');
    if (resumeQueue && effective == LicenseAccessState.full) {
      _offlineSync?.resumeAfterEntitlement();
    }
  }

  /// Servisi kapat.
  void dispose() {
    stop();
    _accessController.close();
    _access.dispose();
  }
}

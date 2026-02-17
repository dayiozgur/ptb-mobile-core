/// DataProvider durumu
enum DataProviderStatus {
  /// Aktif
  active,

  /// Pasif
  inactive,

  /// Bağlantı kuruluyor
  connecting,

  /// Hata
  error,

  /// Devre dışı
  disabled;

  /// String'den DataProviderStatus'a dönüştür
  static DataProviderStatus fromString(String? value) {
    return DataProviderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DataProviderStatus.inactive,
    );
  }

  /// Türkçe etiket
  String get label {
    switch (this) {
      case DataProviderStatus.active:
        return 'Aktif';
      case DataProviderStatus.inactive:
        return 'Pasif';
      case DataProviderStatus.connecting:
        return 'Bağlanıyor';
      case DataProviderStatus.error:
        return 'Hata';
      case DataProviderStatus.disabled:
        return 'Devre Dışı';
    }
  }
}

/// DataProvider tipi
enum DataProviderType {
  /// Modbus
  modbus('MODBUS', 'Modbus'),

  /// OPC UA
  opcUa('OPC_UA', 'OPC UA'),

  /// MQTT
  mqtt('MQTT', 'MQTT'),

  /// HTTP/REST API
  http('HTTP', 'HTTP/REST'),

  /// BACnet
  bacnet('BACNET', 'BACnet'),

  /// Siemens S7
  s7('S7', 'Siemens S7'),

  /// Allen Bradley
  allenBradley('ALLEN_BRADLEY', 'Allen Bradley'),

  /// Database
  database('DATABASE', 'Database'),

  /// File
  file('FILE', 'Dosya'),

  /// Custom
  custom('CUSTOM', 'Özel');

  final String value;
  final String label;
  const DataProviderType(this.value, this.label);

  static DataProviderType fromString(String? value) {
    return DataProviderType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => DataProviderType.custom,
    );
  }
}

/// Veri toplama modu
enum DataCollectionMode {
  /// Polling (periyodik sorgulama)
  polling('POLLING', 'Polling'),

  /// Subscription (abonelik)
  subscription('SUBSCRIPTION', 'Subscription'),

  /// On-demand (talep üzerine)
  onDemand('ON_DEMAND', 'Talep Üzerine'),

  /// Event-driven (olay tabanlı)
  eventDriven('EVENT_DRIVEN', 'Olay Tabanlı');

  final String value;
  final String label;
  const DataCollectionMode(this.value, this.label);

  static DataCollectionMode fromString(String? value) {
    return DataCollectionMode.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => DataCollectionMode.polling,
    );
  }
}

/// DataProvider (Veri Sağlayıcı) modeli
///
/// IoT sistemindeki veri kaynaklarını/protokollerini temsil eder.
/// Hiyerarşi: Tenant → DataProvider → Controller → Variable
class DataProvider {
  /// Benzersiz ID
  final String id;

  /// DataProvider adı
  final String name;

  /// DataProvider kodu
  final String? code;

  /// Açıklama
  final String? description;

  /// DataProvider tipi
  final DataProviderType type;

  /// Durum
  final DataProviderStatus status;

  /// Aktif mi?
  final bool active;

  // ============================================
  // BAĞLANTI AYARLARI
  // ============================================

  /// Host adresi
  final String? host;

  /// Port
  final int? port;

  /// Kullanıcı adı
  final String? username;

  /// Şifre (encrypted)
  final String? password;

  /// SSL/TLS kullanılsın mı?
  final bool useSsl;

  /// Sertifika yolu
  final String? certificatePath;

  /// Bağlantı dizesi
  final String? connectionString;

  // ============================================
  // VERİ TOPLAMA AYARLARI
  // ============================================

  /// Veri toplama modu
  final DataCollectionMode collectionMode;

  /// Polling aralığı (ms)
  final int pollingInterval;

  /// Batch boyutu
  final int batchSize;

  /// Timeout (ms)
  final int timeout;

  /// Retry sayısı
  final int retryCount;

  /// Retry aralığı (ms)
  final int retryInterval;

  // ============================================
  // DURUM BİLGİLERİ
  // ============================================

  /// Son bağlantı tarihi
  final DateTime? lastConnectedAt;

  /// Son hata mesajı
  final String? lastError;

  /// Son hata tarihi
  final DateTime? lastErrorAt;

  /// Toplam değişken sayısı
  final int variableCount;

  /// Bağlı controller sayısı
  final int controllerCount;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Tenant ID
  final String tenantId;

  /// Bağlı olduğu Site ID (DB: site_id)
  final String? siteId;

  /// Bağlı olduğu Unit ID (DB: unit_id)
  final String? unitId;

  /// IP adresi (DB: ip)
  final String? ip;

  /// Hostname (DB: hostname)
  final String? hostname;

  /// MAC adresi (DB: mac)
  final String? mac;

  /// Brand ID (DB: brand_id FK)
  final String? brandId;

  /// Uygulama versiyonu (DB: app_version)
  final String? appVersion;

  /// Sistem versiyonu (DB: sys_version)
  final String? sysVersion;

  /// Uptime (DB: uptime)
  final String? uptime;

  // ============================================
  // METADATA
  // ============================================

  /// Ek konfigürasyon (JSON)
  final Map<String, dynamic> config;

  /// Etiketler
  final List<String> tags;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Oluşturan kullanıcı
  final String? createdBy;

  /// Güncelleyen kullanıcı
  final String? updatedBy;

  /// Row ID (sıralama için)
  final int? rowId;

  const DataProvider({
    required this.id,
    required this.name,
    required this.tenantId,
    this.code,
    this.description,
    this.type = DataProviderType.modbus,
    this.status = DataProviderStatus.inactive,
    this.active = true,
    this.host,
    this.port,
    this.username,
    this.password,
    this.useSsl = false,
    this.certificatePath,
    this.connectionString,
    this.collectionMode = DataCollectionMode.polling,
    this.pollingInterval = 1000,
    this.batchSize = 100,
    this.timeout = 5000,
    this.retryCount = 3,
    this.retryInterval = 1000,
    this.lastConnectedAt,
    this.lastError,
    this.lastErrorAt,
    this.variableCount = 0,
    this.controllerCount = 0,
    this.siteId,
    this.unitId,
    this.ip,
    this.hostname,
    this.mac,
    this.brandId,
    this.appVersion,
    this.sysVersion,
    this.uptime,
    this.config = const {},
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.rowId,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Aktif mi?
  bool get isActive => active && status == DataProviderStatus.active;

  /// Hata durumunda mı?
  bool get hasError => status == DataProviderStatus.error;

  /// Bağlantı bilgisi var mı?
  bool get hasConnectionInfo =>
      (host != null && host!.isNotEmpty) ||
      (connectionString != null && connectionString!.isNotEmpty);

  /// Bağlantı adresi (görüntüleme için)
  String get connectionAddress {
    if (host != null && port != null) {
      return '$host:$port';
    }
    if (host != null) return host!;
    if (connectionString != null) return connectionString!;
    return '-';
  }

  /// Polling aralığı formatlanmış
  String get pollingIntervalFormatted {
    if (pollingInterval < 1000) return '${pollingInterval}ms';
    if (pollingInterval < 60000) return '${pollingInterval ~/ 1000}s';
    return '${pollingInterval ~/ 60000}dk';
  }

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory DataProvider.fromJson(Map<String, dynamic> json) {
    return DataProvider(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      type: DataProviderType.fromString(json['type'] as String?),
      status: _statusFromJson(json),
      active: json['active'] as bool? ?? true,
      host: json['host'] as String? ?? json['ip'] as String?,
      port: json['port'] as int?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      useSsl: json['use_ssl'] as bool? ?? false,
      certificatePath: json['certificate_path'] as String?,
      connectionString: json['connection_string'] as String?,
      collectionMode:
          DataCollectionMode.fromString(json['collection_mode'] as String?),
      pollingInterval: json['polling_interval'] as int? ?? 1000,
      batchSize: json['batch_size'] as int? ?? 100,
      timeout: json['timeout'] as int? ?? 5000,
      retryCount: json['retry_count'] as int? ?? 3,
      retryInterval: json['retry_interval'] as int? ?? 1000,
      lastConnectedAt: json['last_connection_time'] != null
          ? DateTime.tryParse(json['last_connection_time'] as String)
          : json['last_connected_at'] != null
              ? DateTime.tryParse(json['last_connected_at'] as String)
              : null,
      lastError: json['last_error'] as String?,
      lastErrorAt: json['last_error_at'] != null
          ? DateTime.tryParse(json['last_error_at'] as String)
          : null,
      variableCount: json['variable_count'] as int? ?? 0,
      controllerCount: json['controller_count'] as int? ?? 0,
      siteId: json['site_id'] as String?,
      unitId: json['unit_id'] as String?,
      ip: json['ip'] as String?,
      hostname: json['hostname'] as String?,
      mac: json['mac'] as String?,
      brandId: json['brand_id'] as String?,
      appVersion: json['app_version'] as String?,
      sysVersion: json['sys_version'] as String?,
      uptime: json['uptime'] as String?,
      config: json['config'] as Map<String, dynamic>? ?? const {},
      tags: json['tags'] != null && json['tags'] is List
          ? List<String>.from(json['tags'] as List)
          : const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      rowId: json['row_id'] as int?,
    );
  }

  /// DB'deki active alanından status türet
  static DataProviderStatus _statusFromJson(Map<String, dynamic> json) {
    // Önce doğrudan status alanını kontrol et (cache'den okuma)
    if (json['status'] != null) {
      return DataProviderStatus.fromString(json['status'] as String?);
    }
    // DB'deki active boolean'dan türet
    final active = json['active'] as bool? ?? true;
    return active ? DataProviderStatus.active : DataProviderStatus.inactive;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tenant_id': tenantId,
      'code': code,
      'description': description,
      'type': type.value,
      'status': status.name,
      'active': active,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'use_ssl': useSsl,
      'certificate_path': certificatePath,
      'connection_string': connectionString,
      'collection_mode': collectionMode.value,
      'polling_interval': pollingInterval,
      'batch_size': batchSize,
      'timeout': timeout,
      'retry_count': retryCount,
      'retry_interval': retryInterval,
      'last_connected_at': lastConnectedAt?.toIso8601String(),
      'last_error': lastError,
      'last_error_at': lastErrorAt?.toIso8601String(),
      'variable_count': variableCount,
      'controller_count': controllerCount,
      'site_id': siteId,
      'unit_id': unitId,
      'ip': ip,
      'hostname': hostname,
      'mac': mac,
      'brand_id': brandId,
      'app_version': appVersion,
      'sys_version': sysVersion,
      'uptime': uptime,
      'config': config,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
      'row_id': rowId,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  DataProvider copyWith({
    String? id,
    String? name,
    String? tenantId,
    String? code,
    String? description,
    DataProviderType? type,
    DataProviderStatus? status,
    bool? active,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useSsl,
    String? certificatePath,
    String? connectionString,
    DataCollectionMode? collectionMode,
    int? pollingInterval,
    int? batchSize,
    int? timeout,
    int? retryCount,
    int? retryInterval,
    DateTime? lastConnectedAt,
    String? lastError,
    DateTime? lastErrorAt,
    int? variableCount,
    int? controllerCount,
    String? siteId,
    String? unitId,
    String? ip,
    String? hostname,
    String? mac,
    String? brandId,
    String? appVersion,
    String? sysVersion,
    String? uptime,
    Map<String, dynamic>? config,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    int? rowId,
  }) {
    return DataProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      tenantId: tenantId ?? this.tenantId,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      active: active ?? this.active,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useSsl: useSsl ?? this.useSsl,
      certificatePath: certificatePath ?? this.certificatePath,
      connectionString: connectionString ?? this.connectionString,
      collectionMode: collectionMode ?? this.collectionMode,
      pollingInterval: pollingInterval ?? this.pollingInterval,
      batchSize: batchSize ?? this.batchSize,
      timeout: timeout ?? this.timeout,
      retryCount: retryCount ?? this.retryCount,
      retryInterval: retryInterval ?? this.retryInterval,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastError: lastError ?? this.lastError,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      variableCount: variableCount ?? this.variableCount,
      controllerCount: controllerCount ?? this.controllerCount,
      siteId: siteId ?? this.siteId,
      unitId: unitId ?? this.unitId,
      ip: ip ?? this.ip,
      hostname: hostname ?? this.hostname,
      mac: mac ?? this.mac,
      brandId: brandId ?? this.brandId,
      appVersion: appVersion ?? this.appVersion,
      sysVersion: sysVersion ?? this.sysVersion,
      uptime: uptime ?? this.uptime,
      config: config ?? this.config,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      rowId: rowId ?? this.rowId,
    );
  }

  @override
  String toString() => 'DataProvider($id, $name, ${type.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DataProvider && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// DataProvider bağlantı testi sonucu
class DataProviderConnectionTestResult {
  /// Başarılı mı?
  final bool success;

  /// Mesaj
  final String message;

  /// Yanıt süresi (ms)
  final int? responseTimeMs;

  /// Hata detayı
  final String? errorDetail;

  /// Test tarihi
  final DateTime testedAt;

  const DataProviderConnectionTestResult({
    required this.success,
    required this.message,
    this.responseTimeMs,
    this.errorDetail,
    required this.testedAt,
  });

  factory DataProviderConnectionTestResult.success({
    required String message,
    int? responseTimeMs,
  }) {
    return DataProviderConnectionTestResult(
      success: true,
      message: message,
      responseTimeMs: responseTimeMs,
      testedAt: DateTime.now(),
    );
  }

  factory DataProviderConnectionTestResult.failure({
    required String message,
    String? errorDetail,
  }) {
    return DataProviderConnectionTestResult(
      success: false,
      message: message,
      errorDetail: errorDetail,
      testedAt: DateTime.now(),
    );
  }
}

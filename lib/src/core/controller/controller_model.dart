import '../utils/db_field_helpers.dart';

/// Controller durumu
enum ControllerStatus {
  /// Çevrimiçi
  online,

  /// Çevrimdışı
  offline,

  /// Bağlantı kuruluyor
  connecting,

  /// Hata
  error,

  /// Bakımda
  maintenance,

  /// Devre dışı
  disabled,

  /// Bilinmiyor
  unknown;

  /// String'den ControllerStatus'a dönüştür
  static ControllerStatus fromString(String? value) {
    return ControllerStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ControllerStatus.unknown,
    );
  }

  /// Türkçe etiket
  String get label {
    switch (this) {
      case ControllerStatus.online:
        return 'Çevrimiçi';
      case ControllerStatus.offline:
        return 'Çevrimdışı';
      case ControllerStatus.connecting:
        return 'Bağlanıyor';
      case ControllerStatus.error:
        return 'Hata';
      case ControllerStatus.maintenance:
        return 'Bakımda';
      case ControllerStatus.disabled:
        return 'Devre Dışı';
      case ControllerStatus.unknown:
        return 'Bilinmiyor';
    }
  }
}

/// Controller tipi
enum ControllerType {
  /// PLC (Programmable Logic Controller)
  plc('PLC', 'Programlanabilir Mantık Denetleyicisi'),

  /// RTU (Remote Terminal Unit)
  rtu('RTU', 'Uzak Terminal Ünitesi'),

  /// Gateway
  gateway('GATEWAY', 'Ağ Geçidi'),

  /// HMI (Human Machine Interface)
  hmi('HMI', 'İnsan Makine Arayüzü'),

  /// SCADA
  scada('SCADA', 'SCADA Sistemi'),

  /// IoT Gateway
  iotGateway('IOT_GATEWAY', 'IoT Ağ Geçidi'),

  /// Edge Device
  edge('EDGE', 'Edge Cihaz'),

  /// Sensör Hub
  sensorHub('SENSOR_HUB', 'Sensör Hub'),

  /// Virtual Controller
  virtual('VIRTUAL', 'Sanal Kontroller'),

  /// Diğer
  other('OTHER', 'Diğer');

  final String value;
  final String label;
  const ControllerType(this.value, this.label);

  static ControllerType fromString(String? value) {
    return ControllerType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => ControllerType.other,
    );
  }
}

/// İletişim protokolü
enum CommunicationProtocol {
  /// Modbus TCP
  modbusTcp('MODBUS_TCP', 'Modbus TCP'),

  /// Modbus RTU
  modbusRtu('MODBUS_RTU', 'Modbus RTU'),

  /// OPC UA
  opcUa('OPC_UA', 'OPC UA'),

  /// OPC DA
  opcDa('OPC_DA', 'OPC DA'),

  /// MQTT
  mqtt('MQTT', 'MQTT'),

  /// HTTP/REST
  http('HTTP', 'HTTP/REST'),

  /// BACnet
  bacnet('BACNET', 'BACnet'),

  /// Profinet
  profinet('PROFINET', 'Profinet'),

  /// EtherNet/IP
  ethernetIp('ETHERNET_IP', 'EtherNet/IP'),

  /// Siemens S7
  s7('S7', 'Siemens S7'),

  /// Custom
  custom('CUSTOM', 'Özel');

  final String value;
  final String label;
  const CommunicationProtocol(this.value, this.label);

  static CommunicationProtocol fromString(String? value) {
    return CommunicationProtocol.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => CommunicationProtocol.custom,
    );
  }
}

/// Controller (Kontroller/Cihaz) modeli
///
/// IoT sistemindeki donanım cihazlarını temsil eder.
/// Hiyerarşi: Tenant → Site → Unit → Controller → Variable
class Controller {
  /// Benzersiz ID
  final String id;

  /// Controller adı
  final String name;

  /// Controller kodu
  final String? code;

  /// Açıklama
  final String? description;

  /// Controller tipi
  final ControllerType type;

  /// Marka
  final String? brand;

  /// Model
  final String? model;

  /// Seri numarası
  final String? serialNumber;

  /// Firmware versiyonu
  final String? firmwareVersion;

  // ============================================
  // BAĞLANTI BİLGİLERİ
  // ============================================

  /// İletişim protokolü
  final CommunicationProtocol protocol;

  /// IP adresi
  final String? ipAddress;

  /// Port
  final int? port;

  /// Slave ID (Modbus için)
  final int? slaveId;

  /// Bağlantı dizesi (connection string)
  final String? connectionString;

  /// Bağlantı timeout (ms)
  final int connectionTimeout;

  /// Okuma timeout (ms)
  final int readTimeout;

  /// Yeniden bağlanma denemesi
  final int retryCount;

  /// Yeniden bağlanma aralığı (ms)
  final int retryInterval;

  // ============================================
  // DURUM BİLGİLERİ
  // ============================================

  /// Mevcut durum
  final ControllerStatus status;

  /// Aktif mi?
  final bool active;

  /// Son bağlantı tarihi
  final DateTime? lastConnectedAt;

  /// Son veri tarihi
  final DateTime? lastDataAt;

  /// Son hata mesajı
  final String? lastError;

  /// Son hata tarihi
  final DateTime? lastErrorAt;

  /// Uptime (saniye)
  final int? uptimeSeconds;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Unit ID
  final String? unitId;

  /// Bağlı olduğu Site ID
  final String? siteId;

  /// Bağlı olduğu Tenant ID
  final String tenantId;

  /// Provider ID (veri sağlayıcı)
  final String? providerId;

  /// Device Model ID (cihaz şablonu)
  /// Variables ile ilişki device_model_id üzerinden kurulur.
  /// Aynı device_model'e sahip controller'lar aynı variable şablonlarını kullanır.
  final String? deviceModelId;

  // ============================================
  // METADATA
  // ============================================

  /// Etiketler
  final List<String> tags;

  /// Ek özellikler (JSON)
  final Map<String, dynamic> metadata;

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

  const Controller({
    required this.id,
    required this.name,
    required this.tenantId,
    this.code,
    this.description,
    this.type = ControllerType.other,
    this.brand,
    this.model,
    this.serialNumber,
    this.firmwareVersion,
    this.protocol = CommunicationProtocol.modbusTcp,
    this.ipAddress,
    this.port,
    this.slaveId,
    this.connectionString,
    this.connectionTimeout = 5000,
    this.readTimeout = 3000,
    this.retryCount = 3,
    this.retryInterval = 1000,
    this.status = ControllerStatus.unknown,
    this.active = true,
    this.lastConnectedAt,
    this.lastDataAt,
    this.lastError,
    this.lastErrorAt,
    this.uptimeSeconds,
    this.unitId,
    this.siteId,
    this.providerId,
    this.deviceModelId,
    this.tags = const [],
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Çevrimiçi mi?
  bool get isOnline => status == ControllerStatus.online;

  /// Çevrimdışı mı?
  bool get isOffline => status == ControllerStatus.offline;

  /// Hata durumunda mı?
  bool get hasError => status == ControllerStatus.error;

  /// Bakımda mı?
  bool get isUnderMaintenance => status == ControllerStatus.maintenance;

  /// Bağlantı bilgisi var mı?
  bool get hasConnectionInfo =>
      (ipAddress != null && ipAddress!.isNotEmpty) ||
      (connectionString != null && connectionString!.isNotEmpty);

  /// Uptime formatlanmış
  String get uptimeFormatted {
    if (uptimeSeconds == null) return '-';
    final duration = Duration(seconds: uptimeSeconds!);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) return '${days}g ${hours}s ${minutes}dk';
    if (hours > 0) return '${hours}s ${minutes}dk';
    return '${minutes}dk';
  }

  /// Son bağlantıdan bu yana geçen süre
  Duration? get timeSinceLastConnection {
    if (lastConnectedAt == null) return null;
    return DateTime.now().difference(lastConnectedAt!);
  }

  /// Son veriden bu yana geçen süre
  Duration? get timeSinceLastData {
    if (lastDataAt == null) return null;
    return DateTime.now().difference(lastDataAt!);
  }

  /// Bağlantı adresi (görüntüleme için)
  String get connectionAddress {
    if (ipAddress != null && port != null) {
      return '$ipAddress:$port';
    }
    if (ipAddress != null) return ipAddress!;
    if (connectionString != null) return connectionString!;
    return '-';
  }

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Controller.fromJson(Map<String, dynamic> json) {
    return Controller(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      type: ControllerType.fromString(json['type'] as String?),
      brand: json['brand'] as String?,
      // Dual column: model_code (legacy) / model (current)
      model: DbFieldHelpers.parseControllerModel(json),
      // Dual column: serial (legacy) / serial_number (current)
      serialNumber: DbFieldHelpers.parseControllerSerial(json),
      firmwareVersion: json['firmware_version'] as String?,
      protocol: CommunicationProtocol.fromString(json['protocol'] as String?),
      // Dual column: ip (legacy) / ip_address (current)
      ipAddress: DbFieldHelpers.parseControllerIp(json),
      port: json['port'] as int?,
      slaveId: json['slave_id'] as int?,
      connectionString: json['connection_string'] as String?,
      connectionTimeout: json['connection_timeout'] as int? ?? 5000,
      readTimeout: json['read_timeout'] as int? ?? 3000,
      retryCount: json['retry_count'] as int? ?? 3,
      retryInterval: json['retry_interval'] as int? ?? 1000,
      status: _statusFromJson(json),
      active: json['active'] as bool? ?? true,
      // Dual column: last_connection_time (legacy) / last_connected_at (current)
      lastConnectedAt: DbFieldHelpers.parseControllerLastConnection(json),
      // Dual column: last_communication_time (legacy) / last_data_at (current)
      lastDataAt: DbFieldHelpers.parseControllerLastData(json),
      lastError: json['last_error'] as String?,
      lastErrorAt: json['last_error_at'] != null
          ? DateTime.tryParse(json['last_error_at'] as String)
          : null,
      uptimeSeconds: json['uptime_seconds'] as int?,
      unitId: json['unit_id'] as String?,
      siteId: json['site_id'] as String?,
      providerId: json['provider_id'] as String?,
      deviceModelId: json['device_model_id'] as String?,
      tags: json['tags'] != null && json['tags'] is List
          ? List<String>.from(json['tags'] as List)
          : const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  /// DB'deki is_enabled/is_canceled alanlarından status türet
  static ControllerStatus _statusFromJson(Map<String, dynamic> json) {
    // Önce doğrudan status alanını kontrol et
    if (json['status'] != null) {
      return ControllerStatus.fromString(json['status'] as String?);
    }
    // DB'deki boolean alanlardan türet
    final isCanceled = json['is_canceled'] as bool? ?? false;
    final isEnabled = json['is_enabled'] as bool? ?? true;
    if (isCanceled) return ControllerStatus.disabled;
    if (!isEnabled) return ControllerStatus.offline;
    return ControllerStatus.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tenant_id': tenantId,
      'code': code,
      'description': description,
      'type': type.value,
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'firmware_version': firmwareVersion,
      'protocol': protocol.value,
      'ip_address': ipAddress,
      'port': port,
      'slave_id': slaveId,
      'connection_string': connectionString,
      'connection_timeout': connectionTimeout,
      'read_timeout': readTimeout,
      'retry_count': retryCount,
      'retry_interval': retryInterval,
      'status': status.name,
      'active': active,
      'last_connected_at': lastConnectedAt?.toIso8601String(),
      'last_data_at': lastDataAt?.toIso8601String(),
      'last_error': lastError,
      'last_error_at': lastErrorAt?.toIso8601String(),
      'uptime_seconds': uptimeSeconds,
      'unit_id': unitId,
      'site_id': siteId,
      'provider_id': providerId,
      'device_model_id': deviceModelId,
      'tags': tags,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  Controller copyWith({
    String? id,
    String? name,
    String? tenantId,
    String? code,
    String? description,
    ControllerType? type,
    String? brand,
    String? model,
    String? serialNumber,
    String? firmwareVersion,
    CommunicationProtocol? protocol,
    String? ipAddress,
    int? port,
    int? slaveId,
    String? connectionString,
    int? connectionTimeout,
    int? readTimeout,
    int? retryCount,
    int? retryInterval,
    ControllerStatus? status,
    bool? active,
    DateTime? lastConnectedAt,
    DateTime? lastDataAt,
    String? lastError,
    DateTime? lastErrorAt,
    int? uptimeSeconds,
    String? unitId,
    String? siteId,
    String? providerId,
    String? deviceModelId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Controller(
      id: id ?? this.id,
      name: name ?? this.name,
      tenantId: tenantId ?? this.tenantId,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      protocol: protocol ?? this.protocol,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      slaveId: slaveId ?? this.slaveId,
      connectionString: connectionString ?? this.connectionString,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      readTimeout: readTimeout ?? this.readTimeout,
      retryCount: retryCount ?? this.retryCount,
      retryInterval: retryInterval ?? this.retryInterval,
      status: status ?? this.status,
      active: active ?? this.active,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastDataAt: lastDataAt ?? this.lastDataAt,
      lastError: lastError ?? this.lastError,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      unitId: unitId ?? this.unitId,
      siteId: siteId ?? this.siteId,
      providerId: providerId ?? this.providerId,
      deviceModelId: deviceModelId ?? this.deviceModelId,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'Controller($id, $name, ${status.label})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Controller && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Controller istatistikleri
class ControllerStats {
  /// Toplam controller sayısı
  final int totalCount;

  /// Çevrimiçi controller sayısı
  final int onlineCount;

  /// Çevrimdışı controller sayısı
  final int offlineCount;

  /// Hata durumundaki controller sayısı
  final int errorCount;

  /// Bakımdaki controller sayısı
  final int maintenanceCount;

  const ControllerStats({
    this.totalCount = 0,
    this.onlineCount = 0,
    this.offlineCount = 0,
    this.errorCount = 0,
    this.maintenanceCount = 0,
  });

  /// Çevrimiçi oranı (%)
  double get onlinePercentage {
    if (totalCount == 0) return 0;
    return (onlineCount / totalCount) * 100;
  }

  /// Sağlık durumu
  String get healthStatus {
    if (totalCount == 0) return 'Veri yok';
    if (onlinePercentage >= 90) return 'İyi';
    if (onlinePercentage >= 70) return 'Normal';
    if (onlinePercentage >= 50) return 'Dikkat';
    return 'Kritik';
  }

  factory ControllerStats.fromJson(Map<String, dynamic> json) {
    return ControllerStats(
      totalCount: json['total_count'] as int? ?? 0,
      onlineCount: json['online_count'] as int? ?? 0,
      offlineCount: json['offline_count'] as int? ?? 0,
      errorCount: json['error_count'] as int? ?? 0,
      maintenanceCount: json['maintenance_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_count': totalCount,
      'online_count': onlineCount,
      'offline_count': offlineCount,
      'error_count': errorCount,
      'maintenance_count': maintenanceCount,
    };
  }
}

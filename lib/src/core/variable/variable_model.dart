/// Variable veri tipi
enum VariableDataType {
  /// Boolean
  boolean('BOOL', 'Boolean'),

  /// Integer (16-bit)
  int16('INT16', 'Int16'),

  /// Integer (32-bit)
  int32('INT32', 'Int32'),

  /// Integer (64-bit)
  int64('INT64', 'Int64'),

  /// Unsigned Integer (16-bit)
  uint16('UINT16', 'UInt16'),

  /// Unsigned Integer (32-bit)
  uint32('UINT32', 'UInt32'),

  /// Float (32-bit)
  float32('FLOAT32', 'Float32'),

  /// Float (64-bit)
  float64('FLOAT64', 'Float64'),

  /// String
  string('STRING', 'String'),

  /// Date/Time
  datetime('DATETIME', 'DateTime'),

  /// JSON
  json('JSON', 'JSON'),

  /// Binary
  binary('BINARY', 'Binary');

  final String value;
  final String label;
  const VariableDataType(this.value, this.label);

  static VariableDataType fromString(String? value) {
    return VariableDataType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => VariableDataType.float32,
    );
  }

  /// Numeric tip mi?
  bool get isNumeric {
    return this == int16 ||
        this == int32 ||
        this == int64 ||
        this == uint16 ||
        this == uint32 ||
        this == float32 ||
        this == float64;
  }
}

/// Variable erişim modu
enum VariableAccessMode {
  /// Sadece okuma
  readOnly('READ_ONLY', 'Sadece Okuma'),

  /// Okuma/Yazma
  readWrite('READ_WRITE', 'Okuma/Yazma'),

  /// Sadece yazma
  writeOnly('WRITE_ONLY', 'Sadece Yazma');

  final String value;
  final String label;
  const VariableAccessMode(this.value, this.label);

  static VariableAccessMode fromString(String? value) {
    return VariableAccessMode.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => VariableAccessMode.readOnly,
    );
  }
}

/// Variable kategorisi
enum VariableCategory {
  /// Analog giriş
  analogInput('AI', 'Analog Giriş'),

  /// Analog çıkış
  analogOutput('AO', 'Analog Çıkış'),

  /// Dijital giriş
  digitalInput('DI', 'Dijital Giriş'),

  /// Dijital çıkış
  digitalOutput('DO', 'Dijital Çıkış'),

  /// Sayaç
  counter('COUNTER', 'Sayaç'),

  /// Hesaplanan
  calculated('CALCULATED', 'Hesaplanan'),

  /// Durum
  status('STATUS', 'Durum'),

  /// Alarm
  alarm('ALARM', 'Alarm'),

  /// Setpoint
  setpoint('SETPOINT', 'Setpoint'),

  /// Diğer
  other('OTHER', 'Diğer');

  final String value;
  final String label;
  const VariableCategory(this.value, this.label);

  static VariableCategory fromString(String? value) {
    return VariableCategory.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => VariableCategory.other,
    );
  }
}

/// Variable kalite durumu
enum VariableQuality {
  /// İyi (geçerli veri)
  good('GOOD', 'İyi'),

  /// Kötü (geçersiz veri)
  bad('BAD', 'Kötü'),

  /// Şüpheli (belirsiz veri)
  uncertain('UNCERTAIN', 'Şüpheli'),

  /// Bağlantı yok
  noConnection('NO_CONNECTION', 'Bağlantı Yok');

  final String value;
  final String label;
  const VariableQuality(this.value, this.label);

  static VariableQuality fromString(String? value) {
    return VariableQuality.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => VariableQuality.bad,
    );
  }
}

/// Variable (Değişken/Tag) modeli
///
/// IoT sistemindeki veri noktalarını temsil eder.
/// Hiyerarşi: Controller → Variable
class Variable {
  /// Benzersiz ID
  final String id;

  /// Variable adı
  final String name;

  /// Variable kodu/tag adı
  final String? code;

  /// Açıklama
  final String? description;

  /// Veri tipi
  final VariableDataType dataType;

  /// Erişim modu
  final VariableAccessMode accessMode;

  /// Kategori
  final VariableCategory category;

  /// Aktif mi?
  final bool active;

  // ============================================
  // ADRES BİLGİLERİ
  // ============================================

  /// Adres (Modbus register, OPC node, vb.)
  final String? address;

  /// Register tipi (holding, input, coil, vb.)
  final String? registerType;

  /// Byte sıralaması (big-endian, little-endian)
  final String? byteOrder;

  /// Bit pozisyonu (boolean için)
  final int? bitPosition;

  // ============================================
  // ÖLÇEKLEME
  // ============================================

  /// Ham değer minimum
  final double? rawMin;

  /// Ham değer maksimum
  final double? rawMax;

  /// Ölçeklenmiş değer minimum
  final double? scaledMin;

  /// Ölçeklenmiş değer maksimum
  final double? scaledMax;

  /// Birim (°C, kW, %, vb.)
  final String? unit;

  /// Ondalık basamak sayısı
  final int decimals;

  // ============================================
  // ALARM LİMİTLERİ
  // ============================================

  /// Düşük-düşük limit
  final double? loLoLimit;

  /// Düşük limit
  final double? loLimit;

  /// Yüksek limit
  final double? hiLimit;

  /// Yüksek-yüksek limit
  final double? hiHiLimit;

  /// Deadband (histerezis)
  final double? deadband;

  // ============================================
  // MEVCUT DEĞER
  // ============================================

  /// Mevcut değer
  final dynamic currentValue;

  /// Kalite durumu
  final VariableQuality quality;

  /// Son güncelleme tarihi
  final DateTime? lastUpdatedAt;

  /// Son değişiklik tarihi
  final DateTime? lastChangedAt;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Bağlı olduğu Controller ID
  final String controllerId;

  /// Bağlı olduğu Tenant ID
  final String tenantId;

  /// Unit ID (opsiyonel)
  final String? unitId;

  // ============================================
  // METADATA
  // ============================================

  /// Etiketler
  final List<String> tags;

  /// Ek özellikler
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

  const Variable({
    required this.id,
    required this.name,
    required this.controllerId,
    required this.tenantId,
    this.code,
    this.description,
    this.dataType = VariableDataType.float32,
    this.accessMode = VariableAccessMode.readOnly,
    this.category = VariableCategory.other,
    this.active = true,
    this.address,
    this.registerType,
    this.byteOrder,
    this.bitPosition,
    this.rawMin,
    this.rawMax,
    this.scaledMin,
    this.scaledMax,
    this.unit,
    this.decimals = 2,
    this.loLoLimit,
    this.loLimit,
    this.hiLimit,
    this.hiHiLimit,
    this.deadband,
    this.currentValue,
    this.quality = VariableQuality.bad,
    this.lastUpdatedAt,
    this.lastChangedAt,
    this.unitId,
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

  /// Değer iyi kalitede mi?
  bool get isGoodQuality => quality == VariableQuality.good;

  /// Okunabilir mi?
  bool get isReadable =>
      accessMode == VariableAccessMode.readOnly ||
      accessMode == VariableAccessMode.readWrite;

  /// Yazılabilir mi?
  bool get isWritable =>
      accessMode == VariableAccessMode.writeOnly ||
      accessMode == VariableAccessMode.readWrite;

  /// Numeric değer mi?
  bool get isNumeric => dataType.isNumeric;

  /// Boolean değer mi?
  bool get isBoolean => dataType == VariableDataType.boolean;

  /// Alarm limitleri tanımlı mı?
  bool get hasAlarmLimits =>
      loLoLimit != null ||
      loLimit != null ||
      hiLimit != null ||
      hiHiLimit != null;

  /// Ölçekleme tanımlı mı?
  bool get hasScaling =>
      rawMin != null &&
      rawMax != null &&
      scaledMin != null &&
      scaledMax != null;

  /// Numeric değer (null-safe)
  double? get numericValue {
    if (currentValue == null) return null;
    if (currentValue is num) return (currentValue as num).toDouble();
    if (currentValue is String) return double.tryParse(currentValue as String);
    return null;
  }

  /// Boolean değer (null-safe)
  bool? get booleanValue {
    if (currentValue == null) return null;
    if (currentValue is bool) return currentValue as bool;
    if (currentValue is num) return (currentValue as num) != 0;
    if (currentValue is String) {
      final str = (currentValue as String).toLowerCase();
      return str == 'true' || str == '1' || str == 'on';
    }
    return null;
  }

  /// Formatlanmış değer
  String get formattedValue {
    if (currentValue == null) return '-';
    if (isBoolean) {
      return booleanValue == true ? 'ON' : 'OFF';
    }
    if (isNumeric && numericValue != null) {
      final formatted = numericValue!.toStringAsFixed(decimals);
      return unit != null ? '$formatted $unit' : formatted;
    }
    return currentValue.toString();
  }

  /// Alarm durumu
  AlarmState get alarmState {
    if (!isNumeric || numericValue == null) return AlarmState.normal;

    final value = numericValue!;

    if (hiHiLimit != null && value >= hiHiLimit!) return AlarmState.hiHi;
    if (loLoLimit != null && value <= loLoLimit!) return AlarmState.loLo;
    if (hiLimit != null && value >= hiLimit!) return AlarmState.hi;
    if (loLimit != null && value <= loLimit!) return AlarmState.lo;

    return AlarmState.normal;
  }

  /// Alarm durumunda mı?
  bool get inAlarm => alarmState != AlarmState.normal;

  // ============================================
  // SCALING
  // ============================================

  /// Ham değeri ölçeklenmiş değere dönüştür
  double? scaleValue(double rawValue) {
    if (!hasScaling) return rawValue;

    final rawRange = rawMax! - rawMin!;
    if (rawRange == 0) return scaledMin;

    final scaledRange = scaledMax! - scaledMin!;
    return scaledMin! + ((rawValue - rawMin!) / rawRange) * scaledRange;
  }

  /// Ölçeklenmiş değeri ham değere dönüştür
  double? unscaleValue(double scaledValue) {
    if (!hasScaling) return scaledValue;

    final scaledRange = scaledMax! - scaledMin!;
    if (scaledRange == 0) return rawMin;

    final rawRange = rawMax! - rawMin!;
    return rawMin! + ((scaledValue - scaledMin!) / scaledRange) * rawRange;
  }

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Variable.fromJson(Map<String, dynamic> json) {
    return Variable(
      id: json['id'] as String,
      name: json['name'] as String,
      controllerId: json['controller_id'] as String,
      tenantId: json['tenant_id'] as String,
      code: json['code'] as String?,
      description: json['description'] as String?,
      dataType: VariableDataType.fromString(json['data_type'] as String?),
      accessMode: VariableAccessMode.fromString(json['access_mode'] as String?),
      category: VariableCategory.fromString(json['category'] as String?),
      active: json['active'] as bool? ?? true,
      address: json['address'] as String?,
      registerType: json['register_type'] as String?,
      byteOrder: json['byte_order'] as String?,
      bitPosition: json['bit_position'] as int?,
      rawMin: (json['raw_min'] as num?)?.toDouble(),
      rawMax: (json['raw_max'] as num?)?.toDouble(),
      scaledMin: (json['scaled_min'] as num?)?.toDouble(),
      scaledMax: (json['scaled_max'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      decimals: json['decimals'] as int? ?? 2,
      loLoLimit: (json['lolo_limit'] as num?)?.toDouble(),
      loLimit: (json['lo_limit'] as num?)?.toDouble(),
      hiLimit: (json['hi_limit'] as num?)?.toDouble(),
      hiHiLimit: (json['hihi_limit'] as num?)?.toDouble(),
      deadband: (json['deadband'] as num?)?.toDouble(),
      currentValue: json['current_value'],
      quality: VariableQuality.fromString(json['quality'] as String?),
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.tryParse(json['last_updated_at'] as String)
          : null,
      lastChangedAt: json['last_changed_at'] != null
          ? DateTime.tryParse(json['last_changed_at'] as String)
          : null,
      unitId: json['unit_id'] as String?,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'controller_id': controllerId,
      'tenant_id': tenantId,
      'code': code,
      'description': description,
      'data_type': dataType.value,
      'access_mode': accessMode.value,
      'category': category.value,
      'active': active,
      'address': address,
      'register_type': registerType,
      'byte_order': byteOrder,
      'bit_position': bitPosition,
      'raw_min': rawMin,
      'raw_max': rawMax,
      'scaled_min': scaledMin,
      'scaled_max': scaledMax,
      'unit': unit,
      'decimals': decimals,
      'lolo_limit': loLoLimit,
      'lo_limit': loLimit,
      'hi_limit': hiLimit,
      'hihi_limit': hiHiLimit,
      'deadband': deadband,
      'current_value': currentValue,
      'quality': quality.value,
      'last_updated_at': lastUpdatedAt?.toIso8601String(),
      'last_changed_at': lastChangedAt?.toIso8601String(),
      'unit_id': unitId,
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

  Variable copyWith({
    String? id,
    String? name,
    String? controllerId,
    String? tenantId,
    String? code,
    String? description,
    VariableDataType? dataType,
    VariableAccessMode? accessMode,
    VariableCategory? category,
    bool? active,
    String? address,
    String? registerType,
    String? byteOrder,
    int? bitPosition,
    double? rawMin,
    double? rawMax,
    double? scaledMin,
    double? scaledMax,
    String? unit,
    int? decimals,
    double? loLoLimit,
    double? loLimit,
    double? hiLimit,
    double? hiHiLimit,
    double? deadband,
    dynamic currentValue,
    VariableQuality? quality,
    DateTime? lastUpdatedAt,
    DateTime? lastChangedAt,
    String? unitId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Variable(
      id: id ?? this.id,
      name: name ?? this.name,
      controllerId: controllerId ?? this.controllerId,
      tenantId: tenantId ?? this.tenantId,
      code: code ?? this.code,
      description: description ?? this.description,
      dataType: dataType ?? this.dataType,
      accessMode: accessMode ?? this.accessMode,
      category: category ?? this.category,
      active: active ?? this.active,
      address: address ?? this.address,
      registerType: registerType ?? this.registerType,
      byteOrder: byteOrder ?? this.byteOrder,
      bitPosition: bitPosition ?? this.bitPosition,
      rawMin: rawMin ?? this.rawMin,
      rawMax: rawMax ?? this.rawMax,
      scaledMin: scaledMin ?? this.scaledMin,
      scaledMax: scaledMax ?? this.scaledMax,
      unit: unit ?? this.unit,
      decimals: decimals ?? this.decimals,
      loLoLimit: loLoLimit ?? this.loLoLimit,
      loLimit: loLimit ?? this.loLimit,
      hiLimit: hiLimit ?? this.hiLimit,
      hiHiLimit: hiHiLimit ?? this.hiHiLimit,
      deadband: deadband ?? this.deadband,
      currentValue: currentValue ?? this.currentValue,
      quality: quality ?? this.quality,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
      unitId: unitId ?? this.unitId,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'Variable($id, $name, $formattedValue)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Variable && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Alarm durumu
enum AlarmState {
  /// Normal
  normal('NORMAL', 'Normal'),

  /// Düşük
  lo('LO', 'Düşük'),

  /// Düşük-düşük
  loLo('LOLO', 'Çok Düşük'),

  /// Yüksek
  hi('HI', 'Yüksek'),

  /// Yüksek-yüksek
  hiHi('HIHI', 'Çok Yüksek');

  final String value;
  final String label;
  const AlarmState(this.value, this.label);

  /// Kritik alarm mı?
  bool get isCritical => this == loLo || this == hiHi;

  /// Uyarı mı?
  bool get isWarning => this == lo || this == hi;
}

/// Variable değer güncelleme
class VariableValueUpdate {
  /// Variable ID
  final String variableId;

  /// Yeni değer
  final dynamic value;

  /// Kalite
  final VariableQuality quality;

  /// Zaman damgası
  final DateTime timestamp;

  const VariableValueUpdate({
    required this.variableId,
    required this.value,
    this.quality = VariableQuality.good,
    required this.timestamp,
  });

  factory VariableValueUpdate.fromJson(Map<String, dynamic> json) {
    return VariableValueUpdate(
      variableId: json['variable_id'] as String,
      value: json['value'],
      quality: VariableQuality.fromString(json['quality'] as String?),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variable_id': variableId,
      'value': value,
      'quality': quality.value,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

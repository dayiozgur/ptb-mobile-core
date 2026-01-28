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

/// Variable (Değişken/Tag) modeli
///
/// IoT sistemindeki veri noktalarını temsil eder.
/// Variables, device_model bazlı şablonlardır.
/// Controller bağlantısı realtimes junction tablosu üzerinden sağlanır.
///
/// DB Tablosu: variables
/// NOT: DB'de controller_id ve tenant_id kolonları YOKTUR.
/// Controller bağlantısı: realtimes.controller_id ↔ realtimes.variable_id
/// Device model bağlantısı: variables.device_model_id
class Variable {
  /// Benzersiz ID
  final String id;

  /// Variable adı
  final String name;

  /// Variable kodu/tag adı
  final String? code;

  /// Açıklama
  final String? description;

  /// Veri tipi (DB: data_type)
  final VariableDataType dataType;

  /// Erişim modu (DB: read_only bool + read_write int)
  final VariableAccessMode accessMode;

  /// Kategori (DB: grp_category)
  final VariableCategory category;

  /// Aktif mi?
  final bool active;

  // ============================================
  // ADRES BİLGİLERİ
  // ============================================

  /// Giriş adresi (DB: address_input)
  final String? addressInput;

  /// Çıkış adresi (DB: address_output)
  final String? addressOutput;

  /// Bit pozisyonu (boolean için)
  final int? bitPosition;

  // ============================================
  // DEĞER BİLGİLERİ
  // ============================================

  /// Minimum değer (DB: minimum - varchar)
  final String? minimum;

  /// Maksimum değer (DB: maximum - varchar)
  final String? maximum;

  /// Min değer (DB: min_value - numeric)
  final double? minValue;

  /// Max değer (DB: max_value - numeric)
  final double? maxValue;

  /// Varsayılan değer (DB: default_value)
  final String? defaultValue;

  /// A katsayısı (DB: a_value - ölçekleme)
  final double? aValue;

  /// B katsayısı (DB: b_value - ölçekleme)
  final double? bValue;

  /// Birim (°C, kW, %, vb.)
  final String? unit;

  /// Ölçü birimi (DB: measure_unit)
  final String? measureUnit;

  /// Ondalık (DB: decimal - boolean)
  final bool decimal;

  // ============================================
  // MEVCUT DEĞER
  // ============================================

  /// Mevcut değer (DB: value - varchar)
  final String? value;

  /// Durum (DB: status)
  final String? status;

  /// Tip (DB: type)
  final String? type;

  /// Variable alt tipi (DB: variable_type)
  final String? variableType;

  /// Son güncelleme tarihi (DB: last_update)
  final DateTime? lastUpdate;

  // ============================================
  // MODBUS/PROTOKOL BİLGİLERİ
  // ============================================

  /// Boyut (DB: dimension)
  final int? dimension;

  /// Uzunluk (DB: length)
  final int? length;

  /// İşaretli mi? (DB: signed)
  final bool? signed;

  /// Okuma/yazma modu (DB: read_write - int)
  final int? readWrite;

  /// Sadece okunur (DB: read_only)
  final bool? readOnly;

  /// Okuma fonksiyon tipi (DB: func_type_read)
  final int? funcTypeRead;

  /// Yazma fonksiyon tipi (DB: func_type_write)
  final int? funcTypeWrite;

  /// Fonksiyon kodu (DB: function_code)
  final String? functionCode;

  /// Encoding (DB: var_encoding)
  final int? varEncoding;

  // ============================================
  // BAYRAKLAR
  // ============================================

  /// Aktif mi? (DB: is_active)
  final bool? isActive;

  /// İptal edilmiş mi? (DB: is_cancelled)
  final bool? isCancelled;

  /// Loglanıyor mu? (DB: is_logged)
  final bool? isLogged;

  /// Mantıksal mı? (DB: is_logic)
  final bool? isLogic;

  /// Değişiklikte mi? (DB: is_on_change)
  final bool? isOnChange;

  /// HACCP mi? (DB: ishaccp)
  final bool? isHaccp;

  /// Zaman serisi etkin mi? (DB: time_series_enabled)
  final bool? timeSeriesEnabled;

  // ============================================
  // GÖRSEL BİLGİLERİ
  // ============================================

  /// Renk (DB: color)
  final String? color;

  /// Frekans (DB: frequency)
  final String? frequency;

  /// Gecikme (DB: delay)
  final String? delay;

  /// Delta (DB: delta)
  final String? delta;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Device Model ID (DB: device_model_id FK)
  final String? deviceModelId;

  /// Priority ID (DB: priority_id FK)
  final String? priorityId;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime? createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Oluşturan kullanıcı
  final String? createdBy;

  /// Güncelleyen kullanıcı
  final String? updatedBy;

  const Variable({
    required this.id,
    required this.name,
    this.code,
    this.description,
    this.dataType = VariableDataType.float32,
    this.accessMode = VariableAccessMode.readOnly,
    this.category = VariableCategory.other,
    this.active = true,
    this.addressInput,
    this.addressOutput,
    this.bitPosition,
    this.minimum,
    this.maximum,
    this.minValue,
    this.maxValue,
    this.defaultValue,
    this.aValue,
    this.bValue,
    this.unit,
    this.measureUnit,
    this.decimal = false,
    this.value,
    this.status,
    this.type,
    this.variableType,
    this.lastUpdate,
    this.dimension,
    this.length,
    this.signed,
    this.readWrite,
    this.readOnly,
    this.funcTypeRead,
    this.funcTypeWrite,
    this.functionCode,
    this.varEncoding,
    this.isActive,
    this.isCancelled,
    this.isLogged,
    this.isLogic,
    this.isOnChange,
    this.isHaccp,
    this.timeSeriesEnabled,
    this.color,
    this.frequency,
    this.delay,
    this.delta,
    this.deviceModelId,
    this.priorityId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Okunabilir mi?
  bool get isReadable =>
      readOnly == true ||
      accessMode == VariableAccessMode.readOnly ||
      accessMode == VariableAccessMode.readWrite;

  /// Yazılabilir mi?
  bool get isWritable =>
      readOnly == false ||
      accessMode == VariableAccessMode.writeOnly ||
      accessMode == VariableAccessMode.readWrite;

  /// Numeric değer mi?
  bool get isNumeric => dataType.isNumeric;

  /// Boolean değer mi?
  bool get isBoolean => dataType == VariableDataType.boolean;

  /// Ölçekleme tanımlı mı?
  bool get hasScaling => aValue != null && bValue != null;

  /// Numeric değer (null-safe)
  double? get numericValue {
    if (value == null) return null;
    return double.tryParse(value!);
  }

  /// Boolean değer (null-safe)
  bool? get booleanValue {
    if (value == null) return null;
    final str = value!.toLowerCase();
    return str == 'true' || str == '1' || str == 'on';
  }

  /// Formatlanmış değer
  String get formattedValue {
    if (value == null || value!.isEmpty) return '-';
    if (isBoolean) {
      return booleanValue == true ? 'ON' : 'OFF';
    }
    if (isNumeric && numericValue != null) {
      final formatted = decimal
          ? numericValue!.toStringAsFixed(2)
          : numericValue!.toStringAsFixed(0);
      final displayUnit = unit ?? measureUnit;
      return displayUnit != null ? '$formatted $displayUnit' : formatted;
    }
    return value!;
  }

  /// Adres (geriye uyumluluk - addressInput kullanır)
  String? get address => addressInput;

  // ============================================
  // SCALING
  // ============================================

  /// Ham değeri ölçeklenmiş değere dönüştür (y = a*x + b)
  double? scaleValue(double rawValue) {
    if (!hasScaling) return rawValue;
    return aValue! * rawValue + bValue!;
  }

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory Variable.fromJson(Map<String, dynamic> json) {
    return Variable(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      description: json['description'] as String?,
      dataType: VariableDataType.fromString(json['data_type'] as String?),
      accessMode: json['read_only'] == true
          ? VariableAccessMode.readOnly
          : json['read_write'] != null && (json['read_write'] as int) > 0
              ? VariableAccessMode.readWrite
              : VariableAccessMode.readOnly,
      category: VariableCategory.fromString(json['grp_category'] as String? ?? json['category'] as String?),
      active: json['active'] as bool? ?? true,
      addressInput: json['address_input'] != null
          ? json['address_input'].toString()
          : json['address'] as String?,
      addressOutput: json['address_output'] != null
          ? json['address_output'].toString()
          : null,
      bitPosition: json['bit_position'] as int?,
      minimum: json['minimum'] as String?,
      maximum: json['maximum'] as String?,
      minValue: (json['min_value'] as num?)?.toDouble(),
      maxValue: (json['max_value'] as num?)?.toDouble(),
      defaultValue: json['default_value'] as String?,
      aValue: (json['a_value'] as num?)?.toDouble(),
      bValue: (json['b_value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      measureUnit: json['measure_unit'] as String?,
      decimal: json['decimal'] as bool? ?? false,
      value: json['value'] as String?,
      status: json['status'] as String?,
      type: json['type'] as String?,
      variableType: json['variable_type'] as String?,
      lastUpdate: json['last_update'] != null
          ? DateTime.tryParse(json['last_update'] as String)
          : null,
      dimension: json['dimension'] as int?,
      length: json['length'] as int?,
      signed: json['signed'] as bool?,
      readWrite: json['read_write'] as int?,
      readOnly: json['read_only'] as bool?,
      funcTypeRead: json['func_type_read'] as int?,
      funcTypeWrite: json['func_type_write'] as int?,
      functionCode: json['function_code'] as String?,
      varEncoding: json['var_encoding'] as int?,
      isActive: json['is_active'] as bool?,
      isCancelled: json['is_cancelled'] as bool?,
      isLogged: json['is_logged'] as bool?,
      isLogic: json['is_logic'] as bool?,
      isOnChange: json['is_on_change'] as bool?,
      isHaccp: json['ishaccp'] as bool?,
      timeSeriesEnabled: json['time_series_enabled'] as bool?,
      color: json['color'] as String?,
      frequency: json['frequency'] as String?,
      delay: json['delay'] as String?,
      delta: json['delta'] as String?,
      deviceModelId: json['device_model_id'] as String?,
      priorityId: json['priority_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
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
      'code': code,
      'description': description,
      'data_type': dataType.value,
      'grp_category': category.value,
      'active': active,
      'address_input': addressInput,
      'address_output': addressOutput,
      'bit_position': bitPosition,
      'minimum': minimum,
      'maximum': maximum,
      'min_value': minValue,
      'max_value': maxValue,
      'default_value': defaultValue,
      'a_value': aValue,
      'b_value': bValue,
      'unit': unit,
      'measure_unit': measureUnit,
      'decimal': decimal,
      'value': value,
      'status': status,
      'type': type,
      'variable_type': variableType,
      'last_update': lastUpdate?.toIso8601String(),
      'dimension': dimension,
      'length': length,
      'signed': signed,
      'read_write': readWrite,
      'read_only': readOnly,
      'func_type_read': funcTypeRead,
      'func_type_write': funcTypeWrite,
      'function_code': functionCode,
      'var_encoding': varEncoding,
      'is_active': isActive,
      'is_cancelled': isCancelled,
      'is_logged': isLogged,
      'is_logic': isLogic,
      'is_on_change': isOnChange,
      'ishaccp': isHaccp,
      'time_series_enabled': timeSeriesEnabled,
      'color': color,
      'frequency': frequency,
      'delay': delay,
      'delta': delta,
      'device_model_id': deviceModelId,
      'priority_id': priorityId,
      'created_at': createdAt?.toIso8601String(),
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
    String? code,
    String? description,
    VariableDataType? dataType,
    VariableAccessMode? accessMode,
    VariableCategory? category,
    bool? active,
    String? addressInput,
    String? addressOutput,
    int? bitPosition,
    String? minimum,
    String? maximum,
    double? minValue,
    double? maxValue,
    String? defaultValue,
    double? aValue,
    double? bValue,
    String? unit,
    String? measureUnit,
    bool? decimal,
    String? value,
    String? status,
    String? type,
    String? variableType,
    DateTime? lastUpdate,
    int? dimension,
    int? length,
    bool? signed,
    int? readWrite,
    bool? readOnly,
    int? funcTypeRead,
    int? funcTypeWrite,
    String? functionCode,
    int? varEncoding,
    bool? isActive,
    bool? isCancelled,
    bool? isLogged,
    bool? isLogic,
    bool? isOnChange,
    bool? isHaccp,
    bool? timeSeriesEnabled,
    String? color,
    String? frequency,
    String? delay,
    String? delta,
    String? deviceModelId,
    String? priorityId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Variable(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      dataType: dataType ?? this.dataType,
      accessMode: accessMode ?? this.accessMode,
      category: category ?? this.category,
      active: active ?? this.active,
      addressInput: addressInput ?? this.addressInput,
      addressOutput: addressOutput ?? this.addressOutput,
      bitPosition: bitPosition ?? this.bitPosition,
      minimum: minimum ?? this.minimum,
      maximum: maximum ?? this.maximum,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      defaultValue: defaultValue ?? this.defaultValue,
      aValue: aValue ?? this.aValue,
      bValue: bValue ?? this.bValue,
      unit: unit ?? this.unit,
      measureUnit: measureUnit ?? this.measureUnit,
      decimal: decimal ?? this.decimal,
      value: value ?? this.value,
      status: status ?? this.status,
      type: type ?? this.type,
      variableType: variableType ?? this.variableType,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      dimension: dimension ?? this.dimension,
      length: length ?? this.length,
      signed: signed ?? this.signed,
      readWrite: readWrite ?? this.readWrite,
      readOnly: readOnly ?? this.readOnly,
      funcTypeRead: funcTypeRead ?? this.funcTypeRead,
      funcTypeWrite: funcTypeWrite ?? this.funcTypeWrite,
      functionCode: functionCode ?? this.functionCode,
      varEncoding: varEncoding ?? this.varEncoding,
      isActive: isActive ?? this.isActive,
      isCancelled: isCancelled ?? this.isCancelled,
      isLogged: isLogged ?? this.isLogged,
      isLogic: isLogic ?? this.isLogic,
      isOnChange: isOnChange ?? this.isOnChange,
      isHaccp: isHaccp ?? this.isHaccp,
      timeSeriesEnabled: timeSeriesEnabled ?? this.timeSeriesEnabled,
      color: color ?? this.color,
      frequency: frequency ?? this.frequency,
      delay: delay ?? this.delay,
      delta: delta ?? this.delta,
      deviceModelId: deviceModelId ?? this.deviceModelId,
      priorityId: priorityId ?? this.priorityId,
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

/// Variable değer güncelleme
class VariableValueUpdate {
  /// Variable ID
  final String variableId;

  /// Yeni değer
  final String? value;

  /// Zaman damgası
  final DateTime timestamp;

  const VariableValueUpdate({
    required this.variableId,
    required this.value,
    required this.timestamp,
  });

  factory VariableValueUpdate.fromJson(Map<String, dynamic> json) {
    return VariableValueUpdate(
      variableId: json['variable_id'] as String,
      value: json['value'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variable_id': variableId,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

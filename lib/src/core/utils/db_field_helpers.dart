/// Veritabanı alan yardımcıları
///
/// DB'de legacy ve current kolon isimleri arasındaki tutarsızlıkları
/// yönetmek için yardımcı fonksiyonlar.
///
/// ## Bilinen Dual Column Yapıları
///
/// ### logs tablosu:
/// - datetime (legacy) / date_time (current)
/// - onoff (legacy) / on_off (current)
///
/// ### alarms tablosu:
/// - arrival_endtime (legacy) / arrival_end_time (current)
///
/// ### controllers tablosu:
/// - model_code (legacy) / model (current)
/// - serial (legacy) / serial_number (current)
/// - ip (legacy) / ip_address (current)
/// - last_connection_time (legacy) / last_connected_at (current)
///
/// ### providers tablosu:
/// - host (legacy) / ip (current)
/// - last_connection_time (legacy) / last_connected_at (current)
///
/// Bu yardımcı fonksiyonlar, her iki kolon ismini de destekleyerek
/// veri okuma işlemlerinde tutarlılık sağlar.
class DbFieldHelpers {
  DbFieldHelpers._();

  // ============================================
  // DATE/TIME FIELDS
  // ============================================

  /// DateTime alanını parse et (dual column desteği)
  ///
  /// [json] kaynak map
  /// [currentKey] mevcut/tercih edilen anahtar (örn: 'date_time')
  /// [legacyKey] eski anahtar (örn: 'datetime')
  static DateTime? parseDateTime(
    Map<String, dynamic> json,
    String currentKey, [
    String? legacyKey,
  ]) {
    final value = json[currentKey] ?? (legacyKey != null ? json[legacyKey] : null);
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  /// Logs tablosu için date_time/datetime alanını parse et
  static DateTime? parseLogDateTime(Map<String, dynamic> json) {
    return parseDateTime(json, 'date_time', 'datetime');
  }

  // ============================================
  // INTEGER FIELDS
  // ============================================

  /// Integer alanını parse et (dual column desteği)
  ///
  /// [json] kaynak map
  /// [currentKey] mevcut/tercih edilen anahtar
  /// [legacyKey] eski anahtar
  static int? parseInt(
    Map<String, dynamic> json,
    String currentKey, [
    String? legacyKey,
  ]) {
    return json[currentKey] as int? ??
        (legacyKey != null ? json[legacyKey] as int? : null);
  }

  /// Logs tablosu için on_off/onoff alanını parse et
  static int? parseLogOnOff(Map<String, dynamic> json) {
    return parseInt(json, 'on_off', 'onoff');
  }

  // ============================================
  // STRING FIELDS
  // ============================================

  /// String alanını parse et (dual column desteği)
  ///
  /// [json] kaynak map
  /// [currentKey] mevcut/tercih edilen anahtar
  /// [legacyKey] eski anahtar
  static String? parseString(
    Map<String, dynamic> json,
    String currentKey, [
    String? legacyKey,
  ]) {
    return json[currentKey] as String? ??
        (legacyKey != null ? json[legacyKey] as String? : null);
  }

  /// Controller model/model_code alanını parse et
  static String? parseControllerModel(Map<String, dynamic> json) {
    return parseString(json, 'model_code', 'model');
  }

  /// Controller serial/serial_number alanını parse et
  static String? parseControllerSerial(Map<String, dynamic> json) {
    return parseString(json, 'serial', 'serial_number');
  }

  /// Controller ip/ip_address alanını parse et
  static String? parseControllerIp(Map<String, dynamic> json) {
    return parseString(json, 'ip', 'ip_address');
  }

  // ============================================
  // ALARM SPECIFIC
  // ============================================

  /// Alarm arrival_endtime/arrival_end_time alanını parse et
  static DateTime? parseAlarmArrivalEndTime(Map<String, dynamic> json) {
    return parseDateTime(json, 'arrival_endtime', 'arrival_end_time');
  }

  // ============================================
  // CONTROLLER SPECIFIC
  // ============================================

  /// Controller last_connection_time/last_connected_at alanını parse et
  static DateTime? parseControllerLastConnection(Map<String, dynamic> json) {
    return parseDateTime(json, 'last_connection_time', 'last_connected_at');
  }

  /// Controller last_communication_time/last_data_at alanını parse et
  static DateTime? parseControllerLastData(Map<String, dynamic> json) {
    return parseDateTime(json, 'last_communication_time', 'last_data_at');
  }
}

/// DB alan mapping bilgisi
///
/// Her bir dual column için mapping bilgisini tutar.
class DbFieldMapping {
  /// Mevcut/tercih edilen alan adı
  final String currentKey;

  /// Legacy alan adı
  final String legacyKey;

  /// Açıklama
  final String description;

  const DbFieldMapping({
    required this.currentKey,
    required this.legacyKey,
    required this.description,
  });
}

/// Bilinen dual column mapping'leri
///
/// Bu liste, DB'deki tutarsız alan isimlerini dokümante eder.
const knownDualColumnMappings = <DbFieldMapping>[
  // Logs tablosu
  DbFieldMapping(
    currentKey: 'date_time',
    legacyKey: 'datetime',
    description: 'Log zaman damgası',
  ),
  DbFieldMapping(
    currentKey: 'on_off',
    legacyKey: 'onoff',
    description: 'Log on/off durumu',
  ),
  // Alarms tablosu
  DbFieldMapping(
    currentKey: 'arrival_end_time',
    legacyKey: 'arrival_endtime',
    description: 'Alarm varış bitiş zamanı',
  ),
  // Controllers tablosu
  DbFieldMapping(
    currentKey: 'model',
    legacyKey: 'model_code',
    description: 'Controller model kodu',
  ),
  DbFieldMapping(
    currentKey: 'serial_number',
    legacyKey: 'serial',
    description: 'Controller seri numarası',
  ),
  DbFieldMapping(
    currentKey: 'ip_address',
    legacyKey: 'ip',
    description: 'Controller IP adresi',
  ),
  DbFieldMapping(
    currentKey: 'last_connected_at',
    legacyKey: 'last_connection_time',
    description: 'Controller son bağlantı zamanı',
  ),
];

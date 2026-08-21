import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../utils/logger.dart';

/// Anlık hava durumu verisi (open-meteo `current`).
class WeatherData {
  /// Sıcaklık (°C).
  final double temperature;

  /// WMO hava-durumu kodu.
  final int code;

  /// Türkçe durum etiketi (koddan türetilir).
  final String condition;

  /// Şehir/konum adı (gösterim için).
  final String city;

  const WeatherData({
    required this.temperature,
    required this.code,
    required this.condition,
    required this.city,
  });
}

/// Hava durumu servisi — **open-meteo** (anahtarsız/ücretsiz) `current` uç
/// noktasını çağırır. Mobilde CSP kısıtı olmadığından doğrudan istemciden
/// çağrılır (web'de böyle bir widget YOK — bu mobil-özel bir eklentidir).
///
/// MVP: cihaz konumu yerine widget `config`'inden (veya varsayılan İstanbul)
/// lat/lon kullanılır — iOS konum-izni/Info.plist gereksinimi olmadan anında
/// çalışır. İleride konum izniyle cihaz-konumu eklenebilir.
class WeatherService {
  final Dio _dio;

  WeatherService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  /// Varsayılan konum: İstanbul.
  static const double defaultLat = 41.0082;
  static const double defaultLon = 28.9784;
  static const String defaultCity = 'İstanbul';

  static const String _endpoint = 'https://api.open-meteo.com/v1/forecast';

  /// Anlık hava durumunu getir. [lat]/[lon] verilmezse varsayılan (İstanbul).
  Future<WeatherData> current({
    double? lat,
    double? lon,
    String? city,
  }) async {
    final la = lat ?? defaultLat;
    final lo = lon ?? defaultLon;
    final cityName =
        (city != null && city.trim().isNotEmpty) ? city.trim() : defaultCity;
    try {
      final resp = await _dio.get(
        _endpoint,
        queryParameters: {
          'latitude': la,
          'longitude': lo,
          'current': 'temperature_2m,weather_code',
          'timezone': 'auto',
        },
      );
      final data = resp.data as Map<String, dynamic>;
      final cur = (data['current'] as Map?)?.cast<String, dynamic>() ?? const {};
      final temp = (cur['temperature_2m'] as num?)?.toDouble() ?? 0;
      final code = (cur['weather_code'] as num?)?.toInt() ?? 0;
      return WeatherData(
        temperature: temp,
        code: code,
        condition: conditionLabel(code),
        city: cityName,
      );
    } catch (e) {
      Logger.warning('Weather fetch failed: $e');
      rethrow;
    }
  }

  /// WMO kodu → Türkçe durum etiketi.
  static String conditionLabel(int code) {
    if (code == 0) return 'Açık';
    if (code == 1) return 'Az bulutlu';
    if (code == 2) return 'Parçalı bulutlu';
    if (code == 3) return 'Bulutlu';
    if (code == 45 || code == 48) return 'Sisli';
    if (code >= 51 && code <= 57) return 'Çisenti';
    if (code >= 61 && code <= 67) return 'Yağmurlu';
    if (code >= 71 && code <= 77) return 'Karlı';
    if (code >= 80 && code <= 82) return 'Sağanak';
    if (code >= 85 && code <= 86) return 'Kar sağanağı';
    if (code >= 95) return 'Gök gürültülü';
    return 'Bilinmiyor';
  }

  /// WMO kodu → Material ikon.
  static IconData conditionIcon(int code) {
    if (code == 0 || code == 1) return Icons.wb_sunny_outlined;
    if (code == 2) return Icons.wb_cloudy_outlined;
    if (code == 3) return Icons.cloud_outlined;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 57) return Icons.grain;
    if (code >= 61 && code <= 67) return Icons.water_drop_outlined;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.umbrella_outlined;
    if (code >= 85 && code <= 86) return Icons.ac_unit;
    if (code >= 95) return Icons.thunderstorm_outlined;
    return Icons.thermostat_outlined;
  }
}

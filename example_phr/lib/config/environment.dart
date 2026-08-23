import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration (PHR app).
class Environment {
  Environment._();

  /// Splash/marka rengi (platform_app_configs.primary_color ile eşleşir).
  static const Color brandColor = Color(0xFF7C3AED);

  /// Splash slogan (platform_app_configs.brand_tagline).
  static const String slogan = 'İnsan kaynakları yönetimi';

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';

  static String get appName => dotenv.env['APP_NAME'] ?? 'Protoolbag HR';

  static bool get isDebugMode =>
      dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';

  /// Zorunlu değişkenleri doğrula.
  static void validate() {
    final required = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];
    final missing = <String>[];
    for (final key in required) {
      if (dotenv.env[key]?.isEmpty ?? true) missing.add(key);
    }
    if (missing.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missing.join(', ')}',
      );
    }
  }
}

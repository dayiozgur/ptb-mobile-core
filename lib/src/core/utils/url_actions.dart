import 'package:url_launcher/url_launcher.dart';

/// **URL aksiyonları** — `tel:` / `mailto:` / harici URL açma. BuildContext'siz
/// saf yardımcı; başarı `bool` döner (çağıran gerekirse SnackBar gösterir).
/// Önceden CRM kişi-detayına gömülüydü; her platform (PHR çalışan-ara, PMS
/// saha/sağlayıcı-ara, PPM) kullanabilsin diye çekirdeğe alındı.
class UrlActions {
  UrlActions._();

  static Future<bool> _launch(String uri) async {
    try {
      return await launchUrl(
        Uri.parse(uri),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// Telefon çevir (tel:).
  static Future<bool> dialPhone(String phone) => _launch('tel:${phone.trim()}');

  /// E-posta oluştur (mailto:).
  static Future<bool> sendEmail(String email) =>
      _launch('mailto:${email.trim()}');

  /// Harici URL aç.
  static Future<bool> openUrl(String url) => _launch(url.trim());

  /// Şema dahil ham uri aç (tel:/mailto:/https: …).
  static Future<bool> openUri(String uri) => _launch(uri);
}

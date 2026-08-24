import 'package:protoolbag_core/protoolbag_core.dart';

/// PPM ekranları için ortak i18n yardımcısı.
///
/// Anahtar bulunamazsa (`translate` anahtarın kendisini geri döndürür)
/// Türkçe [fallback] gösterilir — böylece DB seed'i gecikse bile UI güvenli
/// biçimde Türkçe görünür.
String ppmT(String key, String fallback) {
  final v = sl<LocalizationService>().translate(key);
  return v == key ? fallback : v;
}

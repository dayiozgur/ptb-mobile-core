import 'package:image_cropper/image_cropper.dart';

/// OCR ÖNCESİ görüntü kırpma — seçilen/çekilen fotoğrafı native kırpma UI'ı
/// (iOS TOCropViewController / Android uCrop) ile kullanıcıya çerçeveletir.
/// Kartın/belgenin dışındaki gürültü atılır → OCR doğruluğu artar.
///
/// [ratioX]/[ratioY] verilirse en-boy oranı kilitlenir (kartvizit 85.6×54mm ≈
/// 1.585:1); ikisi de null → serbest oran (fiş/fatura, değişken uzunluk).
/// İptal/hata → orijinal path döner (kırpma OPSİYONEL — akışı asla bozmaz).
class ScanCropper {
  static Future<String> crop(
    String sourcePath, {
    double? ratioX,
    double? ratioY,
    String title = 'Çerçevele',
  }) async {
    final locked = ratioX != null && ratioY != null;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio:
            locked ? CropAspectRatio(ratioX: ratioX, ratioY: ratioY) : null,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title,
            lockAspectRatio: locked,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: locked,
          ),
        ],
      );
      return cropped?.path ?? sourcePath;
    } catch (_) {
      // Kırpma başarısızsa OCR ham görselle çalışsın (kesinti olmasın).
      return sourcePath;
    }
  }
}

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'ocr_models.dart';
import 'receipt_parser.dart';
import 'scan_cropper.dart';

/// Fatura/fiş görsel kaynağı (image_picker'ı çekirdekte kapsüller).
enum DocumentScanSource { camera, gallery }

/// **Fatura/fiş tarama** — kamera/galeriden görsel al, on-device OCR (Google
/// MLKit, bulut/anahtar YOK), MLKit satır bounding-box'larını [OcrLine]'a
/// indirge, [ReceiptParser] ile Türk fiş/fatura alanlarını çıkar.
///
/// [CardScanner]'dan farkı: kartvizit düz metni kullanır; burada 2-boyutlu
/// tablo geometrisi (sağa-hizalı tutar sütunu) korunur → doğruluk için şart.
/// Sonuç [DocumentScanResult]; kullanıcı ZORUNLU onay ekranında düzeltir.
class DocumentScanner {
  final ImagePicker _picker;
  DocumentScanner({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Görsel seç → OCR → ayrıştır. İptal → null.
  Future<ReceiptScanResult?> scan({
    DocumentScanSource source = DocumentScanSource.camera,
  }) async {
    final XFile? shot = await _picker.pickImage(
      source: source == DocumentScanSource.gallery
          ? ImageSource.gallery
          : ImageSource.camera,
      imageQuality: 100, // belge: metin detayı > dosya boyutu
    );
    if (shot == null) return null;

    // OCR öncesi: kullanıcı fişi/faturayı çerçevelesin (serbest oran — belge
    // uzunluğu değişken). İptal → ham görselle devam.
    final path = await ScanCropper.crop(shot.path, title: 'Belgeyi çerçevele');

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(input);
      return ReceiptParser.parse(
        toOcrLines(recognized),
        rawText: recognized.text,
      );
    } finally {
      await recognizer.close();
    }
  }

  /// MLKit `RecognizedText` ağacını (blok→satır, bounding-box) [OcrLine]
  /// listesine indirger. Ayrı fonksiyon — geometri eşlemesi izole test edilir.
  static List<OcrLine> toOcrLines(RecognizedText recognized) {
    final out = <OcrLine>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final b = line.boundingBox;
        out.add(OcrLine(
          text: line.text,
          left: b.left,
          top: b.top,
          right: b.right,
          bottom: b.bottom,
        ));
      }
    }
    return out;
  }
}

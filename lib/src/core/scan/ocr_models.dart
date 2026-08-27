/// Fatura/fiş OCR ara-modelleri — MLKit'ten bağımsız (saf, test-edilebilir).
///
/// [DocumentScanner] MLKit `RecognizedText` ağacını (blok→satır, her satır
/// bounding-box) [OcrLine] listesine indirger; [ReceiptParser] yalnız bu
/// listeyi tüketir. Böylece geometri sezgileri (satır-rekonstrüksiyon,
/// sağa-hizalı tutar) MLKit olmadan birim-testlenebilir.
library;

/// OCR'ın tanıdığı tek bir metin satırı + sayfa-piksel koordinatları.
class OcrLine {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrLine({
    required this.text,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  double get centerY => (top + bottom) / 2;
  double get height => (bottom - top).abs();
}

/// Tek bir KDV oranı için matrah + vergi tutarı.
class VatLine {
  /// Yüzde (ör. 20, 10, 1). Bilinmiyorsa null.
  final int? rate;

  /// KDV matrahı (vergi hariç tutar). Bilinmiyorsa null.
  final double? base;

  /// KDV tutarı.
  final double? amount;

  const VatLine({this.rate, this.base, this.amount});
}

/// Fatura/fiş ayrıştırma sonucu. Tüm alanlar opsiyonel; kullanıcı onay
/// ekranında düzeltir. [fieldConfidence] alan-başına 0..1 güven; [warnings]
/// aritmetik/format uyarıları (kırmızı işaretlenecek alanlar).
class ReceiptScanResult {
  /// Genel/ödenecek toplam.
  final double? total;

  /// Ara toplam (vergi hariç mal/hizmet).
  final double? subTotal;

  /// KDV satırları (oran başına).
  final List<VatLine> vatLines;

  /// ISO tarih (yyyy-MM-dd).
  final String? date;

  /// Saat (HH:mm).
  final String? time;

  /// Fiş/fatura/belge numarası.
  final String? documentNo;

  /// Vergi no (VKN 10 hane) veya TCKN (11 hane).
  final String? taxNumber;

  /// Satıcı/işletme ünvanı.
  final String? merchant;

  /// Okunan ham metin (kullanıcı gözden geçirsin / hiçbir şey çıkmazsa görsün).
  final String rawText;

  /// Alan-başına güven skoru (0..1). Anahtarlar: total/subTotal/date/taxNumber…
  final Map<String, double> fieldConfidence;

  /// Doğrulama uyarıları (ör. "KDV toplamı genel toplamla tutmuyor").
  final List<String> warnings;

  /// Alan-başına kaynak OCR satırı + bounding-box (görüntü-piksel koordinat).
  /// Anahtarlar [fieldConfidence] ile aynı (total/subTotal/date/taxNumber/
  /// merchant/documentNo). Onay ekranında taranan görüntü üzerine okunan
  /// alanların kutusu çizilir (düşük-güven kırmızı). Boş = geometri yok.
  final Map<String, OcrLine> fieldBoxes;

  /// Kırpılmış/taranan görüntünün yerel dosya yolu (onay ekranında Image.file
  /// ile gösterilip üstüne [fieldBoxes] overlay çizilir). null = görüntü yok.
  final String? imagePath;

  const ReceiptScanResult({
    this.total,
    this.subTotal,
    this.vatLines = const [],
    this.date,
    this.time,
    this.documentNo,
    this.taxNumber,
    this.merchant,
    this.rawText = '',
    this.fieldConfidence = const {},
    this.warnings = const [],
    this.fieldBoxes = const {},
    this.imagePath,
  });

  /// Belirli alanları değiştirip yeni sonuç üretir (onay ekranı düzeltmeleri
  /// [fieldBoxes]/[imagePath] gibi geometriyi kaybetmesin diye).
  ReceiptScanResult copyWith({
    double? total,
    double? subTotal,
    List<VatLine>? vatLines,
    String? date,
    String? time,
    String? documentNo,
    String? taxNumber,
    String? merchant,
    String? rawText,
    Map<String, double>? fieldConfidence,
    List<String>? warnings,
    Map<String, OcrLine>? fieldBoxes,
    String? imagePath,
  }) {
    return ReceiptScanResult(
      total: total ?? this.total,
      subTotal: subTotal ?? this.subTotal,
      vatLines: vatLines ?? this.vatLines,
      date: date ?? this.date,
      time: time ?? this.time,
      documentNo: documentNo ?? this.documentNo,
      taxNumber: taxNumber ?? this.taxNumber,
      merchant: merchant ?? this.merchant,
      rawText: rawText ?? this.rawText,
      fieldConfidence: fieldConfidence ?? this.fieldConfidence,
      warnings: warnings ?? this.warnings,
      fieldBoxes: fieldBoxes ?? this.fieldBoxes,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  /// Hiçbir anlamlı alan çıkmadı mı?
  bool get isEmpty =>
      total == null &&
      subTotal == null &&
      date == null &&
      documentNo == null &&
      taxNumber == null &&
      vatLines.isEmpty;

  /// Toplam KDV (satırların tutarları).
  double? get totalVat {
    final amounts = vatLines.map((v) => v.amount).whereType<double>();
    if (amounts.isEmpty) return null;
    return amounts.fold<double>(0, (a, b) => a + b);
  }
}

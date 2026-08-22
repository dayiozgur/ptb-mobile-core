import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Kartvizit taramasından çıkarılan alanlar (hepsi opsiyonel; kullanıcı
/// hızlı-ekle formunda düzeltir/tamamlar).
class CardScanResult {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? title;

  const CardScanResult({
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.title,
  });

  bool get isEmpty =>
      (firstName ?? '').isEmpty &&
      (lastName ?? '').isEmpty &&
      (email ?? '').isEmpty &&
      (phone ?? '').isEmpty;
}

/// **Kartvizit tarama** — kamera ile fotoğraf çek, on-device OCR (Google MLKit,
/// bulut/anahtar YOK) ile metni çıkar, alanları sezgisel ayrıştır. Sonuç
/// hızlı-ekle formunu ön-doldurur; kayıt mevcut `contacts` insert yolundan.
class CardScanner {
  final ImagePicker _picker;
  CardScanner({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Kamera → OCR → ayrıştırma. Kullanıcı iptal ederse null döner.
  Future<CardScanResult?> scanFromCamera() async {
    final XFile? shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (shot == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(shot.path);
      final recognized = await recognizer.processImage(input);
      return parseCardText(recognized.text);
    } finally {
      await recognizer.close();
    }
  }

  /// OCR metnini alanlara ayrıştırır (saf fonksiyon — test edilebilir).
  static CardScanResult parseCardText(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const CardScanResult();

    final emailRe = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');
    // En az 7 rakam içeren telefon-benzeri dizi.
    final phoneRe = RegExp(r'(\+?\d[\d\s()\-\.]{6,}\d)');
    final titleKw = RegExp(
      r'(müdür|mudur|yönetici|yonetici|müh|muh|mühendis|muhendis|uzman|'
      r'direktör|direktor|manager|director|engineer|specialist|officer|'
      r'ceo|cto|cfo|coo|founder|kurucu|satış|satis|pazarlama|sales|'
      r'marketing|developer|geliştirici|gelistirici|analyst|analist|'
      r'consultant|danışman|danisman|lead|head|chief|president|başkan|baskan)',
      caseSensitive: false,
    );
    final companyKw = RegExp(
      r'(a\.?ş\.?|ltd|inc\.?|corp|gmbh|co\.|company|şti|sti|holding|'
      r'teknoloji|technolog|yazılım|yazilim|software|solutions|group|grup)',
      caseSensitive: false,
    );
    final urlRe = RegExp(r'(https?://|www\.)', caseSensitive: false);

    String? email;
    String? phone;
    String? title;
    final nameCandidates = <String>[];

    for (final line in lines) {
      final em = emailRe.firstMatch(line);
      if (em != null && email == null) email = em.group(0);

      if (phone == null) {
        final ph = phoneRe.firstMatch(line);
        if (ph != null) {
          final digits = ph.group(0)!.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 7) phone = ph.group(0)!.trim();
        }
      }

      final hasEmail = emailRe.hasMatch(line);
      final hasPhone = phoneRe.hasMatch(line);
      final isUrl = urlRe.hasMatch(line);
      final isCompany = companyKw.hasMatch(line);
      final isTitle = titleKw.hasMatch(line);

      if (isTitle && title == null && !hasEmail && !hasPhone) {
        title = line;
        continue;
      }

      // İsim adayı: e-posta/telefon/url/şirket/unvan DEĞİL, çoğunlukla harf,
      // 2-4 kelime (tipik ad-soyad).
      final wordCount = line.split(RegExp(r'\s+')).length;
      final letterRatio = _letterRatio(line);
      if (!hasEmail &&
          !hasPhone &&
          !isUrl &&
          !isCompany &&
          !isTitle &&
          wordCount >= 1 &&
          wordCount <= 4 &&
          letterRatio > 0.6) {
        nameCandidates.add(line);
      }
    }

    // E-postadan isim tahmini (nameCandidates boşsa): ad.soyad@ → Ad Soyad.
    String? first;
    String? last;
    if (nameCandidates.isNotEmpty) {
      final parts = nameCandidates.first.split(RegExp(r'\s+'));
      first = parts.first;
      if (parts.length > 1) last = parts.sublist(1).join(' ');
    } else if (email != null) {
      final local = email.split('@').first;
      final segs = local.split(RegExp(r'[._\-]+')).where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) first = _capitalize(segs.first);
      if (segs.length > 1) last = _capitalize(segs[1]);
    }

    return CardScanResult(
      firstName: first,
      lastName: last,
      email: email,
      phone: phone,
      title: title,
    );
  }

  static double _letterRatio(String s) {
    if (s.isEmpty) return 0;
    final letters = s.replaceAll(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü]'), '').length;
    return letters / s.length;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

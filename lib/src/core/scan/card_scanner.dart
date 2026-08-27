import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'document_scanner.dart';
import 'ocr_models.dart';
import 'scan_cropper.dart';

/// Kartvizit görsel kaynağı — image_picker'ı çekirdekte kapsüller (çağıran
/// app'lerin image_picker'a doğrudan bağımlı olmasına gerek kalmaz).
enum CardScanSource { camera, gallery }

/// Kartvizit taramasından çıkarılan alanlar (hepsi opsiyonel; kullanıcı
/// hızlı-ekle formunda düzeltir/tamamlar).
class CardScanResult {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? title;
  final String? company;
  final String? website;

  /// OCR'ın okuduğu ham metin (kullanıcı gözden geçirsin / hiçbir şey
  /// çıkmazsa görüp elle girsin diye).
  final String rawText;

  const CardScanResult({
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.title,
    this.company,
    this.website,
    this.rawText = '',
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
  /// Kamera ([ImageSource.camera]) ya da galeri ([ImageSource.gallery]) →
  /// OCR → ayrıştırma. Kullanıcı iptal ederse null döner. Ham OCR metni de
  /// [CardScanResult.rawText]'te döner (kullanıcı gözden geçirsin diye).
  Future<CardScanResult?> scan(
      {CardScanSource source = CardScanSource.camera}) async {
    final XFile? shot = await _picker.pickImage(
      source: source == CardScanSource.gallery
          ? ImageSource.gallery
          : ImageSource.camera,
      imageQuality: 90,
    );
    if (shot == null) return null;

    // OCR öncesi: kullanıcı kartı çerçevelesin (kartvizit oranı kilitli) →
    // arka plan gürültüsü atılır, doğruluk artar. İptal → ham görselle devam.
    final path = await ScanCropper.crop(
      shot.path,
      ratioX: 85.6,
      ratioY: 54,
      title: 'Kartviziti çerçevele',
    );

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(path);
      final recognized = await recognizer.processImage(input);
      // Bbox/geometri KORUNARAK ayrıştır: isim = en büyük fontlu satır, konum
      // (üst→alt) ile blok akışı. Düz metin fallback için rawText de geçilir.
      return parseCardLines(
        DocumentScanner.toOcrLines(recognized),
        rawText: recognized.text,
      );
    } finally {
      await recognizer.close();
    }
  }

  /// Geriye-uyumluluk: kameradan tara.
  Future<CardScanResult?> scanFromCamera() => scan();

  /// Düz OCR metnini ayrıştırır (saf, test-edilebilir). Bbox yoktur → satır
  /// index'i `top` olarak verilir; font eşit olduğundan [parseCardLines]
  /// üst-satır sırasına düşer (eski davranışla uyumlu). Gerçek tarama
  /// [parseCardLines]'ı bbox'lı çağırır (isim = en büyük font).
  static CardScanResult parseCardText(String raw) {
    final rawLines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lines = [
      for (var i = 0; i < rawLines.length; i++)
        OcrLine(text: rawLines[i], top: i.toDouble(), bottom: i.toDouble()),
    ];
    return parseCardLines(lines, rawText: raw);
  }

  /// Bbox'lı OCR satırlarını alanlara ayrıştırır (saf, test-edilebilir).
  ///
  /// Spatial sezgiler (kullanıcı isteği — doğruluk için):
  /// - **İsim = en büyük fontlu** (satır yüksekliği) isim-adayı; eşitse en
  ///   üstteki. Kartvizit tasarımının evrensel kuralı (isim daima en büyük).
  /// - **Firma:** şirket-eki (a.ş./ltd/…) varsa kesin; YOKSA (marka adı,
  ///   ör. "Trendyol") isimden sonraki en büyük ALL-CAPS isim-adayı firma
  ///   sayılır — eski keyword-zorunluluğu isim slotunu çalıyordu.
  /// - **Web sitesi** artık ayrı alana yazılır (eskiden yalnız dışlanıyordu).
  static CardScanResult parseCardLines(List<OcrLine> lines, {String rawText = ''}) {
    final items = lines.where((l) => l.text.trim().isNotEmpty).toList();
    if (items.isEmpty) return CardScanResult(rawText: rawText);

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
    final urlRe = RegExp(
        r'((https?://)?(www\.)[A-Za-z0-9.\-]+\.[A-Za-z]{2,}[^\s]*|(https?://)[^\s]+)',
        caseSensitive: false);

    String? email;
    String? phone;
    String? title;
    String? company;
    String? website;
    final nameCandidates = <OcrLine>[];

    for (final line in items) {
      final text = line.text.trim();

      final em = emailRe.firstMatch(text);
      if (em != null && email == null) email = em.group(0);

      if (phone == null) {
        final ph = phoneRe.firstMatch(text);
        if (ph != null) {
          final digits = ph.group(0)!.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 7) phone = ph.group(0)!.trim();
        }
      }

      final hasEmail = emailRe.hasMatch(text);
      final hasPhone = phoneRe.hasMatch(text);
      final urlMatch = urlRe.firstMatch(text);
      final isUrl = urlMatch != null;
      final isCompany = companyKw.hasMatch(text);
      final isTitle = titleKw.hasMatch(text);

      // Web sitesi: e-posta İÇERMEYEN url satırı (e-posta @'ından sonra da
      // nokta var; onu web sanma).
      if (isUrl && website == null && !hasEmail) {
        website = urlMatch.group(0);
        continue;
      }

      if (isTitle && title == null && !hasEmail && !hasPhone) {
        title = text;
        continue;
      }

      // Firma adayı: şirket-eki içeren satır (kesin). Keyword'süz markalar
      // aşağıda font/caps sezgisiyle yakalanır.
      if (isCompany && company == null && !hasEmail && !hasPhone && !isUrl) {
        company = text;
        continue;
      }

      // İsim adayı: e-posta/telefon/url/şirket/unvan DEĞİL, çoğunlukla harf,
      // 1-4 kelime. Bbox (height/top) sıralama için korunur.
      final wordCount = text.split(RegExp(r'\s+')).length;
      if (!hasEmail &&
          !hasPhone &&
          !isUrl &&
          !isCompany &&
          !isTitle &&
          wordCount >= 1 &&
          wordCount <= 4 &&
          _letterRatio(text) > 0.6) {
        nameCandidates.add(line);
      }
    }

    // İsim = en büyük font (height DESC); eşitse en üstteki (top ASC). Düz-metin
    // fallback'te height hepsi 0, top = satır index → orijinal sıra korunur.
    nameCandidates.sort((a, b) {
      final byHeight = b.height.compareTo(a.height);
      return byHeight != 0 ? byHeight : a.top.compareTo(b.top);
    });

    String? first;
    String? last;
    if (nameCandidates.isNotEmpty) {
      final parts = nameCandidates.first.text.trim().split(RegExp(r'\s+'));
      first = parts.first;
      if (parts.length > 1) last = parts.sublist(1).join(' ');

      // Firma keyword'süz fallback: firma hâlâ boşsa, isimden SONRAKI en büyük
      // isim-adayı ALL-CAPS ise (marka genelde büyük harf) firma say.
      if (company == null && nameCandidates.length > 1) {
        for (final cand in nameCandidates.skip(1)) {
          final t = cand.text.trim();
          if (t == t.toUpperCase() && _letterRatio(t) > 0.6) {
            company = t;
            break;
          }
        }
      }
    } else if (email != null) {
      // E-postadan isim tahmini: ad.soyad@ → Ad Soyad.
      final local = email.split('@').first;
      final segs =
          local.split(RegExp(r'[._\-]+')).where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) first = _capitalize(segs.first);
      if (segs.length > 1) last = _capitalize(segs[1]);
    }

    return CardScanResult(
      firstName: first,
      lastName: last,
      email: email,
      phone: phone,
      title: title,
      company: company,
      website: website,
      rawText: rawText,
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

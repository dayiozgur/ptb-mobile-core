import 'ocr_models.dart';

/// Türk fatura/fiş metnini [ReceiptScanResult]'a ayrıştıran **saf** motor.
///
/// Yalnız [OcrLine] listesini tüketir (MLKit bağımsız → birim-testlenebilir).
/// Doğruluk katmanları: (1) TR sayı/tarih/KDV/VKN sezgileri, (2) geometri —
/// anahtar-kelime satırındaki/sırasındaki sağa-hizalı tutar, (3) aritmetik
/// çapraz-kontrol (ara+ΣKDV≈genel toplam) → uyarı + güven skoru.
class ReceiptParser {
  const ReceiptParser._();

  // ---- Genel toplam / ara toplam / KDV anahtar kelimeleri ----
  static final RegExp _grandTotalKw =
      RegExp(r'(genel\s*toplam|ödenecek|odenecek|toplam\s*tutar)', caseSensitive: false);
  static final RegExp _totalKw =
      RegExp(r'\btoplam\b|\btutar\b', caseSensitive: false);
  static final RegExp _subTotalKw = RegExp(
      r'(ara\s*toplam|mal\s*/?\s*hizmet|matbu|vergi\s*hariç|vergi\s*haric)',
      caseSensitive: false);
  static final RegExp _vatKw =
      RegExp(r'k\.?\s*d\.?\s*v\.?|\bkdv\b', caseSensitive: false);
  static final RegExp _docNoKw = RegExp(
      r'(fiş\s*no|fis\s*no|fatura\s*no|belge\s*no|\bz\s*no\b|ekü|eku|fiş\s*:|seri)',
      caseSensitive: false);
  static final RegExp _taxKw = RegExp(
      r'(vkn|v\.?\s*d\.?|vergi\s*(no|dairesi|kimlik)|tckn|t\.?c\.?\s*kimlik)',
      caseSensitive: false);

  // Ondalıklı tutar tokenı (TR: nokta-binlik, virgül-ondalık) — öncelik.
  static final RegExp _decimalAmount =
      RegExp(r'\d{1,3}(?:\.\d{3})*,\d{1,2}|\d+,\d{1,2}|\d+\.\d{1,2}');
  static final RegExp _rateRe = RegExp(r'%\s?(\d{1,2})|kdv\s*%?\s?(\d{1,2})', caseSensitive: false);

  /// TR biçimli tutarı double'a çevirir. `1.234,56`→1234.56, `12,50`→12.5,
  /// `1.234`→1234 (binlik), `12.50`→12.5. Bulamazsa null.
  static double? parseTurkishAmount(String raw) {
    final s = raw.replaceAll(RegExp(r'(tl|try|₺|\s)', caseSensitive: false), '');
    final m = RegExp(r'-?\d[\d.,]*\d|\d').firstMatch(s);
    if (m == null) return null;
    var num = m.group(0)!;
    final hasComma = num.contains(',');
    final hasDot = num.contains('.');
    if (hasComma && hasDot) {
      if (num.lastIndexOf(',') > num.lastIndexOf('.')) {
        num = num.replaceAll('.', '').replaceAll(',', '.');
      } else {
        num = num.replaceAll(',', '');
      }
    } else if (hasComma) {
      num = num.replaceAll(',', '.');
    } else if (hasDot) {
      final dotCount = '.'.allMatches(num).length;
      final afterDot = num.substring(num.lastIndexOf('.') + 1);
      if (dotCount > 1 || afterDot.length == 3) {
        num = num.replaceAll('.', ''); // binlik ayıracı
      }
    }
    return double.tryParse(num);
  }

  /// `dd.MM.yyyy` / `dd/MM/yy` → ISO `yyyy-MM-dd`. Geçersiz gün/ay → null.
  static String? parseDate(String s) {
    final m = RegExp(r'\b(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{2,4})\b').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    if (d < 1 || d > 31 || mo < 1 || mo > 12) return null;
    return '${y.toString().padLeft(4, '0')}-'
        '${mo.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }

  /// `HH:mm` (00-23:00-59). Bulamazsa null.
  static String? parseTime(String s) {
    final m = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(s);
    if (m == null) return null;
    return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
  }

  /// Bir satırdaki ondalıklı tutar tokenlarını döndürür.
  static List<String> _amountTokens(String text) =>
      _decimalAmount.allMatches(text).map((m) => m.group(0)!).toList();

  /// Anahtar-kelime satırı için değeri + değerin OKUNDUĞU satırı bulur: önce
  /// satırın KENDİ metnindeki (en sağdaki) tutar → kaynak = kw satırı, yoksa
  /// AYNI SATIRDAKİ (centerY yakın) en-sağ tutar → kaynak = o tutar satırı.
  /// Overlay bbox okunan tutarın gerçek konumunu gösterebilsin diye satır döner.
  static ({double? value, OcrLine? line}) _valueLineFor(
      OcrLine kw, List<OcrLine> lines) {
    final own = _amountTokens(kw.text);
    if (own.isNotEmpty) {
      return (value: parseTurkishAmount(own.last), line: kw);
    }
    final tol = kw.height == 0 ? 12.0 : kw.height * 0.7;
    final row = lines.where((l) =>
        !identical(l, kw) && (l.centerY - kw.centerY).abs() <= tol);
    final candidates = <({double right, double value, OcrLine line})>[];
    for (final l in row) {
      for (final tok in _amountTokens(l.text)) {
        final v = parseTurkishAmount(tok);
        if (v != null) candidates.add((right: l.right, value: v, line: l));
      }
    }
    if (candidates.isEmpty) return (value: null, line: null);
    candidates.sort((a, b) => b.right.compareTo(a.right)); // en sağdaki
    return (value: candidates.first.value, line: candidates.first.line);
  }

  /// Yalnız değeri döndüren ince sarmalayıcı (geriye-uyum).
  static double? _valueFor(OcrLine kw, List<OcrLine> lines) =>
      _valueLineFor(kw, lines).value;

  /// Anahtar-kelime eşleşmesi için Türkçe büyük-İ/I katlaması: 'İ' (U+0130) ve
  /// 'I' → 'i'. Dart'ın `caseSensitive:false`'u i/İ çiftini katlamadığından
  /// büyük-harf fişlerde 'FİŞ NO' / 'VERGİ DAİRESİ' / 'MAL/HİZMET' gibi
  /// anahtarlar aksi halde hiç yakalanmaz. Yalnız EŞLEŞME katmanında kullanılır;
  /// değer/bbox çıkarımı ham metni kullanmaya devam eder.
  static String _kw(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'i');

  /// Ana ayrıştırma.
  static ReceiptScanResult parse(List<OcrLine> lines, {String? rawText}) {
    final clean =
        lines.where((l) => l.text.trim().isNotEmpty).toList();
    final raw = rawText ?? clean.map((l) => l.text).join('\n');
    if (clean.isEmpty) return ReceiptScanResult(rawText: raw);

    final conf = <String, double>{};
    final warnings = <String>[];
    // Alan → okunan OCR satırı (görüntü-üstü bbox overlay için).
    final boxes = <String, OcrLine>{};

    // --- Genel toplam ---
    double? total;
    OcrLine? grandLine = clean.firstWhereOrNull((l) => _grandTotalKw.hasMatch(_kw(l.text)));
    grandLine ??= clean.firstWhereOrNull((l) => _totalKw.hasMatch(_kw(l.text)) && !_subTotalKw.hasMatch(_kw(l.text)) && !_vatKw.hasMatch(_kw(l.text)));
    if (grandLine != null) {
      final vl = _valueLineFor(grandLine, clean);
      total = vl.value;
      if (total != null) {
        conf['total'] = 0.7;
        if (vl.line != null) boxes['total'] = vl.line!;
      }
    }

    // --- Ara toplam ---
    double? subTotal;
    final subLine = clean.firstWhereOrNull((l) => _subTotalKw.hasMatch(_kw(l.text)));
    if (subLine != null) {
      final vl = _valueLineFor(subLine, clean);
      subTotal = vl.value;
      if (subTotal != null) {
        conf['subTotal'] = 0.6;
        if (vl.line != null) boxes['subTotal'] = vl.line!;
      }
    }

    // --- KDV satırları ---
    final vatLines = <VatLine>[];
    for (final l in clean.where((l) => _vatKw.hasMatch(_kw(l.text)))) {
      final rm = _rateRe.firstMatch(l.text);
      final rate = rm == null
          ? null
          : int.tryParse(rm.group(1) ?? rm.group(2) ?? '');
      final amount = _valueFor(l, clean);
      if (rate != null || amount != null) {
        vatLines.add(VatLine(rate: rate, amount: amount));
      }
    }

    // --- Tarih / saat ---
    String? date;
    String? time;
    for (final l in clean) {
      final d = parseDate(l.text);
      if (date == null && d != null) {
        date = d;
        boxes['date'] = l; // tarihin okunduğu satır
      }
      time ??= parseTime(l.text);
      if (date != null && time != null) break;
    }
    if (date != null) conf['date'] = 0.8;

    // --- Belge no ---
    String? documentNo;
    final docLine = clean.firstWhereOrNull((l) => _docNoKw.hasMatch(_kw(l.text)));
    if (docLine != null) {
      final m = RegExp(r'[:\s]([A-Z0-9\-]{3,})\s*$').firstMatch(docLine.text.toUpperCase());
      documentNo = m?.group(1) ??
          RegExp(r'(\d{3,})').firstMatch(docLine.text)?.group(1);
      if (documentNo != null) boxes['documentNo'] = docLine;
    }

    // --- Vergi no (VKN 10 / TCKN 11) ---
    String? taxNumber;
    final taxLine = clean.firstWhereOrNull((l) => _taxKw.hasMatch(_kw(l.text)));
    final taxSearch = taxLine?.text ?? raw;
    final tckn = RegExp(r'\b\d{11}\b').firstMatch(taxSearch)?.group(0);
    final vkn = RegExp(r'\b\d{10}\b').firstMatch(taxSearch)?.group(0);
    taxNumber = vkn ?? tckn;
    if (taxNumber != null) {
      conf['taxNumber'] = taxLine != null ? 0.7 : 0.4;
      if (taxLine != null) boxes['taxNumber'] = taxLine; // ham metinden ise satır yok
    }

    // --- Satıcı (üst 1-2 satır, harf-ağırlıklı) ---
    String? merchant;
    final sorted = [...clean]..sort((a, b) => a.top.compareTo(b.top));
    for (final l in sorted.take(3)) {
      final t = l.text.trim();
      final letters = t.replaceAll(RegExp(r'[^A-Za-zÇĞİÖŞÜçğıöşü]'), '').length;
      if (t.length >= 3 && letters / t.length > 0.5 && !_taxKw.hasMatch(_kw(t))) {
        merchant = t;
        boxes['merchant'] = l;
        break;
      }
    }

    // --- Aritmetik çapraz-kontrol ---
    final totalVat =
        vatLines.map((v) => v.amount).whereType<double>().fold<double?>(
              null,
              (a, b) => (a ?? 0) + b,
            );
    if (total != null && subTotal != null && totalVat != null) {
      final diff = (subTotal + totalVat - total).abs();
      if (diff <= 0.05) {
        conf['total'] = 0.95;
        conf['subTotal'] = 0.9;
      } else {
        warnings.add(
            'Ara toplam + KDV (${(subTotal + totalVat).toStringAsFixed(2)}) genel toplamla (${total.toStringAsFixed(2)}) tutmuyor');
        conf['total'] = 0.5;
      }
    }
    // KDV = matrah × oran çapraz-kontrolü (matrah=ara toplam, tek oran varsa)
    if (subTotal != null && vatLines.length == 1 && vatLines.first.rate != null && vatLines.first.amount != null) {
      final expected = subTotal * vatLines.first.rate! / 100;
      if ((expected - vatLines.first.amount!).abs() > 0.10) {
        warnings.add(
            'KDV tutarı orana göre beklenenle (${expected.toStringAsFixed(2)}) tutmuyor');
      }
    }

    return ReceiptScanResult(
      total: total,
      subTotal: subTotal,
      vatLines: vatLines,
      date: date,
      time: time,
      documentNo: documentNo,
      taxNumber: taxNumber,
      merchant: merchant,
      rawText: raw,
      fieldConfidence: conf,
      warnings: warnings,
      fieldBoxes: boxes,
    );
  }
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

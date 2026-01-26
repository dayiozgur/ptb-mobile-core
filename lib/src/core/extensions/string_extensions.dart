/// String için uzantı metodları
extension StringExtensions on String {
  // ============================================
  // VALIDATION
  // ============================================

  /// Geçerli email mi?
  bool get isValidEmail {
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(this);
  }

  /// Geçerli URL mi?
  bool get isValidUrl {
    final regex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );
    return regex.hasMatch(this);
  }

  /// Geçerli telefon numarası mı?
  bool get isValidPhone {
    final digits = replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10 && digits.length <= 15;
  }

  /// Sadece rakam içeriyor mu?
  bool get isNumeric {
    return RegExp(r'^[0-9]+$').hasMatch(this);
  }

  /// Sadece harf içeriyor mu?
  bool get isAlphabetic {
    return RegExp(r'^[a-zA-ZğüşıöçĞÜŞİÖÇ]+$').hasMatch(this);
  }

  /// Alfanümerik mi?
  bool get isAlphanumeric {
    return RegExp(r'^[a-zA-Z0-9ğüşıöçĞÜŞİÖÇ]+$').hasMatch(this);
  }

  // ============================================
  // CASE CONVERSION
  // ============================================

  /// İlk harf büyük (capitalize)
  String get capitalize {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1).toLowerCase();
  }

  /// Her kelimenin ilk harfi büyük (title case)
  String get toTitleCase {
    if (isEmpty) return this;
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// camelCase'e dönüştür
  String get toCamelCase {
    if (isEmpty) return this;
    final words = split(RegExp(r'[_\s-]+'));
    if (words.isEmpty) return this;

    final first = words.first.toLowerCase();
    final rest = words.skip(1).map((w) => w.capitalize);
    return first + rest.join();
  }

  /// snake_case'e dönüştür
  String get toSnakeCase {
    if (isEmpty) return this;
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceAll(RegExp(r'^_'), '');
  }

  /// kebab-case'e dönüştür
  String get toKebabCase {
    return toSnakeCase.replaceAll('_', '-');
  }

  // ============================================
  // TRIMMING & CLEANING
  // ============================================

  /// Null veya boş mu?
  bool get isNullOrEmpty => isEmpty;

  /// Null veya boşluk mu?
  bool get isNullOrBlank => trim().isEmpty;

  /// Boşlukları temizle (birden fazla boşluğu teke indir)
  String get cleanSpaces {
    return replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Tüm boşlukları kaldır
  String get removeAllSpaces {
    return replaceAll(RegExp(r'\s'), '');
  }

  /// HTML tag'lerini kaldır
  String get removeHtmlTags {
    return replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Özel karakterleri kaldır
  String get removeSpecialCharacters {
    return replaceAll(RegExp(r'[^a-zA-Z0-9ğüşıöçĞÜŞİÖÇ\s]'), '');
  }

  // ============================================
  // EXTRACTION
  // ============================================

  /// Sadece rakamları al
  String get digitsOnly {
    return replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Sadece harfleri al
  String get lettersOnly {
    return replaceAll(RegExp(r'[^a-zA-ZğüşıöçĞÜŞİÖÇ]'), '');
  }

  /// İlk n karakteri al
  String take(int n) {
    if (length <= n) return this;
    return substring(0, n);
  }

  /// Son n karakteri al
  String takeLast(int n) {
    if (length <= n) return this;
    return substring(length - n);
  }

  // ============================================
  // TRUNCATION
  // ============================================

  /// Metni kısalt
  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - suffix.length)}$suffix';
  }

  /// Kelime bazlı kısaltma
  String truncateWords(int wordCount, {String suffix = '...'}) {
    final words = split(' ');
    if (words.length <= wordCount) return this;
    return '${words.take(wordCount).join(' ')}$suffix';
  }

  // ============================================
  // FORMATTING
  // ============================================

  /// Telefon numarası formatla
  String get formatPhone {
    final digits = digitsOnly;
    if (digits.length == 10) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 8)} ${digits.substring(8)}';
    }
    return this;
  }

  /// Kredi kartı formatla
  String get formatCreditCard {
    final digits = digitsOnly;
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Kredi kartı maskele
  String get maskCreditCard {
    final digits = digitsOnly;
    if (digits.length < 4) return this;
    return '**** **** **** ${digits.takeLast(4)}';
  }

  /// Email maskele
  String get maskEmail {
    if (!isValidEmail) return this;
    final parts = split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '**@$domain';
    }

    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }

  // ============================================
  // CONVERSION
  // ============================================

  /// Int'e dönüştür
  int? toIntOrNull() => int.tryParse(this);

  /// Double'a dönüştür
  double? toDoubleOrNull() => double.tryParse(this);

  /// Bool'a dönüştür
  bool? toBoolOrNull() {
    final lower = toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
    return null;
  }

  /// DateTime'a dönüştür
  DateTime? toDateTimeOrNull() => DateTime.tryParse(this);

  // ============================================
  // MISC
  // ============================================

  /// Tersine çevir
  String get reversed {
    return split('').reversed.join();
  }

  /// Kelime sayısı
  int get wordCount {
    if (trim().isEmpty) return 0;
    return trim().split(RegExp(r'\s+')).length;
  }

  /// Belirli bir string içeriyor mu? (case insensitive)
  bool containsIgnoreCase(String other) {
    return toLowerCase().contains(other.toLowerCase());
  }
}

/// Nullable String için uzantılar
extension NullableStringExtensions on String? {
  /// Null, boş veya sadece boşluk mu?
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;

  /// Null veya boş mu?
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  /// Null ise default değer döndür
  String orDefault(String defaultValue) => this ?? defaultValue;

  /// Null veya boş ise default değer döndür
  String orEmpty() => this ?? '';
}

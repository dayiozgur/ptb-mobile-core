import 'package:intl/intl.dart';

/// Veri formatlama yardımcıları
///
/// Para birimi, sayı, tarih ve diğer veri tiplerini
/// kullanıcı dostu formatlara dönüştürür.
class Formatters {
  Formatters._();

  // ============================================
  // CURRENCY
  // ============================================

  /// Para birimi formatı
  ///
  /// Örnek: 1234.56 → "$1,234.56"
  static String currency(
    double amount, {
    String symbol = '₺',
    int decimals = 2,
    String locale = 'tr_TR',
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: decimals,
    );
    return formatter.format(amount);
  }

  /// Kompakt para birimi formatı
  ///
  /// Örnek: 1234567 → "₺1.23M"
  static String currencyCompact(
    double amount, {
    String symbol = '₺',
    String locale = 'tr_TR',
  }) {
    final formatter = NumberFormat.compactCurrency(
      locale: locale,
      symbol: symbol,
    );
    return formatter.format(amount);
  }

  // ============================================
  // NUMBER
  // ============================================

  /// Sayı formatı
  ///
  /// Örnek: 1000000 → "1,000,000"
  static String number(
    num value, {
    int decimals = 0,
    String locale = 'tr_TR',
  }) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    );
    return formatter.format(value);
  }

  /// Kompakt sayı formatı
  ///
  /// Örnek: 1234567 → "1.23M"
  static String numberCompact(num value, {String locale = 'tr_TR'}) {
    final formatter = NumberFormat.compact(locale: locale);
    return formatter.format(value);
  }

  /// Ondalık sayı formatı
  ///
  /// Örnek: 1234.5678 → "1,234.57"
  static String decimal(
    double value, {
    int decimals = 2,
    String locale = 'tr_TR',
  }) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    );
    return formatter.format(value);
  }

  // ============================================
  // PERCENTAGE
  // ============================================

  /// Yüzde formatı
  ///
  /// Örnek: 0.856 → "%85.6"
  static String percentage(
    double value, {
    int decimals = 1,
    String locale = 'tr_TR',
  }) {
    final formatter = NumberFormat.percentPattern(locale);
    return formatter.format(value);
  }

  /// Özel yüzde formatı
  ///
  /// Örnek: 85.6 → "%85.6" (değer zaten yüzde olarak verilmişse)
  static String percentageFromValue(
    double value, {
    int decimals = 1,
  }) {
    return '%${value.toStringAsFixed(decimals)}';
  }

  // ============================================
  // DATE & TIME
  // ============================================

  /// Tarih formatı
  ///
  /// Örnek: DateTime.now() → "26/01/2024"
  static String date(
    DateTime date, {
    String format = 'dd/MM/yyyy',
    String locale = 'tr_TR',
  }) {
    final formatter = DateFormat(format, locale);
    return formatter.format(date);
  }

  /// Uzun tarih formatı
  ///
  /// Örnek: DateTime.now() → "26 Ocak 2024"
  static String dateLong(DateTime date, {String locale = 'tr_TR'}) {
    final formatter = DateFormat.yMMMMd(locale);
    return formatter.format(date);
  }

  /// Kısa tarih formatı
  ///
  /// Örnek: DateTime.now() → "26 Oca"
  static String dateShort(DateTime date, {String locale = 'tr_TR'}) {
    final formatter = DateFormat.MMMd(locale);
    return formatter.format(date);
  }

  /// Saat formatı
  ///
  /// Örnek: DateTime.now() → "14:30"
  static String time(DateTime date, {String locale = 'tr_TR'}) {
    final formatter = DateFormat.Hm(locale);
    return formatter.format(date);
  }

  /// Tarih ve saat formatı
  ///
  /// Örnek: DateTime.now() → "26/01/2024 14:30"
  static String dateTime(
    DateTime date, {
    String format = 'dd/MM/yyyy HH:mm',
    String locale = 'tr_TR',
  }) {
    final formatter = DateFormat(format, locale);
    return formatter.format(date);
  }

  /// Göreli zaman formatı
  ///
  /// Örnek: 5 dakika önce, 2 saat önce, Dün, 3 gün önce
  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes dakika önce';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks hafta önce';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ay önce';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years yıl önce';
    }
  }

  /// Göreli gelecek zaman formatı
  ///
  /// Örnek: 5 dakika içinde, 2 saat içinde, Yarın
  static String relativeTimeFuture(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inSeconds < 60) {
      return 'Birazdan';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes dakika içinde';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours saat içinde';
    } else if (difference.inDays == 1) {
      return 'Yarın';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün içinde';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks hafta içinde';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ay içinde';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years yıl içinde';
    }
  }

  // ============================================
  // FILE SIZE
  // ============================================

  /// Dosya boyutu formatı
  ///
  /// Örnek: 1536000 → "1.5 MB"
  static String fileSize(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  // ============================================
  // DURATION
  // ============================================

  /// Süre formatı (saat:dakika:saniye)
  ///
  /// Örnek: Duration(hours: 2, minutes: 30) → "2:30:00"
  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Okunabilir süre formatı
  ///
  /// Örnek: Duration(hours: 2, minutes: 30) → "2 saat 30 dakika"
  static String durationReadable(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final parts = <String>[];

    if (hours > 0) {
      parts.add('$hours saat');
    }
    if (minutes > 0) {
      parts.add('$minutes dakika');
    }
    if (seconds > 0 && hours == 0) {
      parts.add('$seconds saniye');
    }

    return parts.isEmpty ? '0 saniye' : parts.join(' ');
  }

  // ============================================
  // PHONE
  // ============================================

  /// Telefon numarası formatı
  ///
  /// Örnek: "5551234567" → "555 123 45 67"
  static String phone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length == 10) {
      return '${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 8)} ${digits.substring(8)}';
    } else if (digits.length == 11 && digits.startsWith('0')) {
      return '${digits.substring(1, 4)} ${digits.substring(4, 7)} ${digits.substring(7, 9)} ${digits.substring(9)}';
    }

    return value;
  }

  // ============================================
  // CREDIT CARD
  // ============================================

  /// Kredi kartı numarası formatı
  ///
  /// Örnek: "1234567890123456" → "1234 5678 9012 3456"
  static String creditCard(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  /// Kredi kartı numarası maskeleme
  ///
  /// Örnek: "1234567890123456" → "**** **** **** 3456"
  static String creditCardMasked(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length < 4) return value;

    final last4 = digits.substring(digits.length - 4);
    return '**** **** **** $last4';
  }

  // ============================================
  // TEXT
  // ============================================

  /// Metin kısaltma
  ///
  /// Örnek: "Bu çok uzun bir metin" → "Bu çok uzun..."
  static String truncate(String value, int maxLength, {String suffix = '...'}) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - suffix.length)}$suffix';
  }

  /// Başlık formatı (her kelimenin ilk harfi büyük)
  ///
  /// Örnek: "hello world" → "Hello World"
  static String titleCase(String value) {
    if (value.isEmpty) return value;

    return value.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Cümle formatı (ilk harf büyük)
  ///
  /// Örnek: "hello world" → "Hello world"
  static String sentenceCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

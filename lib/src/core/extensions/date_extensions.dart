import 'package:intl/intl.dart';

/// DateTime için uzantı metodları
extension DateTimeExtensions on DateTime {
  // ============================================
  // FORMATTING
  // ============================================

  /// Standart tarih formatı (dd/MM/yyyy)
  String get formatted => DateFormat('dd/MM/yyyy').format(this);

  /// Uzun tarih formatı (26 Ocak 2024)
  String get formattedLong => DateFormat.yMMMMd('tr_TR').format(this);

  /// Kısa tarih formatı (26 Oca)
  String get formattedShort => DateFormat.MMMd('tr_TR').format(this);

  /// Saat formatı (14:30)
  String get formattedTime => DateFormat.Hm('tr_TR').format(this);

  /// Tarih ve saat formatı (26/01/2024 14:30)
  String get formattedDateTime => DateFormat('dd/MM/yyyy HH:mm').format(this);

  /// ISO 8601 formatı
  String get formattedIso => toIso8601String();

  /// Özel format
  String format(String pattern, {String locale = 'tr_TR'}) {
    return DateFormat(pattern, locale).format(this);
  }

  // ============================================
  // RELATIVE TIME
  // ============================================

  /// Göreli zaman (5 dakika önce, Dün, vb.)
  String get relative {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.isNegative) {
      return _relativeFuture(diff.abs());
    }
    return _relativePast(diff);
  }

  String _relativePast(Duration diff) {
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays == 1) return 'Dün';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta önce';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} ay önce';
    return '${(diff.inDays / 365).floor()} yıl önce';
  }

  String _relativeFuture(Duration diff) {
    if (diff.inSeconds < 60) return 'Birazdan';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika içinde';
    if (diff.inHours < 24) return '${diff.inHours} saat içinde';
    if (diff.inDays == 1) return 'Yarın';
    if (diff.inDays < 7) return '${diff.inDays} gün içinde';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} hafta içinde';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} ay içinde';
    return '${(diff.inDays / 365).floor()} yıl içinde';
  }

  // ============================================
  // COMPARISON
  // ============================================

  /// Bugün mü?
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Dün mü?
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Yarın mı?
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Bu hafta mı?
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.startOfWeek;
    final endOfWeek = now.endOfWeek;
    return isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
        isBefore(endOfWeek.add(const Duration(seconds: 1)));
  }

  /// Bu ay mı?
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// Bu yıl mı?
  bool get isThisYear {
    return year == DateTime.now().year;
  }

  /// Geçmişte mi?
  bool get isPast => isBefore(DateTime.now());

  /// Gelecekte mi?
  bool get isFuture => isAfter(DateTime.now());

  /// Aynı gün mü?
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  /// Aynı ay mı?
  bool isSameMonth(DateTime other) {
    return year == other.year && month == other.month;
  }

  /// Aynı yıl mı?
  bool isSameYear(DateTime other) {
    return year == other.year;
  }

  // ============================================
  // MANIPULATION
  // ============================================

  /// Günün başlangıcı (00:00:00)
  DateTime get startOfDay => DateTime(year, month, day);

  /// Günün sonu (23:59:59)
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  /// Haftanın başlangıcı (Pazartesi)
  DateTime get startOfWeek {
    final daysFromMonday = weekday - 1;
    return DateTime(year, month, day - daysFromMonday);
  }

  /// Haftanın sonu (Pazar)
  DateTime get endOfWeek {
    final daysToSunday = 7 - weekday;
    return DateTime(year, month, day + daysToSunday, 23, 59, 59, 999);
  }

  /// Ayın başlangıcı
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// Ayın sonu
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59, 999);

  /// Yılın başlangıcı
  DateTime get startOfYear => DateTime(year, 1, 1);

  /// Yılın sonu
  DateTime get endOfYear => DateTime(year, 12, 31, 23, 59, 59, 999);

  /// Gün ekle
  DateTime addDays(int days) => add(Duration(days: days));

  /// Gün çıkar
  DateTime subtractDays(int days) => subtract(Duration(days: days));

  /// Hafta ekle
  DateTime addWeeks(int weeks) => add(Duration(days: weeks * 7));

  /// Ay ekle
  DateTime addMonths(int months) {
    var newMonth = month + months;
    var newYear = year;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear--;
    }

    final lastDayOfMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = day > lastDayOfMonth ? lastDayOfMonth : day;

    return DateTime(newYear, newMonth, newDay, hour, minute, second);
  }

  /// Yıl ekle
  DateTime addYears(int years) => DateTime(year + years, month, day);

  /// Sadece tarihi kopyala (saat sıfırla)
  DateTime get dateOnly => DateTime(year, month, day);

  /// Saat ve dakikayı değiştir
  DateTime withTime(int hour, int minute, [int second = 0]) {
    return DateTime(year, month, day, hour, minute, second);
  }

  // ============================================
  // INFO
  // ============================================

  /// Aydaki gün sayısı
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  /// Yılın kaçıncı günü
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays + 1;
  }

  /// Yılın kaçıncı haftası
  int get weekOfYear {
    final firstDayOfYear = DateTime(year, 1, 1);
    final days = difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  /// Çeyrek (Q1, Q2, Q3, Q4)
  int get quarter => ((month - 1) / 3).floor() + 1;

  /// Artık yıl mı?
  bool get isLeapYear {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Hafta içi mi?
  bool get isWeekday => weekday < 6;

  /// Hafta sonu mu?
  bool get isWeekend => weekday >= 6;

  /// Gün adı
  String get dayName {
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    return days[weekday - 1];
  }

  /// Kısa gün adı
  String get dayNameShort {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday - 1];
  }

  /// Ay adı
  String get monthName {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return months[month - 1];
  }

  /// Kısa ay adı
  String get monthNameShort {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara'
    ];
    return months[month - 1];
  }

  // ============================================
  // DIFFERENCE
  // ============================================

  /// İki tarih arasındaki gün farkı
  int daysBetween(DateTime other) {
    return dateOnly.difference(other.dateOnly).inDays.abs();
  }

  /// İki tarih arasındaki ay farkı
  int monthsBetween(DateTime other) {
    return ((year - other.year) * 12 + (month - other.month)).abs();
  }

  /// İki tarih arasındaki yıl farkı
  int yearsBetween(DateTime other) {
    return (year - other.year).abs();
  }

  /// Yaş hesapla
  int get age {
    final now = DateTime.now();
    int age = now.year - year;
    if (now.month < month || (now.month == month && now.day < day)) {
      age--;
    }
    return age;
  }
}

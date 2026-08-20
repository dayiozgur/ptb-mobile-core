import 'dart:ui' show Color;

import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

/// Dinamik widget'lar için ortak yardımcılar: config okuma, tip-güvenli
/// sayı/tarih biçimlendirme (tr_TR) ve varsayılan renk paleti.
class DynWidgetHelpers {
  DynWidgetHelpers._();

  static const String locale = 'tr_TR';

  /// visualConfig'ten string değer okur (null-güvenli).
  static String? readString(Map<String, dynamic> config, String key) {
    final v = config[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// visualConfig'ten int okur.
  static int? readInt(Map<String, dynamic> config, String key) {
    final v = config[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// visualConfig'ten num okur.
  static num? readNum(Map<String, dynamic> config, String key) {
    return toNum(config[key]);
  }

  /// visualConfig'ten string listesi okur (`valueFields`, `columns` vb.).
  static List<String> readStringList(Map<String, dynamic> config, String key) {
    final v = config[key];
    if (v is List) {
      return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const <String>[];
  }

  /// Herhangi bir değeri num'a çevirir (parse edilemezse null).
  static num? toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return value.isNaN ? null : value;
    }
    if (value is bool) return value ? 1 : 0;
    if (value is String) return num.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  /// Bir satır haritasındaki ilk sayısal alan-anahtarını döner.
  static String? firstNumericKey(Map<String, dynamic> row) {
    for (final entry in row.entries) {
      if (toNum(entry.value) != null && entry.value is! bool) {
        return entry.key;
      }
    }
    return null;
  }

  /// Bir satır haritasındaki ilk metin (kategori) alan-anahtarını döner.
  static String? firstStringKey(Map<String, dynamic> row) {
    for (final entry in row.entries) {
      final v = entry.value;
      if (v is String && toNum(v) == null) return entry.key;
    }
    // Metin bulunamazsa ilk anahtarı döner.
    return row.keys.isNotEmpty ? row.keys.first : null;
  }

  /// Değerin ISO-8601 tarih olup olmadığını dener.
  static DateTime? tryDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.length >= 8) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Sayıyı tr_TR biçiminde, verilen ondalık basamakla biçimlendirir.
  static String formatNumber(
    num value, {
    int? decimals,
    String? prefix,
    String? suffix,
  }) {
    final NumberFormat formatter;
    if (decimals != null) {
      formatter = NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimals,
      );
    } else {
      // Tam sayı ise basamak yok, aksi halde makul 2 basamak.
      formatter = value == value.roundToDouble()
          ? NumberFormat.decimalPattern(locale)
          : NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: 2);
    }
    final body = formatter.format(value);
    return '${prefix ?? ''}$body${suffix ?? ''}';
  }

  /// Bir hücre değerini görüntü metnine çevirir (sayı/tarih/metin).
  static String formatCell(dynamic value) {
    if (value == null) return '—';
    final date = tryDate(value);
    if (date != null) {
      return DateFormat('dd.MM.yyyy', locale).format(date);
    }
    final n = toNum(value);
    if (n != null && value is! bool) {
      return formatNumber(n);
    }
    if (value is bool) return value ? 'Evet' : 'Hayır';
    return value.toString();
  }

  /// visualConfig `colors[]` listesini ya da varsayılan 10-renk paletini döner.
  static List<Color> resolveColors(Map<String, dynamic> config) {
    final raw = config['colors'];
    if (raw is List && raw.isNotEmpty) {
      final parsed = <Color>[];
      for (final c in raw) {
        final color = _parseColor(c);
        if (color != null) parsed.add(color);
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return defaultPalette;
  }

  /// AppColors.primary tabanlı sabit 10-renk paleti.
  static List<Color> get defaultPalette => <Color>[
        AppColors.primary,
        AppColors.success,
        AppColors.warning,
        AppColors.error,
        AppColors.info,
        AppColors.secondary,
        AppColors.accent,
        const Color(0xFFAF52DE),
        const Color(0xFFFF2D55),
        const Color(0xFF5AC8FA),
      ];

  /// "#RRGGBB" / "#AARRGGBB" / int → Color.
  static Color? _parseColor(dynamic value) {
    if (value is int) return Color(value);
    if (value is String) {
      var hex = value.trim().replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        final v = int.tryParse(hex, radix: 16);
        if (v != null) return Color(v);
      }
    }
    return null;
  }
}

import '../di/service_locator.dart';
import '../localization/localization_service.dart';

/// Relative times and readable durations in the UI language ("5 minutes ago",
/// "yesterday", "in 2 hours", "2 h 30 min"). Texts come from the keywords
/// (`time.*`) with the built-in tr / en / de fallbacks; English when no
/// localization service is registered (tests, early start-up).
class RelativeTime {
  RelativeTime._();

  static const Map<String, String> _english = {
    'time.just_now': 'Just now',
    'time.minutes_ago': '{count} minutes ago',
    'time.hours_ago': '{count} hours ago',
    'time.yesterday': 'Yesterday',
    'time.days_ago': '{count} days ago',
    'time.weeks_ago': '{count} weeks ago',
    'time.months_ago': '{count} months ago',
    'time.years_ago': '{count} years ago',
    'time.in_a_moment': 'In a moment',
    'time.in_minutes': 'In {count} minutes',
    'time.in_hours': 'In {count} hours',
    'time.tomorrow': 'Tomorrow',
    'time.in_days': 'In {count} days',
    'time.in_weeks': 'In {count} weeks',
    'time.in_months': 'In {count} months',
    'time.in_years': 'In {count} years',
    'time.duration_hours': '{count} h',
    'time.duration_minutes': '{count} min',
    'time.duration_seconds': '{count} s',
  };

  static String _t(String key, [int? count]) {
    String text;
    if (sl.isRegistered<LocalizationService>()) {
      text = sl<LocalizationService>().translate(key);
      if (text == key) text = _english[key] ?? key;
    } else {
      text = _english[key] ?? key;
    }
    if (count == null) return text;
    return text
        .replaceAll('{{count}}', '$count')
        .replaceAll('{count}', '$count');
  }

  /// "Just now", "5 minutes ago", "Yesterday", "3 weeks ago" …
  static String past(DateTime date, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(date);
    if (d.isNegative) return future(date, now: now);
    if (d.inSeconds < 60) return _t('time.just_now');
    if (d.inMinutes < 60) return _t('time.minutes_ago', d.inMinutes);
    if (d.inHours < 24) return _t('time.hours_ago', d.inHours);
    if (d.inDays == 1) return _t('time.yesterday');
    if (d.inDays < 7) return _t('time.days_ago', d.inDays);
    if (d.inDays < 30) return _t('time.weeks_ago', d.inDays ~/ 7);
    if (d.inDays < 365) return _t('time.months_ago', d.inDays ~/ 30);
    return _t('time.years_ago', d.inDays ~/ 365);
  }

  /// "In a moment", "In 5 minutes", "Tomorrow", "In 3 weeks" …
  static String future(DateTime date, {DateTime? now}) {
    final d = date.difference(now ?? DateTime.now());
    if (d.isNegative) return past(date, now: now);
    if (d.inSeconds < 60) return _t('time.in_a_moment');
    if (d.inMinutes < 60) return _t('time.in_minutes', d.inMinutes);
    if (d.inHours < 24) return _t('time.in_hours', d.inHours);
    if (d.inDays == 1) return _t('time.tomorrow');
    if (d.inDays < 7) return _t('time.in_days', d.inDays);
    if (d.inDays < 30) return _t('time.in_weeks', d.inDays ~/ 7);
    if (d.inDays < 365) return _t('time.in_months', d.inDays ~/ 30);
    return _t('time.in_years', d.inDays ~/ 365);
  }

  /// Past or future, whichever [date] is.
  static String of(DateTime date, {DateTime? now}) =>
      date.isAfter(now ?? DateTime.now())
          ? future(date, now: now)
          : past(date, now: now);

  /// "2 h 30 min", "45 s" — seconds only below one hour.
  static String duration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    final parts = <String>[
      if (h > 0) _t('time.duration_hours', h),
      if (m > 0) _t('time.duration_minutes', m),
      if (s > 0 && h == 0) _t('time.duration_seconds', s),
    ];
    return parts.isEmpty ? _t('time.duration_seconds', 0) : parts.join(' ');
  }
}

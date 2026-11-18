import 'package:intl/intl.dart';

abstract final class Fmt {
  static final _date = DateFormat('MMM d, yyyy');
  static final _dateShort = DateFormat('MMM d');
  static final _time = DateFormat('h:mm a');
  static final _dateTime = DateFormat('MMM d, yyyy · h:mm a');
  static final _weekday = DateFormat('EEE');

  static String date(DateTime d) => _date.format(d);
  static String dateShort(DateTime d) => _dateShort.format(d);
  static String time(DateTime d) => _time.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String weekday(DateTime d) => _weekday.format(d);

  static String relative(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = n.difference(d);
    if (diff.isNegative) {
      final ahead = d.difference(n);
      if (ahead.inDays >= 1) return 'in ${ahead.inDays}d';
      if (ahead.inHours >= 1) return 'in ${ahead.inHours}h';
      return 'soon';
    }
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  static String greeting({DateTime? now}) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static String initials(String first, String last) {
    final a = first.trim().isNotEmpty ? first.trim()[0] : '';
    final b = last.trim().isNotEmpty ? last.trim()[0] : '';
    final r = '$a$b'.toUpperCase();
    return r.isEmpty ? '?' : r;
  }

  static String bytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

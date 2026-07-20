import 'package:intl/intl.dart';

/// Human-friendly relative time for sightings feed rows.
///
/// Examples: "Just now", "12 minutes ago", "2 hours ago", "Yesterday",
/// "3 days ago", then a short date like "Jul 12" past ~7 days.
String formatRelativeTime(DateTime when, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(when);

  if (diff.isNegative || diff.inSeconds < 60) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? '1 minute ago' : '$m minutes ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }

  final startOfToday = DateTime(current.year, current.month, current.day);
  final startOfWhen = DateTime(when.year, when.month, when.day);
  final dayDiff = startOfToday.difference(startOfWhen).inDays;

  if (dayDiff == 1) return 'Yesterday';
  if (dayDiff > 1 && dayDiff < 7) return '$dayDiff days ago';

  if (when.year == current.year) {
    return DateFormat.MMMd().format(when);
  }
  return DateFormat.yMMMd().format(when);
}

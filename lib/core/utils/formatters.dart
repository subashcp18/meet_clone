abstract final class Formatters {
  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String formatTime(DateTime dateTime) {
    final hour24 = dateTime.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  static String formatFullDate(DateTime dateTime) {
    final weekday = _weekdays[dateTime.weekday - 1];
    final month = _months[dateTime.month - 1];
    return '$weekday, $month ${dateTime.day}, ${dateTime.year}';
  }

  static String formatDateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diffDays = target.difference(today).inDays;

    if (diffDays == 0) {
      return 'Today';
    }
    if (diffDays == 1) {
      return 'Tomorrow';
    }
    final month = _months[dateTime.month - 1];
    return '$month ${dateTime.day}';
  }

  static String formatMeetingWindow(DateTime start, int durationMinutes) {
    final end = start.add(Duration(minutes: durationMinutes));
    final dateLabel = formatDateLabel(start);
    return '$dateLabel, ${formatTime(start)} - ${formatTime(end)}';
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String initialsFromName(String nameOrEmail) {
    final cleaned = nameOrEmail.trim();
    if (cleaned.isEmpty) {
      return '?';
    }
    final localPart = cleaned.contains('@')
        ? cleaned.split('@').first
        : cleaned;
    final parts = localPart
        .split(RegExp(r'[\s._-]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return cleaned[0].toUpperCase();
    }
    if (parts.length == 1) {
      final first = parts.first;
      return first.length >= 2
          ? first.substring(0, 2).toUpperCase()
          : first[0].toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

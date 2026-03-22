String formatDate(DateTime? date) {
  if (date == null) {
    return '—';
  }

  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String truncateMiddle(String text, {int maxLength = 56}) {
  if (text.length <= maxLength) {
    return text;
  }

  final left = (maxLength / 2).floor() - 2;
  final right = (maxLength / 2).floor() - 1;
  return '${text.substring(0, left)}...${text.substring(text.length - right)}';
}

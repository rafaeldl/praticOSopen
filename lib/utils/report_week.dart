/// Week of the financial report: Sunday to Saturday, [offset] weeks away
/// from the week of [now]. [end] is exclusive (the next Sunday at midnight).
///
/// One rule for the query, the label on screen and the PDF: before, each
/// counted the week its own way and showed a week other than the one
/// searched.
({DateTime start, DateTime end}) reportWeek(DateTime now, int offset) {
  final daysSinceSunday = now.weekday % 7;
  final start = DateTime(
    now.year,
    now.month,
    now.day - daysSinceSunday + 7 * offset,
  );
  final end = DateTime(start.year, start.month, start.day + 7);
  return (start: start, end: end);
}

/// Last day shown for [reportWeek] (Saturday).
DateTime reportWeekLastDay(DateTime now, int offset) {
  final week = reportWeek(now, offset);
  return DateTime(week.end.year, week.end.month, week.end.day - 1);
}

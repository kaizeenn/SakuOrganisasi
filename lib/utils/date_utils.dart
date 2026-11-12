// Date helpers for fields that represent a calendar date, not an instant.
//
// The app is used in Indonesia (UTC+7), but the backend stores DateTime
// values. Sending a local midnight through `toUtc()` changes the calendar
// date to the previous day (for example, 12 Nov 00:00 WIB becomes 11 Nov
// 17:00 UTC). These helpers encode the selected calendar date at UTC so the
// date remains stable across the phone, API, database, and reports.

String toApiCalendarDate(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day).toIso8601String();
}

String toApiCalendarBoundary(DateTime date, {required bool endOfDay}) {
  final utcDate = endOfDay
      ? DateTime.utc(date.year, date.month, date.day, 23, 59, 59, 999)
      : DateTime.utc(date.year, date.month, date.day);
  return utcDate.toIso8601String();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:apk_bendahara/utils/date_utils.dart';

void main() {
  test('calendar date remains the selected day when encoded for the API', () {
    final selected = DateTime(2026, 11, 12);

    expect(toApiCalendarDate(selected), '2026-11-12T00:00:00.000Z');
  });

  test('date range boundaries include the complete selected end date', () {
    final selected = DateTime(2026, 11, 12);

    expect(
      toApiCalendarBoundary(selected, endOfDay: false),
      '2026-11-12T00:00:00.000Z',
    );
    expect(
      toApiCalendarBoundary(selected, endOfDay: true),
      '2026-11-12T23:59:59.999Z',
    );
  });

  test('a local midnight no longer becomes the previous UTC calendar date', () {
    final selected = DateTime(2026, 11, 12, 0, 0);
    final oldPayload = selected.toUtc().toIso8601String();
    final fixedPayload = toApiCalendarDate(selected);

    expect(oldPayload, isNot(fixedPayload));
    expect(fixedPayload.substring(0, 10), '2026-11-12');
  });
}

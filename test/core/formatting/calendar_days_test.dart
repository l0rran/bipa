import 'package:bipa/core/formatting/calendar_days.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 28, 8);

  test('conta dias do calendário, não períodos de 24 horas', () {
    expect(calendarDaysSince(DateTime(2026, 10, 28, 7), now), 0);
    expect(calendarDaysSince(DateTime(2026, 10, 27, 23), now), 1);
    expect(calendarDaysSince(DateTime(2026, 9, 18, 12), now), 40);
  });

  test('uma data no futuro conta como hoje', () {
    expect(calendarDaysSince(DateTime(2026, 10, 29, 9), now), 0);
  });
}

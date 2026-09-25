import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/utils/format.dart';

void main() {
  countdownTests();
  test('formatKes', () {
    expect(formatKes(null), 'Fee not set');
    expect(formatKes(0), 'Free');
    expect(formatKes(1500), 'KES 1,500');
    expect(formatKes(250.5), 'KES 251');
  });

  test('formatRelativeSlot uses Today / Tomorrow / date', () {
    final now = DateTime(2026, 10, 14, 8);
    expect(
      formatRelativeSlot(DateTime(2026, 10, 14, 14, 30), now: now),
      'Today, 14:30',
    );
    expect(
      formatRelativeSlot(DateTime(2026, 10, 15, 9), now: now),
      'Tomorrow, 09:00',
    );
    expect(
      formatRelativeSlot(DateTime(2026, 10, 20, 9), now: now),
      'Tue 20 Oct, 09:00',
    );
  });

  test('initialsOf strips titles', () {
    expect(initialsOf('Dr. Jane Wanjiru'), 'JW');
    expect(initialsOf('dr Otieno'), 'O');
    expect(initialsOf('  '), '?');
    expect(initialsOf('Amina Hassan Ali'), 'AH');
  });
}

void countdownTests() {
  final now = DateTime(2026, 10, 14, 8);
  test('formatCountdown', () {
    expect(
      formatCountdown(now.subtract(const Duration(minutes: 1)), now: now),
      'now',
    );
    expect(
      formatCountdown(now.add(const Duration(seconds: 20)), now: now),
      'any moment',
    );
    expect(
      formatCountdown(now.add(const Duration(minutes: 25)), now: now),
      'in 25 min',
    );
    expect(
      formatCountdown(now.add(const Duration(hours: 3, minutes: 20)), now: now),
      'in 3 h 20 min',
    );
    expect(
      formatCountdown(now.add(const Duration(hours: 5)), now: now),
      'in 5 h',
    );
    expect(
      formatCountdown(now.add(const Duration(days: 1, hours: 2)), now: now),
      'in 1 day',
    );
    expect(
      formatCountdown(now.add(const Duration(days: 4)), now: now),
      'in 4 days',
    );
  });
}

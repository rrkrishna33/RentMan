import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/models/booking.dart';
import 'package:rental_app/services/notification_service.dart';

Booking _bookingIn(int days) {
  final now = DateTime.now();
  return Booking(
    id: 1,
    customerId: 1,
    rentalDate: DateTime(now.year, now.month, now.day).add(Duration(days: days)),
    bookingDate: now,
    totalAmount: 1000,
    depositAmount: 500,
    lastUpdated: now,
    items: const [],
  );
}

void main() {
  group('Booking.shouldRemind', () {
    test('is false when the rental date is in the past', () {
      expect(_bookingIn(-1).shouldRemind, isFalse);
    });

    test('is false for a rental date today (0 days out)', () {
      expect(_bookingIn(0).shouldRemind, isFalse);
    });

    test('is true just inside the window (1 day out)', () {
      expect(_bookingIn(1).shouldRemind, isTrue);
    });

    test('is true at the far edge of the window (10 days out)', () {
      expect(_bookingIn(10).shouldRemind, isTrue);
    });

    test('is false just outside the window (11 days out)', () {
      expect(_bookingIn(11).shouldRemind, isFalse);
    });
  });

  group('NotificationService.debugReminderTimes', () {
    test('returns no times for a booking without an id', () {
      final booking = Booking(
        customerId: 1,
        rentalDate: DateTime.now().add(const Duration(days: 3)),
        bookingDate: DateTime.now(),
        depositAmount: 500,
        lastUpdated: DateTime.now(),
        items: const [],
      );

      final times = NotificationService.debugReminderTimes(
        booking: booking,
        daysBefore: 5,
        hour: 9,
        minute: 0,
      );

      expect(times, isEmpty);
    });

    test('returns no times once the rental date has passed', () {
      final times = NotificationService.debugReminderTimes(
        booking: _bookingIn(-2),
        daysBefore: 5,
        hour: 9,
        minute: 0,
      );

      expect(times, isEmpty);
    });

    test('schedules one reminder per day from daysBefore up to the rental date', () {
      final booking = _bookingIn(7);
      final times = NotificationService.debugReminderTimes(
        booking: booking,
        daysBefore: 5,
        hour: 9,
        minute: 0,
      );

      // daysUntil=7 > daysBefore=5, so it should start 5 days out and
      // include the rental day itself: 6 reminders total (day 2..7).
      expect(times.length, 6);

      final last = times.last;
      expect(last.year, booking.rentalDate.year);
      expect(last.month, booking.rentalDate.month);
      expect(last.day, booking.rentalDate.day);

      for (final t in times) {
        expect(t.hour, 9);
        expect(t.minute, 0);
      }

      for (var i = 1; i < times.length; i++) {
        expect(times[i].difference(times[i - 1]).inDays, 1);
      }
    });

    test('clamps the start day to today when daysBefore exceeds daysUntil', () {
      final booking = _bookingIn(3);
      final times = NotificationService.debugReminderTimes(
        booking: booking,
        daysBefore: 10,
        hour: 9,
        minute: 0,
      );

      // daysUntil=3 is not > daysBefore=10, so it starts today (day 0) and
      // runs through the rental day: 4 candidate reminders, but today's is
      // only included if 9am hasn't passed yet, so allow 3 or 4.
      expect(times.length, anyOf(3, 4));
      expect(times.last.day, booking.rentalDate.day);
    });

    test('every returned time is still in the future', () {
      final times = NotificationService.debugReminderTimes(
        booking: _bookingIn(5),
        daysBefore: 5,
        hour: 9,
        minute: 0,
      );

      final now = DateTime.now();
      for (final t in times) {
        expect(t.isAfter(now), isTrue);
      }
    });
  });
}

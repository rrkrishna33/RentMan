import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app/models/booking.dart';

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
  group('Booking.daysUntilRental / shouldRemind', () {
    // Regression coverage: daysUntilRental used to compare a date-only
    // rentalDate against DateTime.now() (which includes the current
    // time-of-day), so the result silently shifted by a day depending on
    // when you checked. It must count calendar days instead.
    test('is false when the rental date is in the past', () {
      expect(_bookingIn(-1).shouldRemind, isFalse);
    });

    test('is false for a rental date today (0 days out)', () {
      expect(_bookingIn(0).shouldRemind, isFalse);
    });

    test('is true just inside the window (1 day out)', () {
      expect(_bookingIn(1).daysUntilRental, 1);
      expect(_bookingIn(1).shouldRemind, isTrue);
    });

    test('is true at the far edge of the window (10 days out)', () {
      expect(_bookingIn(10).daysUntilRental, 10);
      expect(_bookingIn(10).shouldRemind, isTrue);
    });

    test('is false just outside the window (11 days out)', () {
      expect(_bookingIn(11).daysUntilRental, 11);
      expect(_bookingIn(11).shouldRemind, isFalse);
    });
  });
}

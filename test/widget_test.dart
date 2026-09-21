// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:rental_app/main.dart';
import 'package:rental_app/models/booking.dart';

void main() {
  testWidgets('App launches without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const RentManApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  test('booking balance is deposit minus rent minus paid to customer', () {
    final booking = Booking(
      customerId: 1,
      eventDate: DateTime.now().add(const Duration(days: 3)),
      bookingDate: DateTime.now(),
      totalAmount: 5000,
      depositAmount: 20000,
      paidAmount: 3000,
      lastUpdated: DateTime.now(),
      items: const [],
    );

    expect(booking.balanceAmount, 12000.0);
  });
}

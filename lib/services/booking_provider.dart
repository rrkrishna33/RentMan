import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/booking.dart';
import '../models/delivery.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class BookingProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<Customer> _customers = [];
  List<Booking> _bookings = [];
  List<Delivery> _deliveries = [];
  
  List<Customer> get customers => _customers;
  List<Booking> get bookings => _bookings;
  List<Delivery> get deliveries => _deliveries;

  // Bookings whose event is coming up soon and have NOT been dispatched yet.
  List<Booking> get pendingDeliveries => _bookings.where((b) {
        if (!b.shouldRemind) return false;
        final status = getDeliveryForBooking(b.id)?.status ?? 'pending';
        return status == 'pending';
      }).toList();

  // Bookings that already have a delivery status update (dispatched/delivered/returned).
  List<Booking> get updatedDeliveries {
    final result = _bookings.where((b) {
      final status = getDeliveryForBooking(b.id)?.status;
      return status != null && status != 'pending';
    }).toList();
    result.sort((a, b) {
      final da = getDeliveryForBooking(a.id)?.lastUpdated ?? a.lastUpdated;
      final db = getDeliveryForBooking(b.id)?.lastUpdated ?? b.lastUpdated;
      return db.compareTo(da);
    });
    return result;
  }

  // Current delivery record for a booking, if any.
  Delivery? getDeliveryForBooking(int? bookingId) {
    if (bookingId == null) return null;
    try {
      return _deliveries.firstWhere((d) => d.bookingId == bookingId);
    } catch (e) {
      return null;
    }
  }

  // Load all data from database
  Future<void> loadAllData() async {
    _customers = await _dbHelper.getAllCustomers();
    _bookings = await _dbHelper.getAllBookings();
    _deliveries = await _dbHelper.getAllDeliveries();
    notifyListeners();
  }
  
  // Add customer
  Future<void> addCustomer(String name, String phone, String? address) async {
    final customer = Customer(
      name: name,
      phone: phone,
      address: address,
      createdDate: DateTime.now(),
    );
    
    final id = await _dbHelper.insertCustomer(customer);
    _customers.add(Customer(
      id: id,
      name: name,
      phone: phone,
      address: address,
      createdDate: customer.createdDate,
    ));
    notifyListeners();
  }
  
  // Get customer by ID
  Customer? getCustomer(int id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Update an existing customer
  Future<void> updateCustomer({
    required int id,
    required String name,
    required String phone,
    String? address,
    required DateTime createdDate,
  }) async {
    final customer = Customer(
      id: id,
      name: name,
      phone: phone,
      address: address,
      createdDate: createdDate,
    );

    await _dbHelper.updateCustomer(customer);
    final index = _customers.indexWhere((c) => c.id == id);
    if (index != -1) {
      _customers[index] = customer;
    }
    notifyListeners();
  }

  // Delete a customer along with all of their bookings (and related delivery/alert records)
  Future<void> deleteCustomer(int id) async {
    final customerBookingIds = _bookings.where((b) => b.customerId == id).map((b) => b.id!).toList();
    for (final bookingId in customerBookingIds) {
      await _dbHelper.deleteBooking(bookingId);
      await NotificationService.cancelPendingOrderAlert(bookingId);
    }
    await _dbHelper.deleteCustomer(id);
    _bookings.removeWhere((b) => b.customerId == id);
    _deliveries.removeWhere((d) => customerBookingIds.contains(d.bookingId));
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
  }
  
  // Add booking. Returns the newly created booking's id.
  Future<int> addBooking({
    required int customerId,
    required DateTime rentalDate,
    required double totalAmount,
    required double depositAmount,
    required double paidAmount,
    required List<BookingItem> items,
    String? specialNotes,
  }) async {
    final booking = Booking(
      customerId: customerId,
      rentalDate: rentalDate,
      bookingDate: DateTime.now(),
      totalAmount: totalAmount,
      depositAmount: depositAmount,
      paidAmount: paidAmount,
      specialNotes: specialNotes,
      lastUpdated: DateTime.now(),
      items: items,
    );
    
    final id = await _dbHelper.insertBooking(booking);
    _bookings.add(Booking(
      id: id,
      customerId: customerId,
      rentalDate: rentalDate,
      bookingDate: booking.bookingDate,
      totalAmount: totalAmount,
      depositAmount: depositAmount,
      paidAmount: paidAmount,
      specialNotes: specialNotes,
      lastUpdated: booking.lastUpdated,
      items: items,
    ));
    notifyListeners();
    return id;
  }
  
  // Get booking by ID
  Booking? getBooking(int id) {
    try {
      return _bookings.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  // Update an existing booking
  Future<void> updateBooking({
    required int id,
    required int customerId,
    required DateTime rentalDate,
    required DateTime bookingDate,
    required double totalAmount,
    required double depositAmount,
    required double paidAmount,
    required List<BookingItem> items,
    String? specialNotes,
    bool? balancePaid,
    DateTime? balancePaidDate,
  }) async {
    final existing = getBooking(id);
    final booking = Booking(
      id: id,
      customerId: customerId,
      rentalDate: rentalDate,
      bookingDate: bookingDate,
      totalAmount: totalAmount,
      depositAmount: depositAmount,
      paidAmount: paidAmount,
      balancePaid: balancePaid ?? existing?.balancePaid ?? false,
      balancePaidDate: balancePaidDate ?? existing?.balancePaidDate,
      specialNotes: specialNotes,
      lastUpdated: DateTime.now(),
      items: items,
    );

    await _dbHelper.updateBooking(booking);
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index != -1) {
      _bookings[index] = booking;
    }
    notifyListeners();
  }

  // Mark the remaining balance for a booking as collected
  Future<void> markBalancePaid(int id) async {
    final existing = getBooking(id);
    if (existing == null) return;

    final amountToPayBack = existing.balanceAmount;
    final booking = Booking(
      id: id,
      customerId: existing.customerId,
      rentalDate: existing.rentalDate,
      bookingDate: existing.bookingDate,
      totalAmount: existing.totalAmount,
      depositAmount: existing.depositAmount,
      paidAmount: existing.paidAmount + amountToPayBack,
      balancePaid: true,
      balancePaidDate: DateTime.now(),
      specialNotes: existing.specialNotes,
      lastUpdated: DateTime.now(),
      items: existing.items,
    );

    await _dbHelper.updateBooking(booking);
    final index = _bookings.indexWhere((b) => b.id == id);
    if (index != -1) {
      _bookings[index] = booking;
    }
    notifyListeners();
  }

  // Delete a booking (and its related delivery/alert records)
  Future<void> deleteBooking(int id) async {
    await _dbHelper.deleteBooking(id);
    await NotificationService.cancelPendingOrderAlert(id);
    _bookings.removeWhere((b) => b.id == id);
    _deliveries.removeWhere((d) => d.bookingId == id);
    notifyListeners();
  }
  
  // Update delivery status
  Future<void> updateDeliveryStatus({
    required int bookingId,
    required String courierName,
    required String trackingNumber,
    required String status,
    String? notes,
    String? returnCondition,
  }) async {
    final existing = getDeliveryForBooking(bookingId);
    final delivery = Delivery(
      bookingId: bookingId,
      courierName: courierName,
      trackingNumber: trackingNumber,
      status: status,
      deliveryDate: status == 'delivered' ? DateTime.now() : existing?.deliveryDate,
      notes: notes,
      lastUpdated: DateTime.now(),
      returnDate: status == 'returned' ? DateTime.now() : existing?.returnDate,
      returnCondition: status == 'returned' ? returnCondition : existing?.returnCondition,
      packingPhotoPaths: existing?.packingPhotoPaths,
    );
    
    final id = await _dbHelper.insertDelivery(delivery);
    final updated = Delivery(
      id: id,
      bookingId: bookingId,
      courierName: courierName,
      trackingNumber: trackingNumber,
      status: status,
      deliveryDate: delivery.deliveryDate,
      notes: notes,
      lastUpdated: delivery.lastUpdated,
      returnDate: delivery.returnDate,
      returnCondition: delivery.returnCondition,
      packingPhotoPaths: delivery.packingPhotoPaths,
    );

    if (status == 'dispatched' || status == 'delivered' || status == 'returned') {
      // Order is no longer pending, so stop nagging about it.
      await NotificationService.cancelPendingOrderAlert(bookingId);
    }

    _deliveries.removeWhere((d) => d.bookingId == bookingId);
    _deliveries.add(updated);
    notifyListeners();
  }

  // Save the packing photos taken while gathering items for a booking
  Future<void> savePackingPhotos(int bookingId, List<String> photoPaths) async {
    final existing = getDeliveryForBooking(bookingId);
    final delivery = Delivery(
      bookingId: bookingId,
      courierName: existing?.courierName,
      trackingNumber: existing?.trackingNumber,
      status: existing?.status ?? 'pending',
      deliveryDate: existing?.deliveryDate,
      notes: existing?.notes,
      lastUpdated: DateTime.now(),
      returnDate: existing?.returnDate,
      returnCondition: existing?.returnCondition,
      packingPhotoPaths: photoPaths.isEmpty ? null : photoPaths.join(','),
    );

    final id = await _dbHelper.insertDelivery(delivery);
    final updated = Delivery(
      id: id,
      bookingId: bookingId,
      courierName: delivery.courierName,
      trackingNumber: delivery.trackingNumber,
      status: delivery.status,
      deliveryDate: delivery.deliveryDate,
      notes: delivery.notes,
      lastUpdated: delivery.lastUpdated,
      returnDate: delivery.returnDate,
      returnCondition: delivery.returnCondition,
      packingPhotoPaths: delivery.packingPhotoPaths,
    );
    _deliveries.removeWhere((d) => d.bookingId == bookingId);
    _deliveries.add(updated);
    notifyListeners();
  }
  
  // Get bookings for a customer
  List<Booking> getCustomerBookings(int customerId) {
    return _bookings.where((b) => b.customerId == customerId).toList();
  }
  
  // Search bookings by customer name
  List<Booking> searchBookings(String query) {
    final lowerQuery = query.toLowerCase();
    return _bookings.where((booking) {
      final customer = getCustomer(booking.customerId);
      return customer?.name.toLowerCase().contains(lowerQuery) ?? false;
    }).toList();
  }
  
  // Get reminders to send
  Future<List<Booking>> getPendingReminders() async {
    final reminders = await _dbHelper.getPendingReminders();
    return reminders
        .map((r) => getBooking(r['bookingId']))
        .whereType<Booking>()
        .toList();
  }
  
  // Mark reminder as sent
  Future<void> markReminderAsSent(int reminderId) async {
    await _dbHelper.updateReminder(reminderId, true, 1);
    notifyListeners();
  }

  // Starts, stops or leaves alone the repeating pending-order alert for a
  // single booking, based on its delivery status and how close it is to
  // the rental date relative to settings.pendingOrderAlertStartDaysBefore.
  Future<void> syncPendingOrderAlertForBooking(Booking booking, SettingsService settings) async {
    if (booking.id == null) return;

    final status = getDeliveryForBooking(booking.id)?.status ?? 'pending';
    final withinAlertWindow = booking.daysUntilRental <= settings.pendingOrderAlertStartDaysBefore;

    if (!settings.pendingOrderAlertsEnabled || status != 'pending' || !withinAlertWindow) {
      await NotificationService.cancelPendingOrderAlert(booking.id!);
      return;
    }

    final customer = getCustomer(booking.customerId);
    if (customer == null) return;
    await NotificationService.schedulePendingOrderAlert(
      booking: booking,
      customerName: customer.name,
      intervalHours: settings.pendingOrderAlertIntervalHours,
    );
  }

  // Re-evaluates the pending-order alert for every booking. Call this after
  // loading data, on app resume and whenever the alert settings change, so
  // that alerts start/stop as bookings cross the start-days-before threshold
  // even while the app wasn't open to react to it directly.
  Future<void> syncAllPendingOrderAlerts(SettingsService settings) async {
    for (final booking in _bookings) {
      await syncPendingOrderAlertForBooking(booking, settings);
    }
  }
}

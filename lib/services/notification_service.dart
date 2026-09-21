import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/booking.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    // Request Android notification permission for Android 13+
    try {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      // ignore: avoid_print
      print('Failed to request notification permission: $e');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    required int id,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'rental_channel',
      'Rental Notifications',
      channelDescription: 'Notifications for rental bookings',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinNotificationDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  // Starts a repeating alert for a booking that hasn't been dispatched yet,
  // firing every `intervalHours` until cancelPendingOrderAlert is called
  // (which happens once the delivery status leaves 'pending').
  static Future<void> schedulePendingOrderAlert({
    required Booking booking,
    required String customerName,
    required int intervalHours,
  }) async {
    if (booking.id == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'pending_order_channel',
        'Pending Order Alerts',
        channelDescription: 'Repeating alerts for bookings awaiting dispatch',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _notificationsPlugin.periodicallyShowWithDuration(
        _pendingOrderAlertId(booking.id!),
        'Order Awaiting Dispatch',
        '$customerName\'s rental is still pending dispatch',
        Duration(hours: intervalHours),
        details,
        // Inexact is fine for an hours-scale repeat and, unlike exact
        // alarms, doesn't depend on the user granting the special
        // Android 12+ "Alarms & reminders" permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Failed to schedule pending order alert for booking ${booking.id}: $e');
    }
  }

  static Future<void> cancelPendingOrderAlert(int bookingId) async {
    try {
      await _notificationsPlugin.cancel(_pendingOrderAlertId(bookingId));
    } catch (e) {
      debugPrint('Failed to cancel pending order alert for booking $bookingId: $e');
    }
  }

  // Keeps pending-order-alert ids from colliding with each other or with delivery notification ids.
  static int _pendingOrderAlertId(int bookingId) => 5000000 + bookingId;

  static Future<void> showDeliveryNotification({
    required String courierName,
    required String trackingNumber,
  }) async {
    await showNotification(
      id: DateTime.now().microsecond,
      title: 'Delivery Dispatched',
      body: 'Courier: $courierName, Tracking: $trackingNumber',
    );
  }
}

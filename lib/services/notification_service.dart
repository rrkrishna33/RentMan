import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/booking.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Reminder scheduling uses TZDateTime, which requires the timezone database to be loaded first.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

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

  // Schedules daily reminders starting `daysBefore` days ahead of the rental date,
  // continuing up to the rental date until the booking is dispatched.
  static Future<void> scheduleReminderNotification({
    required Booking booking,
    required String customerName,
    required int daysBefore,
    required int hour,
    required int minute,
  }) async {
    final now = DateTime.now();
    final rentalDate = booking.rentalDate;
    final daysUntil = rentalDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (daysUntil <= 0 || booking.id == null) return;

    final startDay = daysUntil > daysBefore ? daysUntil - daysBefore : 0;

    for (int day = startDay; day <= daysUntil; day++) {
      final scheduledDate = now.add(Duration(days: day));
      final notificationTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
      );

      if (!notificationTime.isAfter(now)) continue;

      try {
        await _notificationsPlugin.zonedSchedule(
          _reminderNotificationId(booking.id!, day),
          'Rental Manager Reminder',
          'Send $customerName rented items for pickup on ${rentalDate.day}/${rentalDate.month}',
          tz.TZDateTime.from(notificationTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'rental_channel',
              'Rental Notifications',
              channelDescription: 'Notifications for rental bookings',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('Failed to schedule reminder for booking ${booking.id}, day $day: $e');
      }
    }
  }

  static Future<void> cancelReminders(int bookingId) async {
    for (int i = 0; i < 31; i++) {
      try {
        await _notificationsPlugin.cancel(_reminderNotificationId(bookingId, i));
      } catch (e) {
        // ignore: avoid_print
        print('Failed to cancel reminder for booking $bookingId, offset $i: $e');
      }
    }
  }

  static List<DateTime> debugReminderTimes({
    required Booking booking,
    required int daysBefore,
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    final rentalDate = booking.rentalDate;
    final daysUntil = rentalDate.difference(DateTime(now.year, now.month, now.day)).inDays;

    if (daysUntil <= 0 || booking.id == null) return const [];

    final startDay = daysUntil > daysBefore ? daysUntil - daysBefore : 0;
    final times = <DateTime>[];

    for (int day = startDay; day <= daysUntil; day++) {
      final scheduledDate = now.add(Duration(days: day));
      final notificationTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
      );

      if (!notificationTime.isAfter(now)) continue;
      times.add(notificationTime);
    }

    return times;
  }

  // Keeps reminder ids for different bookings from colliding with each other or with delivery notification ids.
  static int _reminderNotificationId(int bookingId, int dayOffset) => bookingId * 1000 + dayOffset;

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

  static Future<void> showTestReminder() async {
    await showNotification(
      id: DateTime.now().microsecond,
      title: 'Rental Manager Reminder',
      body: 'Test reminder working. This is a sample notification.',
    );
  }
}

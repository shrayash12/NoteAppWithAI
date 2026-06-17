import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const int _dailyReminderId = 1;

  static final _noteTapController = StreamController<String>.broadcast();
  static Stream<String> get noteTapStream => _noteTapController.stream;

  static int _noteNotificationId(String noteId) =>
      noteId.hashCode.abs() % 100000 + 100;

  static const _androidReminderDetails = AndroidNotificationDetails(
    'smartnotes_reminders',
    'Daily Reminders',
    channelDescription: 'Daily reminder to write notes',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _androidGeneralDetails = AndroidNotificationDetails(
    'smartnotes_general',
    'General',
    channelDescription: 'SmartNotes general notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _noteTapController.add(details.payload!);
        }
      },
    );
    _initialized = true;
  }

  /// Request notification permissions (Android 13+ / iOS)
  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final result = await android.requestNotificationsPermission();
      return result ?? false;
    } else if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }
    return true;
  }

  /// Show an immediate notification
  static Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: _androidGeneralDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule a daily reminder at the given time
  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await cancelDailyReminder();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: 'SmartNotes Reminder',
      body: 'Time to capture your thoughts! Open SmartNotes and write something.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: _androidReminderDetails,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(id: _dailyReminderId);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Schedule a one-time reminder for a specific note
  static Future<void> scheduleNoteReminder({
    required String noteId,
    required String noteTitle,
    required DateTime reminderTime,
  }) async {
    final id = _noteNotificationId(noteId);
    await _plugin.cancel(id: id);
    if (reminderTime.isBefore(DateTime.now())) return;
    final scheduled = tz.TZDateTime.from(reminderTime, tz.local);
    await _plugin.zonedSchedule(
      id: id,
      title: 'Reminder: $noteTitle',
      body: 'Tap to open your note.',
      scheduledDate: scheduled,
      payload: noteId,
      notificationDetails: const NotificationDetails(
        android: _androidReminderDetails,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancel the reminder for a specific note
  static Future<void> cancelNoteReminder(String noteId) async {
    await _plugin.cancel(id: _noteNotificationId(noteId));
  }
}

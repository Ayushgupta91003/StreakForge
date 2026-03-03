import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database and set local
    tz_data.initializeTimeZones();
    // Get the device timezone name
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      // Map common timezone abbreviations to tz database names
      final tzName = _resolveTimezoneName(timeZoneName);
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      // Fallback – use UTC offset to pick a reasonable timezone
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours;
      try {
        if (hours >= 5 && hours <= 6) {
          tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        } else {
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request Android 13+ notification permission
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    }

    _initialized = true;
    debugPrint('NotificationService initialized, timezone: ${tz.local.name}');
  }

  /// Resolve timezone abbreviation to tz database name
  String _resolveTimezoneName(String abbr) {
    // Common abbreviations mapping
    const map = {
      'IST': 'Asia/Kolkata',
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      'GMT': 'Europe/London',
      'BST': 'Europe/London',
      'CET': 'Europe/Berlin',
      'CEST': 'Europe/Berlin',
      'JST': 'Asia/Tokyo',
      'AEST': 'Australia/Sydney',
      'AEDT': 'Australia/Sydney',
    };
    return map[abbr] ?? 'UTC';
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Schedule a daily notification at a specific time
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    debugPrint(
        'Scheduling daily notification id=$id at $hour:$minute, next: $scheduled');

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_forge_reminders',
          'Habit Reminders',
          channelDescription: 'Daily reminders for your habits',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          channelShowBadge: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedule notification for specific days of the week
  Future<void> scheduleWeekly({
    required int baseId,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays, // 1=Mon, 7=Sun
    String? payload,
  }) async {
    for (final day in weekdays) {
      await _plugin.zonedSchedule(
        baseId + day,
        title,
        body,
        _nextInstanceOfWeekdayTime(day, hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_forge_reminders',
            'Habit Reminders',
            channelDescription: 'Daily reminders for your habits',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            channelShowBadge: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Send an immediate test notification
  Future<void> showTestNotification() async {
    await _plugin.show(
      99999,
      'StreakForge 🔥',
      'Notifications are working! Keep forging streaks 💪',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_forge_reminders',
          'Habit Reminders',
          channelDescription: 'Daily reminders for your habits',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          channelShowBadge: true,
        ),
      ),
    );
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications for a reminder
  Future<void> cancelReminder(int baseId) async {
    for (int i = 0; i <= 7; i++) {
      await _plugin.cancel(baseId + i);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Get all pending notifications
  Future<List<PendingNotificationRequest>> getPending() async {
    return await _plugin.pendingNotificationRequests();
  }
}

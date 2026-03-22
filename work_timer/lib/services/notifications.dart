import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'schedule.dart';

final _plugin = FlutterLocalNotificationsPlugin();

final _notifActionController = StreamController<String>.broadcast();

/// Emits action IDs ('stop' or 'silence') when user taps a notification action button.
Stream<String> get onNotificationAction => _notifActionController.stream;

Future<void> initNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final macosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    notificationCategories: [
      DarwinNotificationCategory(
        'timer_alert',
        actions: [
          DarwinNotificationAction.plain('stop', 'Stop'),
          DarwinNotificationAction.plain('silence', 'Silence'),
        ],
      ),
    ],
  );
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const linuxSettings = LinuxInitializationSettings(
    defaultActionName: 'Open',
  );

  await _plugin.initialize(
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
      linux: linuxSettings,
    ),
    onDidReceiveNotificationResponse: (response) {
      final actionId = response.actionId;
      if (actionId != null && actionId.isNotEmpty) {
        _notifActionController.add(actionId);
      }
    },
  );
}

Future<void> requestPermissions() async {
  await _plugin
      .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  await _plugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

const _channel = AndroidNotificationChannel(
  'work_timer',
  'Work Timer',
  description: 'Work session transition alerts',
  importance: Importance.high,
);

Future<void> scheduleAll(Schedule schedule, {int offsetMs = 0}) async {
  await cancelAll();

  // Create Android notification channel
  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  // Schedule a notification at the END of each phase (= start of next)
  for (int i = 0; i < schedule.phases.length; i++) {
    final phase = schedule.phases[i];
    final isLast = i == schedule.phases.length - 1;

    String title;
    String body;

    if (isLast) {
      title = 'Session Complete!';
      body = 'Great work today. Your session has ended.';
    } else {
      final next = schedule.phases[i + 1].phase;
      if (next.isBreak) {
        title = next.name == 'Lunch Break'
            ? 'Lunch time!'
            : 'Break time!';
        body = next.name == 'Lunch Break'
            ? 'Take your 1-hour lunch break.'
            : 'Take a 15-minute break.';
      } else {
        title = 'Back to work';
        body = 'Break is over — time to focus.';
      }
    }

    final adjustedEnd = phase.endTime.add(Duration(milliseconds: offsetMs));
    final scheduledTime = tz.TZDateTime.from(adjustedEnd, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) continue;

    await _plugin.zonedSchedule(
      i,
      title,
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'timer_alert',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

Future<void> cancelAll() async {
  await _plugin.cancelAll();
}

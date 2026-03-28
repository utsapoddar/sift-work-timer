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
  final categoryActions = [
    DarwinNotificationAction.plain('stop', 'Stop'),
    DarwinNotificationAction.plain('silence', 'Silence'),
  ];
  final darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    notificationCategories: [
      DarwinNotificationCategory('timer_alert', actions: categoryActions),
    ],
  );
  const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');

  await _plugin.initialize(
    settings: InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
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
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  await _plugin
      .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

const _androidChannel = AndroidNotificationChannel(
  'work_timer',
  'Work Timer',
  description: 'Work session transition alerts',
  importance: Importance.high,
);

Future<void> scheduleAll(Schedule schedule, {int offsetMs = 0}) async {
  await cancelAll();

  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);

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
        title = next.name == 'Lunch Break' ? 'Lunch time!' : 'Break time!';
        body = next.name == 'Lunch Break'
            ? 'Take your 1-hour lunch break.'
            : 'Take a 15-minute break.';
      } else {
        title = 'Back to work';
        body = 'Break is over — time to focus.';
      }
    }

    final adjustedEnd = phase.endTime.add(Duration(milliseconds: offsetMs));
    // Use absolute UTC epoch ms — correct regardless of device timezone
    final scheduledTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
        tz.UTC, adjustedEnd.millisecondsSinceEpoch);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.UTC))) continue;

    await _plugin.zonedSchedule(
      id: i,
      title: title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // alarm.caf is copied to Library/Sounds at app launch in AppDelegate
          sound: 'alarm.caf',
          categoryIdentifier: 'timer_alert',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'timer_alert',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

Future<void> cancelNotification(int id) async {
  await _plugin.cancel(id: id);
}

Future<void> cancelAll() async {
  await _plugin.cancelAll();
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Key for actions
  static const String actionMarkDone = 'mark_done';

  Future<void> initialize(
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
  ) async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    // flutter_timezone 5.x returns TimezoneInfo; use .identifier for the name
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _isInitialized = true;
  }

  // Static callback for background notification actions
  @pragma('vm:entry-point')
  static void notificationTapBackground(
    NotificationResponse notificationResponse,
  ) {
    debugPrint(
      '[NotifService] Background action: ${notificationResponse.actionId}, '
      'payload: ${notificationResponse.payload}',
    );
    // When the Mark Done button is tapped, the notification is auto-dismissed
    // via cancelNotification: true on the action.
    // The app will reconcile state on next launch.
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Show an instant test notification to verify the pipeline works.
  Future<void> showTestNotification() async {
    debugPrint('[NotifService] Firing instant test notification');
    await flutterLocalNotificationsPlugin.show(
      id: 99999,
      title: 'Test Notification \u{1F514}',
      body: 'If you see this, notifications are working!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_app_channel',
          'To-Do Alerts',
          channelDescription: 'Test notification',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool ongoing = true,
  }) async {
    // Don't schedule in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint(
        '[NotifService] SKIPPED (in past): "$title" at $scheduledDate',
      );
      return;
    }
    debugPrint(
      '[NotifService] Scheduling: "$title" at $scheduledDate (id=$id)',
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'todo_persistent_channel',
          'To-Do Alerts',
          channelDescription: 'Reminders for tasks, courses, and events',
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_notification',
          ongoing: ongoing, // Non-swipeable
          autoCancel: false, // Don't auto-cancel on tap
          actions: [
            AndroidNotificationAction(
              actionMarkDone,
              'Mark Done',
              showsUserInterface: false,
              cancelNotification: true, // Dismisses on action
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/database/database_helper.dart';

@pragma('vm:entry-point')
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
  static Future<void> notificationTapBackground(
    NotificationResponse notificationResponse,
  ) async {
    debugPrint(
      '[NotifService] Background action: ${notificationResponse.actionId}, '
      'payload: ${notificationResponse.payload}, '
      'input: ${notificationResponse.input}',
    );

    if (notificationResponse.actionId == actionMarkDone) {
      final payload = notificationResponse.payload;
      if (payload != null) {
        final parts = payload.split('|');
        if (parts.length >= 2) {
          final type = parts[0];
          final idStr = parts[1];
          final id = int.tryParse(idStr);
          // NEW: Parsing rowId if available (3rd part)
          int? rowId;
          if (parts.length >= 3) {
            rowId = int.tryParse(parts[2]);
          }

          if (id != null) {
            // Initialize DB helper for this isolate
            if (Platform.isWindows || Platform.isLinux) {
              // FFI init might be needed here if on desktop, but usually
              // main() handles it. In background isolate, might need check.
              // Skipping FFI check for now as Android is primary target for this.
            }

            // Manual "cancelForItem" logic for Background Isolate
            // We avoid calling NotificationScheduler.cancelForItem to prevent static initialization issues.
            // Using raw DB operations via DatabaseHelper.

            final dbHelper = DatabaseHelper.instance;

            if (type == 'Task') {
              // Mark Task Completed
              final task = await dbHelper.database.then(
                (db) => db.query('tasks', where: 'id = ?', whereArgs: [id]),
              );
              if (task.isNotEmpty) {
                final updatedTask = Map<String, dynamic>.from(task.first);
                updatedTask['is_completed'] = 1;
                await dbHelper.updateTask(updatedTask);
              }

              // Cancel all notifications for this task
              debugPrint(
                '[NotifService] Cleaning up notifications for Task $id',
              );
              final rows = await dbHelper.getNotificationsFor('task_id', id);
              for (final row in rows) {
                await FlutterLocalNotificationsPlugin().cancel(
                  id: row['id'] as int,
                );
              }
              await dbHelper.deleteNotificationsFor('task_id', id);
            } else if (type == 'Assignment') {
              // Mark Assignment Completed
              final assignment = await dbHelper.database.then(
                (db) =>
                    db.query('assignments', where: 'id = ?', whereArgs: [id]),
              );
              if (assignment.isNotEmpty) {
                final updatedAssignment = Map<String, dynamic>.from(
                  assignment.first,
                );
                updatedAssignment['is_completed'] = 1;
                await dbHelper.updateAssignment(updatedAssignment);
              }

              // Cancel all notifications for this assignment
              debugPrint(
                '[NotifService] Cleaning up notifications for Assignment $id',
              );
              final rows = await dbHelper.getNotificationsFor(
                'assignment_id',
                id,
              );
              for (final row in rows) {
                await FlutterLocalNotificationsPlugin().cancel(
                  id: row['id'] as int,
                );
              }
              await dbHelper.deleteNotificationsFor('assignment_id', id);
            } else {
              // Fallback for other types or parsing errors: use explicit ID
              final cancelId = rowId ?? notificationResponse.id;
              if (cancelId != null) {
                await FlutterLocalNotificationsPlugin().cancel(id: cancelId);
              }
            }
          }
        }
      }
    }
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

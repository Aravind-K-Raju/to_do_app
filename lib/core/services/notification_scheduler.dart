import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/database/database_helper.dart';
import '../../presentation/providers/task_provider.dart';
import '../../presentation/providers/course_provider.dart';
import '../../presentation/providers/assignment_provider.dart';
import '../../presentation/providers/hackathon_provider.dart';
import 'notification_service.dart';
import 'notification_prefs_service.dart';

class NotificationScheduler {
  static final _db = DatabaseHelper.instance;
  static final _notifService = NotificationService();
  static final _prefsService = NotificationPrefsService();

  // --------------- Core: Insert DB rows + schedule OS ---------------

  /// Insert notification rows for an item's date, respecting user prefs
  /// (same-day, 1-day-before, 3-days-before). Returns inserted row IDs.
  static Future<List<int>> _insertRemindersForDate({
    required String itemTitle,
    required String bodyText,
    required DateTime dueDate,
    required String fkColumn,
    required int itemId,
    required String notifType,
  }) async {
    final time = await _prefsService.getNotificationTime();
    final sameDay = await _prefsService.getNotifySameDay();
    final oneDay = await _prefsService.getNotify1DayBefore();
    final threeDays = await _prefsService.getNotify3DaysBefore();

    final now = DateTime.now();
    final insertedIds = <int>[];

    final offsets = <int, String>{};
    if (sameDay) offsets[0] = 'Today: $bodyText';
    if (oneDay) offsets[1] = 'Tomorrow: $bodyText';
    if (threeDays) offsets[3] = 'In 3 Days: $bodyText';

    for (final entry in offsets.entries) {
      final scheduledDate = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        time.hour,
        time.minute,
      ).subtract(Duration(days: entry.key));

      if (scheduledDate.isAfter(now)) {
        final rowId = await _db.insertScheduledNotification({
          'scheduled_at': scheduledDate.toIso8601String(),
          'title': '$notifType Reminder: $itemTitle',
          'body': entry.value,
          'type': notifType == 'Timeline' ? 'timeline' : 'reminder',
          fkColumn: itemId,
        });
        insertedIds.add(rowId);
        debugPrint(
          '[NotifScheduler] Inserted DB row $rowId: "$itemTitle" at $scheduledDate',
        );
      }
    }
    return insertedIds;
  }

  /// Schedule OS alarms for a list of DB row IDs.
  static Future<void> _scheduleOsForIds(List<int> ids) async {
    for (final id in ids) {
      await _scheduleOsForRow(id);
    }
  }

  /// Schedule a single OS alarm from a DB row ID.
  static Future<void> _scheduleOsForRow(int rowId) async {
    final db = await _db.database;
    final rows = await db.query(
      'scheduled_notifications',
      where: 'id = ?',
      whereArgs: [rowId],
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final scheduledAt = DateTime.parse(row['scheduled_at'] as String);
    if (scheduledAt.isBefore(DateTime.now())) return;

    // Build payload from FK columns
    String? payload;
    if (row['course_id'] != null) {
      payload = 'Course|${row['course_id']}|$rowId';
    }
    if (row['task_id'] != null) {
      payload = 'Task|${row['task_id']}|$rowId';
    }
    if (row['assignment_id'] != null) {
      payload = 'Assignment|${row['assignment_id']}|$rowId';
    }
    if (row['hackathon_id'] != null) {
      payload = 'Event|${row['hackathon_id']}|$rowId';
    }

    await _notifService.scheduleNotification(
      id: rowId, // DB row ID = OS notification ID
      title: row['title'] as String,
      body: row['body'] as String,
      scheduledDate: scheduledAt,
      payload: payload,
      ongoing: true,
    );
  }

  // --------------- Public API for Providers ---------------

  /// Schedule notifications for a Course (start date + timeline).
  static Future<void> scheduleForCourse({
    required int courseId,
    required String title,
    required DateTime startDate,
    required List<Map<String, dynamic>>
    timeline, // [{date: DateTime, description: String}]
  }) async {
    final ids = <int>[];

    // Start date reminders
    ids.addAll(
      await _insertRemindersForDate(
        itemTitle: title,
        bodyText: 'Course starts!',
        dueDate: startDate,
        fkColumn: 'course_id',
        itemId: courseId,
        notifType: 'Course',
      ),
    );

    // Timeline entry reminders
    for (final entry in timeline) {
      ids.addAll(
        await _insertRemindersForDate(
          itemTitle: title,
          bodyText: 'Timeline: ${entry['description']}',
          dueDate: entry['date'] as DateTime,
          fkColumn: 'course_id',
          itemId: courseId,
          notifType: 'Course',
        ),
      );
    }

    await _scheduleOsForIds(ids);
  }

  /// Schedule notifications for a Task.
  static Future<void> scheduleForTask({
    required int taskId,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    final ids = await _insertRemindersForDate(
      itemTitle: title,
      bodyText: body,
      dueDate: dueDate,
      fkColumn: 'task_id',
      itemId: taskId,
      notifType: 'Task',
    );
    await _scheduleOsForIds(ids);
  }

  /// Schedule notifications for an Assignment.
  static Future<void> scheduleForAssignment({
    required int assignmentId,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    final ids = await _insertRemindersForDate(
      itemTitle: title,
      bodyText: body,
      dueDate: dueDate,
      fkColumn: 'assignment_id',
      itemId: assignmentId,
      notifType: 'Assignment',
    );
    await _scheduleOsForIds(ids);
  }

  /// Schedule notifications for a Hackathon (start date + timeline).
  static Future<void> scheduleForHackathon({
    required int hackathonId,
    required String title,
    required DateTime startDate,
    required List<Map<String, dynamic>> timeline,
  }) async {
    final ids = <int>[];

    ids.addAll(
      await _insertRemindersForDate(
        itemTitle: title,
        bodyText: 'Event starts!',
        dueDate: startDate,
        fkColumn: 'hackathon_id',
        itemId: hackathonId,
        notifType: 'Event',
      ),
    );

    for (final entry in timeline) {
      ids.addAll(
        await _insertRemindersForDate(
          itemTitle: title,
          bodyText: 'Timeline: ${entry['description']}',
          dueDate: entry['date'] as DateTime,
          fkColumn: 'hackathon_id',
          itemId: hackathonId,
          notifType: 'Event',
        ),
      );
    }

    await _scheduleOsForIds(ids);
  }

  // --------------- Cancel: Query IDs → Cancel OS → Delete DB ---------------

  /// Cancel all notifications for an item. Order: query IDs → cancel OS → delete DB rows.
  static Future<void> cancelForItem(String fkColumn, int itemId) async {
    debugPrint('[NotifScheduler] cancelForItem called for $fkColumn=$itemId');
    // 1. Query IDs from DB
    final rows = await _db.getNotificationsFor(fkColumn, itemId);
    debugPrint('[NotifScheduler] Found ${rows.length} notifications to cancel');

    // 2. Cancel OS alarms
    for (final row in rows) {
      final id = row['id'] as int;
      debugPrint('[NotifScheduler] Cancelling OS notification ID: $id');
      await _notifService.cancelNotification(id);
    }
    // 3. Delete DB rows (or let CASCADE handle it if parent is being deleted)
    await _db.deleteNotificationsFor(fkColumn, itemId);
    debugPrint(
      '[NotifScheduler] Cancelled ${rows.length} notifications for $fkColumn=$itemId',
    );
  }

  // --------------- Reschedule All from DB ---------------

  /// Re-schedule all future notifications from DB (e.g. after reboot or settings change).
  static Future<void> rescheduleAllFromDb() async {
    await _notifService.cancelAll();
    final rows = await _db.getAllScheduledNotifications();
    int scheduled = 0;
    for (final row in rows) {
      final scheduledAt = DateTime.parse(row['scheduled_at'] as String);
      if (scheduledAt.isAfter(DateTime.now())) {
        await _scheduleOsForRow(row['id'] as int);
        scheduled++;
      }
    }
    debugPrint('[NotifScheduler] Rescheduled $scheduled notifications from DB');
  }

  // --------------- Backfill from Existing Data (V8 migration) ---------------

  /// Populate scheduled_notifications from existing items.
  /// Called once at startup after V8 migration.
  static Future<void> backfillFromExisting(BuildContext context) async {
    // Check if backfill already done (table has rows)
    final existing = await _db.getAllScheduledNotifications();
    if (existing.isNotEmpty) return;

    if (!context.mounted) return;
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final assignmentProvider = Provider.of<AssignmentProvider>(
      context,
      listen: false,
    );
    final hackathonProvider = Provider.of<HackathonProvider>(
      context,
      listen: false,
    );

    // Ensure data is loaded
    await Future.wait([
      courseProvider.loadCourses(),
      taskProvider.loadAllTasks(),
      assignmentProvider.loadAssignments(),
      hackathonProvider.loadHackathons(),
    ]);

    // Courses
    for (final course in courseProvider.courses) {
      if (course.id == null) continue;
      await scheduleForCourse(
        courseId: course.id!,
        title: course.title,
        startDate: course.startDate,
        timeline: course.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }

    // Tasks
    for (final task in taskProvider.allTasks) {
      if (task.id == null || task.isCompleted || task.dueDate == null) continue;
      await scheduleForTask(
        taskId: task.id!,
        title: task.title,
        body: task.description ?? 'Task due',
        dueDate: task.dueDate!,
      );
    }

    // Assignments
    for (final assignment in assignmentProvider.assignments) {
      if (assignment.id == null || assignment.isCompleted) continue;
      await scheduleForAssignment(
        assignmentId: assignment.id!,
        title: assignment.title,
        body: '${assignment.subject ?? ''} - ${assignment.type}',
        dueDate: assignment.dueDate,
      );
    }

    // Hackathons
    for (final hackathon in hackathonProvider.hackathons) {
      if (hackathon.id == null) continue;
      await scheduleForHackathon(
        hackathonId: hackathon.id!,
        title: hackathon.name,
        startDate: hackathon.startDate,
        timeline: hackathon.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }

    debugPrint('[NotifScheduler] Backfill complete');
  }

  /// Reschedule all notifications (rebuild from providers).
  /// Used when user changes notification preferences.
  static Future<void> rescheduleAll(BuildContext context) async {
    // Nuke everything
    await _notifService.cancelAll();
    final db = await _db.database;
    await db.delete('scheduled_notifications');

    if (!context.mounted) return;
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final assignmentProvider = Provider.of<AssignmentProvider>(
      context,
      listen: false,
    );
    final hackathonProvider = Provider.of<HackathonProvider>(
      context,
      listen: false,
    );

    await Future.wait([
      courseProvider.loadCourses(),
      taskProvider.loadAllTasks(),
      assignmentProvider.loadAssignments(),
      hackathonProvider.loadHackathons(),
    ]);

    for (final course in courseProvider.courses) {
      if (course.id == null) continue;
      await scheduleForCourse(
        courseId: course.id!,
        title: course.title,
        startDate: course.startDate,
        timeline: course.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }

    for (final task in taskProvider.allTasks) {
      if (task.id == null || task.isCompleted || task.dueDate == null) continue;
      await scheduleForTask(
        taskId: task.id!,
        title: task.title,
        body: task.description ?? 'Task due',
        dueDate: task.dueDate!,
      );
    }

    for (final assignment in assignmentProvider.assignments) {
      if (assignment.id == null || assignment.isCompleted) continue;
      await scheduleForAssignment(
        assignmentId: assignment.id!,
        title: assignment.title,
        body: '${assignment.subject ?? ''} - ${assignment.type}',
        dueDate: assignment.dueDate,
      );
    }

    for (final hackathon in hackathonProvider.hackathons) {
      if (hackathon.id == null) continue;
      await scheduleForHackathon(
        hackathonId: hackathon.id!,
        title: hackathon.name,
        startDate: hackathon.startDate,
        timeline: hackathon.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }

    debugPrint('[NotifScheduler] Full reschedule complete');
  }
}

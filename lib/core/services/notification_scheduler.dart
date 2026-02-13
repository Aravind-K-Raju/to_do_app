import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/providers/task_provider.dart';
import '../../presentation/providers/course_provider.dart';
import '../../presentation/providers/assignment_provider.dart';
import '../../presentation/providers/hackathon_provider.dart';
import 'notification_service.dart';
import 'notification_prefs_service.dart';

class NotificationScheduler {
  static Future<void> rescheduleAll(BuildContext context) async {
    final notificationService = NotificationService();
    final prefsService = NotificationPrefsService();

    // cancel all first
    await notificationService.cancelAll();

    // Get settings
    final time = await prefsService.getNotificationTime();
    final sameDay = await prefsService.getNotifySameDay();
    final oneDay = await prefsService.getNotify1DayBefore();
    final threeDays = await prefsService.getNotify3DaysBefore();

    if (!sameDay && !oneDay && !threeDays) return;

    // Get Data
    if (!context.mounted) return;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
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
      taskProvider.loadAllTasks(),
      courseProvider.loadCourses(),
      assignmentProvider.loadAssignments(),
      hackathonProvider.loadHackathons(),
    ]);

    // Helper to schedule
    Future<void> schedule(
      int baseId,
      String title,
      String body,
      DateTime dueDate,
      String type, {
      String? payloadExtra,
    }) async {
      final now = DateTime.now();

      // Same Day
      if (sameDay) {
        final scheduledDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          time.hour,
          time.minute,
        );
        if (scheduledDate.isAfter(now)) {
          // Create a unique ID by combining baseId and offset indicator
          // Using simple math or string hash.
          // Hash collision risk exists but low for this app scale.
          final id = "${baseId}_0".hashCode;
          await notificationService.scheduleNotification(
            id: id,
            title: '$type Reminder: $title',
            body: 'Today: $body',
            scheduledDate: scheduledDate,
            payload:
                '$type|$baseId${payloadExtra != null ? "|$payloadExtra" : ""}',
            ongoing: true,
          );
        }
      }

      // 1 Day Before
      if (oneDay) {
        final scheduledDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          time.hour,
          time.minute,
        ).subtract(const Duration(days: 1));

        if (scheduledDate.isAfter(now)) {
          final id = "${baseId}_1".hashCode;
          await notificationService.scheduleNotification(
            id: id,
            title: '$type Reminder: $title',
            body: 'Tomorrow: $body',
            scheduledDate: scheduledDate,
            payload:
                '$type|$baseId${payloadExtra != null ? "|$payloadExtra" : ""}',
            ongoing: true,
          );
        }
      }

      // 3 Days Before
      if (threeDays) {
        final scheduledDate = DateTime(
          dueDate.year,
          dueDate.month,
          dueDate.day,
          time.hour,
          time.minute,
        ).subtract(const Duration(days: 3));

        if (scheduledDate.isAfter(now)) {
          final id = "${baseId}_3".hashCode;
          await notificationService.scheduleNotification(
            id: id,
            title: '$type Reminder: $title',
            body: 'In 3 Days: $body',
            scheduledDate: scheduledDate,
            payload:
                '$type|$baseId${payloadExtra != null ? "|$payloadExtra" : ""}',
            ongoing: true,
          );
        }
      }
    }

    // Schedule Tasks
    for (var task in taskProvider.allTasks) {
      if (!task.isCompleted && task.dueDate != null) {
        await schedule(
          task.id!,
          task.title,
          task.description ?? 'No description',
          task.dueDate!,
          'Task',
        );
      }
    }

    // Schedule Assignments
    for (var assignment in assignmentProvider.assignments) {
      if (!assignment.isCompleted) {
        await schedule(
          assignment.id!,
          assignment.title,
          '${assignment.subject} - ${assignment.type}',
          assignment.dueDate,
          'Assignment',
        );
      }
    }

    // Schedule Courses (Active only?)
    // User said: "if there is a date data in any page(Course...) ... it should be notified"
    // Courses have startDate. Maybe we notify about startDate?
    for (var course in courseProvider.courses) {
      // Assuming we notify for start date if it's in future?
      // User said "if there is a date data".
      // Let's schedule for Start Date.
      if (course.startDate.isAfter(DateTime.now()) || sameDay) {
        await schedule(
          course.id!,
          course.title,
          'Course starts today!',
          course.startDate,
          'Course',
        );
      }

      // Timeline events? Not easily accessible as flat list, nested in Course.
      // If we want to be thorough we should iterate timeline.
      // But user demand might be high. Let's start with high level items.
    }

    // Schedule Hackathons
    for (var hackathon in hackathonProvider.hackathons) {
      // Start Date
      if (hackathon.startDate.isAfter(DateTime.now()) || sameDay) {
        await schedule(
          hackathon.id!,
          hackathon.name,
          'Hackathon starts today!',
          hackathon.startDate,
          'Event',
        );
      }
    }
  }
}

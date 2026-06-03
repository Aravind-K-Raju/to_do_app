import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database/database_helper.dart';
import 'notification_prefs_service.dart';
import 'gemini_service.dart';

class WidgetSyncService {
  static final _prefsService = NotificationPrefsService();

  /// Reads active plans, routine timelines, and pending database tasks to synchronize
  /// all home screen widget layouts with the actual current state of the application.
  static Future<void> syncWidget() async {
    try {
      final now = DateTime.now();

      // 1. Format today's date representation (e.g. "Tuesday, May 26")
      final todayDateStr = DateFormat('EEEE, MMM d').format(now);

      // 2. Query region-specific holiday override status
      final isHoliday = await _prefsService.checkIsHoliday(now);

      // 3. Count remaining pending tasks directly in SQLite for high performance
      final db = await DatabaseHelper.instance.database;
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM tasks WHERE is_completed = 0',
      );
      final pendingCount = Sqflite.firstIntValue(countResult) ?? 0;

      // Notes list is now fully handled in native SharedPreferences on Android

      // 4. Retrieve and serialize the entire schedule of activities
      String statusText = isHoliday ? "Enjoy your holiday!" : "Stay productive!";
      List<Map<String, dynamic>> scheduleList = [];

      final cachedPlanJson = await _prefsService.getAiDayPlanJson();
      final cachedPlanDate = await _prefsService.getAiDayPlanDate();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      if (cachedPlanJson != null && cachedPlanDate == todayStr) {
        try {
          final List decoded = jsonDecode(cachedPlanJson);
          scheduleList = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (e) {
          debugPrint('[WidgetSync] Error parsing AI day plan for widget: $e');
        }
      }

      // Fallback to baseline routine if no AI plan is generated for today
      if (scheduleList.isEmpty) {
        final routineStr = await _prefsService.getDailyRoutine(date: now);
        try {
          final List decoded = jsonDecode(routineStr);
          scheduleList = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (e) {
          debugPrint('[WidgetSync] Error parsing baseline routine for widget: $e');
        }
      }

      // Check if all scheduled events are finished to update statusText
      bool allFinished = true;
      for (final item in scheduleList) {
        final timeStr = item['time'] as String?;
        if (timeStr != null) {
          final parsed = _parseTimeStr(timeStr, now);
          if (parsed != null && parsed.isAfter(now)) {
            allFinished = false;
            break;
          }
        }
      }
      if (allFinished && scheduleList.isNotEmpty) {
        statusText = "Rest up for tomorrow!";
      }

      // 5. Pre-calculate active task and remaining duration to cache in preferences
      final currentMinutes = now.hour * 60 + now.minute;
      String activeTitle = "No active task";
      int remainingMins = 60;

      for (int i = 0; i < scheduleList.length; i++) {
        final item = scheduleList[i];
        final timeStr = item['time'] as String?;
        if (timeStr != null) {
          final rangeParts = timeStr.split('-');
          if (rangeParts.length >= 2) {
            final start = _parseRawTimeStrToMinutes(rangeParts[0]);
            final end = _parseRawTimeStrToMinutes(rangeParts[1]);
            if (currentMinutes >= start && currentMinutes < end) {
              activeTitle = item['work'] ?? "Study Session";
              remainingMins = end - currentMinutes;
              break;
            }
          }
        }
      }

      // Read current pause state from SharedPreferences
      final isPaused = await HomeWidget.getWidgetData<bool>('is_paused') ?? false;

      // If active (not paused), cache current active task parameters so when paused,
      // it freezing-locks onto these exact values!
      if (!isPaused) {
        await HomeWidget.saveWidgetData<String>('paused_task_title', activeTitle);
        await HomeWidget.saveWidgetData<int>('paused_remaining_minutes', remainingMins);
      }

      // 6. Securely stash parameters into home_widget's native bridge shared settings
      await HomeWidget.saveWidgetData<String>('today_date_str', todayDateStr);
      await HomeWidget.saveWidgetData<int>('pending_task_count', pendingCount);
      await HomeWidget.saveWidgetData<bool>('is_holiday', isHoliday);
      await HomeWidget.saveWidgetData<String>('status_text', statusText);
      await HomeWidget.saveWidgetData<String>('schedule_json', jsonEncode(scheduleList));
      // Widget notes json is now purely managed native-side
      await HomeWidget.saveWidgetData<bool>('is_rescheduling', false);
      await HomeWidget.saveWidgetData<String>('remaining_time_text', "Ends in ${remainingMins}m");

      // 7. Signal the native OS widget host manager to force redraw
      await HomeWidget.updateWidget(
        name: 'ToDoWidgetProvider',
        androidName: 'ToDoWidgetProvider',
      );

      debugPrint('[WidgetSync] Successfully synchronized all home widget schedule cards.');
    } catch (e) {
      debugPrint('[WidgetSync] Core synchronization failed: $e');
    }
  }

  static DateTime? _parseTimeStr(String timeStr, DateTime reference) {
    try {
      final cleaned = timeStr.trim();
      final format = DateFormat('hh:mm a');
      final parsed = format.parse(cleaned);
      return DateTime(
        reference.year,
        reference.month,
        reference.day,
        parsed.hour,
        parsed.minute,
      );
    } catch (_) {
      return null;
    }
  }

  static int _parseRawTimeStrToMinutes(String timeStr) {
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final ampmParts = cleaned.split(' ');
      final hmParts = ampmParts[0].split(':');
      var hour = int.parse(hmParts[0]);
      final minute = int.parse(hmParts[1]);

      final ampm = ampmParts.length > 1 ? ampmParts[1] : (cleaned.contains('PM') ? 'PM' : 'AM');

      if (ampm == 'PM' && hour != 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> runBackgroundReschedule({
    required String action,
    String? pausedAt,
  }) async {
    try {
      final now = DateTime.now();
      final prefsService = NotificationPrefsService();

      if (action == 'pause') {
        // Skip AI reschedule when pausing. Just toggle states and sync widget immediately!
        await HomeWidget.saveWidgetData<bool>('is_paused', true);
        if (pausedAt != null) {
          await HomeWidget.saveWidgetData<String>('paused_at', pausedAt);
        }
        await syncWidget();
        return;
      }

      // If action is 'resume':
      final apiKey = await prefsService.getGeminiApiKey();
      if (apiKey == null || apiKey.trim().isEmpty) {
        await _performLocalResumeFallback();
        return;
      }

      // 1. Get current plan
      final cachedPlanJson = await prefsService.getAiDayPlanJson();
      List<Map<String, dynamic>> currentPlan = [];
      if (cachedPlanJson != null) {
        try {
          final List decoded = jsonDecode(cachedPlanJson);
          currentPlan = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }
      if (currentPlan.isEmpty) {
        final routineStr = await prefsService.getDailyRoutine(date: now);
        try {
          final List decoded = jsonDecode(routineStr);
          currentPlan = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {}
      }

      // 2. Fetch stashed pause details from HomeWidget
      final stashedTitle = await HomeWidget.getWidgetData<String>('paused_task_title') ?? '';
      final stashedMins = await HomeWidget.getWidgetData<int>('paused_remaining_minutes') ?? 60;
      
      String currentTaskTitle = stashedTitle;
      int remainingMinutes = stashedMins;
      
      final currentMinutes = now.hour * 60 + now.minute;
      if (currentTaskTitle.isEmpty) {
        for (final item in currentPlan) {
          final timeStr = item['time'] as String?;
          if (timeStr != null) {
            final rangeParts = timeStr.split('-');
            if (rangeParts.length >= 2) {
              final start = _parseRawTimeStrToMinutes(rangeParts[0]);
              final end = _parseRawTimeStrToMinutes(rangeParts[1]);
              if (currentMinutes >= start && currentMinutes < end) {
                currentTaskTitle = item['work'] ?? 'Study Session';
                remainingMinutes = end - currentMinutes;
                break;
              }
            }
          }
        }
      }
      if (currentTaskTitle.isEmpty) {
        currentTaskTitle = 'Study Session';
      }

      final timeStr = pausedAt ?? DateFormat('hh:mm a').format(now);

      // 3. Query SQLite for active tasks, courses, assignments, and events
      final db = await DatabaseHelper.instance.database;
      final todayStart = DateTime(now.year, now.month, now.day);

      // Courses
      final coursesResult = await db.query('courses', where: 'status = ?', whereArgs: ['Active']);
      final coursesMap = coursesResult.map((c) => {
        'title': c['title'],
        'description': c['description'] ?? '',
      }).toList();

      // Tasks
      final tasksResult = await db.query('tasks', where: 'is_completed = 0');
      final tasksMap = tasksResult.where((t) {
        final dueDateStr = t['due_date'] as String?;
        if (dueDateStr == null) return true;
        final date = DateTime.tryParse(dueDateStr);
        return date == null || !date.isBefore(todayStart);
      }).map((t) => {
        'title': t['title'],
        'description': t['description'] ?? '',
      }).toList();

      // Assignments
      final assignmentsResult = await db.query('assignments', where: 'is_completed = 0');
      final assignmentsMap = assignmentsResult.where((a) {
        final dueDateStr = a['due_date'] as String?;
        if (dueDateStr == null) return true;
        final date = DateTime.tryParse(dueDateStr);
        return date == null || !date.isBefore(todayStart);
      }).map((a) => {
        'title': a['title'],
        'description': a['description'] ?? '',
        'subject': a['subject'] ?? '',
        'type': a['type'] ?? '',
      }).toList();

      // Events / Hackathons
      final eventsResult = await db.query('hackathons');
      final eventsMap = eventsResult.where((e) {
        final compareStr = (e['end_date'] as String?) ?? (e['start_date'] as String?);
        if (compareStr == null) return true;
        final date = DateTime.tryParse(compareStr);
        return date == null || !date.isBefore(todayStart);
      }).map((e) => {
        'name': e['name'],
        'description': e['description'] ?? '',
      }).toList();



      // 4. Run AI Reschedule!
      final rescheduledPlan = await GeminiService.rescheduleRemainingPlan(
        apiKey: apiKey,
        currentPlan: currentPlan,
        currentTaskTitle: currentTaskTitle,
        action: action,
        timeStr: timeStr,
        remainingMinutes: remainingMinutes,
        tasks: tasksMap,
        courses: coursesMap,
        assignments: assignmentsMap,
        events: eventsMap,
      );

      final newPlanJson = jsonEncode(rescheduledPlan);
      final todayDateStr = DateFormat('yyyy-MM-dd').format(now);

      await prefsService.setAiDayPlanJson(newPlanJson);
      await prefsService.setAiDayPlanDate(todayDateStr);
      await prefsService.setAiDayPlanTimestamp(now.millisecondsSinceEpoch.toString());

      // 5. Force update the widget!
      await syncWidget();
    } catch (e) {
      debugPrint('[WidgetSync] Background AI Reschedule failed: $e');
      try {
        await _performLocalResumeFallback();
      } catch (err) {
        debugPrint('[WidgetSync] Fallback failed: $err');
        await HomeWidget.saveWidgetData<bool>('is_paused', false);
        await HomeWidget.saveWidgetData<bool>('is_rescheduling', false);
        await syncWidget();
      }
    }
  }

  static Future<void> _performLocalResumeFallback() async {
    await HomeWidget.saveWidgetData<bool>('is_paused', false);
    await HomeWidget.saveWidgetData<bool>('is_rescheduling', false);
    await syncWidget();
  }
}

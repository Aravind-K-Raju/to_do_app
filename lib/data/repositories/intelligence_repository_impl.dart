import '../../domain/entities/assignment.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/daily_stats.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/entities/insights_data.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/intelligence_repository.dart';
import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/search_result.dart';

class IntelligenceRepositoryImpl implements IntelligenceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<DailyStats> getDailyStats(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split(
      'T',
    )[0]; // simple YYYY-MM-DD for MVP regex/filtering

    // 1. Calculate Study Minutes for Date
    // 'study_sessions' table is deprecated/removed.

    int totalMinutes = 0;

    // 2. Count Completed Tasks updated/completed today?
    // MVP: Completed tasks count (generic) or tasks due today?
    // Let's count tasks created/due today for simplicity or tasks checking 'is_completed' status.
    // Ideally we need a 'completed_at' timestamp. MVP schema doesn't have it.
    // PROXY: Tasks due today that are completed vs pending.
    final tasks = await db.query(
      'tasks',
      where: "due_date LIKE ?",
      whereArgs: ['$dateStr%'],
    );

    int completed = 0;
    int pending = 0;
    for (var t in tasks) {
      if ((t['is_completed'] as int) == 1) {
        completed++;
      } else {
        pending++;
      }
    }

    // 3. Simple Productivity Score Logic
    // Score = (Completed / (Completed + Pending)) * 50 + (StudyMinutes / 60) * 10
    // Capped at 100.
    double score = 0;
    int totalTasks = completed + pending;
    if (totalTasks > 0) {
      score += (completed / totalTasks) * 50;
    }
    score += (totalMinutes / 60) * 20; // 20 points per hour
    if (score > 100) score = 100;

    return DailyStats(
      date: date,
      tasksCompleted: completed,
      tasksPending: pending,
      studyMinutes: totalMinutes,
      productivityScore: score,
    );
  }

  @override
  Future<InsightsData> getInsightsData() async {
    final db = await _dbHelper.database;

    // --- Courses ---
    final totalCourses =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM courses'),
        ) ??
        0;
    final completedCourses =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM courses WHERE status = 'Completed'",
          ),
        ) ??
        0;

    final activeCoursesData = await db.query(
      'courses',
      where: "status != 'Completed'",
    );
    final activeCourses = activeCoursesData.map((map) {
      return Course(
        id: map['id'] as int,
        title: map['title'] as String,
        description: map['description'] as String?,
        sourceName:
            map['source_name'] as String? ??
            map['platform'] as String? ??
            'Unknown',
        startDate: DateTime.parse(map['start_date'] as String),
        status: map['status'] as String,
        progressPercent: (map['progress_percent'] as num).toDouble(),
        completionDate: null, // Active
        type: _parseCourseType(map['type'] as String? ?? 'site'),
        channelName: map['channel_name'] as String?,
        loginMail: map['login_mail'] as String?,
        links: [],
        timeline: [],
      );
    }).toList();

    // --- Tasks ---
    final totalTasks =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tasks'),
        ) ??
        0;
    final completedTasks =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM tasks WHERE is_completed = 1',
          ),
        ) ??
        0;

    final pendingTasksData = await db.query('tasks', where: 'is_completed = 0');
    final pendingTasks = pendingTasksData.map((map) {
      DateTime? dueDate;
      if (map['due_date'] != null) {
        dueDate = DateTime.tryParse(map['due_date'] as String);
      }
      return Task(
        id: map['id'] as int,
        title: map['title'] as String,
        description: map['description'] as String?,
        isCompleted: false,
        courseId: map['course_id'] as int?,
        dueDate: dueDate,
      );
    }).toList();

    // --- Assignments ---
    final totalAssignments =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM assignments'),
        ) ??
        0;
    final completedAssignments =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM assignments WHERE is_completed = 1',
          ),
        ) ??
        0;

    final pendingAssignmentsData = await db.query(
      'assignments',
      where: 'is_completed = 0',
      orderBy: 'due_date ASC',
    );
    final pendingAssignments = pendingAssignmentsData.map((map) {
      return Assignment(
        id: map['id'] as int,
        title: map['title'] as String,
        description: map['description'] as String?,
        subject: map['subject'] as String?,
        type: map['type'] as String,
        dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
        submissionDate: null,
        isCompleted: false,
      );
    }).toList();

    // --- Events (Hackathons) ---
    // Fetch all for events as date logic is complex in SQLite text fields and dataset is likely small
    final eventMaps = await _dbHelper.getAllHackathons();
    int totalEvents = eventMaps.length;
    int completedEvents = 0;
    List<Hackathon> upcomingEvents = [];
    final now = DateTime.now();

    for (var map in eventMaps) {
      String? endDateStr = map['end_date'] as String?;
      DateTime? endDate;
      if (endDateStr != null && endDateStr.isNotEmpty) {
        endDate = DateTime.tryParse(endDateStr);
      } else {
        endDate = DateTime.tryParse(map['start_date'] as String);
      }

      bool isPast = endDate != null && endDate.isBefore(now);
      if (isPast) {
        completedEvents++;
      } else {
        upcomingEvents.add(
          Hackathon(
            id: map['id'] as int,
            name: map['name'] as String,
            theme: map['theme'] as String?,
            description: map['description'] as String?,
            startDate: DateTime.parse(map['start_date'] as String),
            endDate: endDateStr != null ? DateTime.tryParse(endDateStr) : null,
            teamSize: map['team_size'] as int?,
            techStack: map['tech_stack'] as String?,
            outcome: map['outcome'] as String?,
            projectLink: map['project_link'] as String?,
            loginMail: map['login_mail'] as String?,
            links: [],
            timeline: [],
          ),
        );
      }
    }

    // --- Filter Pending Items (Not completed AND due date not passed) ---
    // --- Filter Pending Items (Not completed AND due date not passed) ---
    // 'now' is already defined at line 178
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    // dayAfterTomorrowStart unused

    bool isSameDay(DateTime? date, DateTime target) {
      if (date == null) return false;
      return date.year == target.year &&
          date.month == target.month &&
          date.day == target.day;
    }

    bool isFutureOrToday(DateTime? date) {
      if (date == null) return true; // No deadline = pending/active
      return date.isAfter(now) || isSameDay(date, now);
    }

    // Filter lists for "Active/Pending" calculation
    final validPendingTasks = pendingTasks
        .where((t) => isFutureOrToday(t.dueDate))
        .toList();
    final validPendingAssignments = pendingAssignments
        .where((a) => isFutureOrToday(a.dueDate))
        .toList();
    // upcomingEvents are already checked for !isPast in the loop above
    // activeCourses are active by status, assuming they are valid

    // --- Score Calculation (New Logic) ---
    // Total Completed = Sum of all completed items
    int totalCompleted =
        completedCourses +
        completedTasks +
        completedAssignments +
        completedEvents;

    // Total Pending/Active = Sum of all items not completed AND due date not passed
    int totalPendingActive =
        activeCourses.length +
        validPendingTasks.length +
        validPendingAssignments.length +
        upcomingEvents.length;

    // Display Ratio NOT percentage, but we need to pass data to UI
    // The UI 'overallScore' field is a double. The user wants to SHOW the ratio.
    // But the previous UI used this score for the circular indicator value (0.0 - 100.0).
    // Let's set the score value to be consumed by the CircularProgressIndicator.
    // If we want to show text "15 / 20", we might need to change the UI to use the raw numbers
    // or pass them via the score.
    // Wait, the data model has `overallScore` as double.
    // I can stick to packing count info or just calculating a progress 0-100 for the circle
    // and letting the UI calculate the text from the individual counts?
    // User said: "New Logic: The text inside the circular score should now display a direct ratio: [Total Completed] / [Total Pending/Active]."
    // The UI built-in `_buildProductivityScore` used `score.toStringAsFixed(0)`.
    // I should probably calculate the percentage for the *visual* circle,
    // but I need to make the *text* values available.
    // The `InsightsData` has all the counts in it!
    // I can calculate `Total Completed` and `Total Pending` in the UI from the `InsightsData` fields.
    // So for `overallScore`, I will return the PERCENTAGE (0-100) so the circle draws correctly.

    double overallScore = 0.0;
    if ((totalCompleted + totalPendingActive) > 0) {
      overallScore =
          (totalCompleted / (totalCompleted + totalPendingActive)) * 100;
    }

    // --- Agenda Items from Scheduled Notifications ---
    // User requested to use the notification table for Timeline results.
    // This ensures consistency with what the user sees in search/notifications.

    Future<List<AgendaItem>> fetchMergedAgenda(DateTime date) async {
      final dateStr = date.toIso8601String().split('T')[0];
      final startOfDayMs = DateTime(
        date.year,
        date.month,
        date.day,
      ).millisecondsSinceEpoch;
      final endOfDayMs = DateTime(
        date.year,
        date.month,
        date.day + 1,
      ).millisecondsSinceEpoch;

      // 1. Fetch Tasks (TEXT Date) - Exclude Completed
      final taskRows = await db.query(
        'tasks',
        where: 'due_date LIKE ? AND is_completed = 0',
        whereArgs: ['$dateStr%'],
        orderBy: 'due_date ASC',
      );
      final tasks = taskRows.map((row) {
        DateTime? time;
        if (row['due_date'] != null) {
          time = DateTime.tryParse(row['due_date'] as String);
          // If time is 00:00 (default), hide it by setting to null
          if (time != null && time.hour == 0 && time.minute == 0) {
            time = null;
          }
        }
        return AgendaItem(
          id: row['id'] as int,
          title: row['title'] as String,
          subtitle: row['description'] as String? ?? 'Task',
          time: time,
          type: 'Task',
          isCompleted: false,
        );
      }).toList();

      // 2. Fetch Assignments (INTEGER Date) - Exclude Completed
      final assignmentRows = await db.query(
        'assignments',
        where: 'due_date >= ? AND due_date < ? AND is_completed = 0',
        whereArgs: [startOfDayMs, endOfDayMs],
      );
      final assignments = assignmentRows.map((row) {
        return AgendaItem(
          id: row['id'] as int,
          title: row['title'] as String,
          subtitle: '${row['subject'] ?? ''} - ${row['type']}',
          time: DateTime.fromMillisecondsSinceEpoch(row['due_date'] as int),
          type: 'Assignment',
          isCompleted: false,
        );
      }).toList();

      // ... rest of fetchAgenda logic (Courses/Events) ...
      // (Assuming Courses/Events start/timeline logic doesn't have 'is_completed' field or it's 'status')
      // For Courses: isCompleted: row['status'] == 'Completed'
      // We might want to Filter them too if status='Completed'?
      // User said: "mark completed for assignments also it should be hidded"
      // I will leave Courses/Events as is for now unless they have explicit 'is_completed' 0/1.
      // Courses have 'status'. Events might not.

      // 3. Fetch Courses (Start Date & Timeline)
      final courses = <AgendaItem>[];
      // A. Start Date
      final courseStartRows = await db.query(
        'courses',
        where: 'start_date LIKE ? AND status != ?',
        whereArgs: ['$dateStr%', 'Completed'], // Filter completed courses?
      );
      for (var row in courseStartRows) {
        courses.add(
          AgendaItem(
            id: row['id'] as int,
            title: row['title'] as String,
            subtitle: 'Course Starts',
            time: DateTime.tryParse(row['start_date'] as String),
            type: 'Course',
            isCompleted: false,
          ),
        );
      }
      // B. Timeline Entries
      final courseTimelineRows = await db.rawQuery(
        '''
        SELECT cd.*, c.title as course_title 
        FROM course_dates cd 
        JOIN courses c ON cd.course_id = c.id 
        WHERE cd.date_val LIKE ? AND c.status != 'Completed'
      ''',
        ['$dateStr%'],
      );
      for (var row in courseTimelineRows) {
        courses.add(
          AgendaItem(
            id: row['course_id'] as int,
            title: row['course_title'] as String,
            subtitle: 'Timeline: ${row['description']}',
            time: DateTime.tryParse(row['date_val'] as String),
            type: 'Course',
            isCompleted: false,
          ),
        );
      }

      // 4. Fetch Events (Start Date & Timeline)
      // (Hackathons don't seem to have is_completed column in schema based on previous usage, maybe?)
      // I will keep them as is.
      final events = <AgendaItem>[];
      // A. Start Date
      final eventStartRows = await db.query(
        'hackathons',
        where: 'start_date LIKE ?',
        whereArgs: ['$dateStr%'],
      );
      for (var row in eventStartRows) {
        events.add(
          AgendaItem(
            id: row['id'] as int,
            title: row['name'] as String,
            subtitle: 'Event Starts',
            time: DateTime.tryParse(row['start_date'] as String),
            type: 'Event',
            isCompleted: false,
          ),
        );
      }
      // B. Timeline Entries
      final eventTimelineRows = await db.rawQuery(
        '''
        SELECT hd.*, h.name as event_name 
        FROM hackathon_dates hd 
        JOIN hackathons h ON hd.hackathon_id = h.id 
        WHERE hd.date_val LIKE ?
      ''',
        ['$dateStr%'],
      );
      for (var row in eventTimelineRows) {
        events.add(
          AgendaItem(
            id: row['hackathon_id'] as int,
            title: row['event_name'] as String,
            subtitle: 'Timeline: ${row['description']}',
            time: DateTime.tryParse(row['date_val'] as String),
            type: 'Event',
            isCompleted: false,
          ),
        );
      }

      // ... rest of merge logic ...
      // I need to use replace_file_content carefully to cover the changes.
      // I will target the specific blocks in separate chunks if possible or one big chunk.
      // Actually, I'll update the whole `fetchMergedAgenda` body I can see.

      // 5. Merge and Sort (Strict Date Mode: No Notifications)
      final merged = [...tasks, ...assignments, ...events, ...courses];

      // Final Sort: Type Priority -> Time
      int getTypePriority(String type) {
        switch (type) {
          case 'Task':
            return 0;
          case 'Assignment':
            return 1;
          case 'Event':
            return 2;
          case 'Course':
            return 3;
          default:
            return 4;
        }
      }

      merged.sort((a, b) {
        int priorityA = getTypePriority(a.type);
        int priorityB = getTypePriority(b.type);
        if (priorityA != priorityB) {
          return priorityA.compareTo(priorityB);
        }
        if (a.time == null) return -1;
        if (b.time == null) return 1;
        return a.time!.compareTo(b.time!);
      });
      return merged;
    }

    // ... search method update below ...

    List<AgendaItem> agendaToday = await fetchMergedAgenda(todayStart);
    List<AgendaItem> agendaTomorrow = await fetchMergedAgenda(tomorrowStart);

    return InsightsData(
      totalCourses: totalCourses,
      completedCourses: completedCourses,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      totalAssignments: totalAssignments,
      completedAssignments: completedAssignments,
      totalEvents:
          totalEvents, // Fixed typo from 'totalEvents' to correct variable if needed, but 'totalEvents' is correct
      completedEvents: completedEvents,
      overallScore: overallScore,
      activeCourses: activeCourses,
      pendingTasks: pendingTasks,
      pendingAssignments: pendingAssignments,
      upcomingEvents: upcomingEvents,
      agendaToday: agendaToday,
      agendaTomorrow: agendaTomorrow,
    );
  }

  CourseType _parseCourseType(String typeStr) {
    try {
      return CourseType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => CourseType.site,
      );
    } catch (_) {
      return CourseType.site;
    }
  }

  @override
  Future<List<SearchResult>> search(
    String query, {
    DateTime? date,
    String? type,
  }) async {
    final db = await _dbHelper.database;
    final List<SearchResult> results = [];

    // Helper to check date match
    bool isDateMatch(DateTime? itemDate) {
      if (date == null) return true;
      if (itemDate == null) return false;
      return itemDate.year == date.year &&
          itemDate.month == date.month &&
          itemDate.day == date.day;
    }

    // 1. Search Courses
    if (type == null || type == 'Course') {
      final courseRows = await db.query(
        'courses',
        where: 'title LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
      for (var row in courseRows) {
        final itemDate = DateTime.tryParse(row['start_date'] as String);
        if (isDateMatch(itemDate)) {
          results.add(
            SearchResult(
              id: (row['id'] as int).toString(),
              title: row['title'] as String,
              subtitle: row['description'] as String? ?? 'Course',
              type: 'Course',
              date: itemDate,
            ),
          );
        }
      }
    }

    // 2. Search Tasks
    if (type == null || type == 'Task') {
      final taskRows = await db.query(
        'tasks',
        where: 'title LIKE ? OR description LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
      for (var row in taskRows) {
        DateTime? itemDate;
        if (row['due_date'] != null) {
          itemDate = DateTime.tryParse(row['due_date'] as String);
        }
        if (isDateMatch(itemDate)) {
          results.add(
            SearchResult(
              id: (row['id'] as int).toString(),
              title: row['title'] as String,
              subtitle: row['description'] as String? ?? 'Task',
              type: 'Task',
              date: itemDate,
            ),
          );
        }
      }
    }

    // 3. Search Assignments
    if (type == null || type == 'Assignment') {
      final assignmentRows = await db.query(
        'assignments',
        where: 'title LIKE ? OR subject LIKE ? OR type LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
      );
      for (var row in assignmentRows) {
        DateTime? itemDate;
        if (row['due_date'] != null) {
          itemDate = DateTime.fromMillisecondsSinceEpoch(
            row['due_date'] as int,
          );
        }
        if (isDateMatch(itemDate)) {
          results.add(
            SearchResult(
              id: (row['id'] as int).toString(),
              title: row['title'] as String,
              subtitle: '${row['subject'] ?? ''} - ${row['type']}',
              type: 'Assignment',
              date: itemDate,
            ),
          );
        }
      }
    }

    // 4. Search Events (Hackathons)
    if (type == null || type == 'Event') {
      final eventRows = await db.query(
        'hackathons',
        where: 'name LIKE ? OR description LIKE ? OR theme LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
      );
      for (var row in eventRows) {
        final itemDate = DateTime.tryParse(row['start_date'] as String);
        if (isDateMatch(itemDate)) {
          results.add(
            SearchResult(
              id: (row['id'] as int).toString(),
              title: row['name'] as String,
              subtitle: row['description'] as String? ?? 'Event',
              type: 'Event',
              date: itemDate,
            ),
          );
        }
      }
      // NEW: Search Event Timeline
      final eventTimelineRows = await db.rawQuery(
        '''
        SELECT hd.*, h.name as event_name 
        FROM hackathon_dates hd 
        JOIN hackathons h ON hd.hackathon_id = h.id 
        WHERE h.name LIKE ? OR hd.description LIKE ?
      ''',
        ['%$query%', '%$query%'],
      );
      for (var row in eventTimelineRows) {
        final itemDate = DateTime.tryParse(row['date_val'] as String);
        if (isDateMatch(itemDate)) {
          results.add(
            SearchResult(
              id: (row['hackathon_id'] as int).toString(),
              title: row['event_name'] as String,
              subtitle: 'Timeline: ${row['description']}',
              type: 'Event',
              date: itemDate,
            ),
          );
        }
      }
    }

    // 5. Search Course Timeline (if type is Course or null)
    if (type == null || type == 'Course') {
      final courseTimelineRows = await db.rawQuery(
        '''
        SELECT cd.*, c.title as course_title 
        FROM course_dates cd 
        JOIN courses c ON cd.course_id = c.id 
        WHERE c.title LIKE ? OR cd.description LIKE ?
      ''',
        ['%$query%', '%$query%'],
      );
      for (var row in courseTimelineRows) {
        final itemDate = DateTime.tryParse(row['date_val'] as String);
        if (isDateMatch(itemDate)) {
          results.add(
            SearchResult(
              id: (row['course_id'] as int).toString(),
              title: row['course_title'] as String,
              subtitle: 'Timeline: ${row['description']}',
              type: 'Course',
              date: itemDate,
            ),
          );
        }
      }
    }

    return results;
  }
}

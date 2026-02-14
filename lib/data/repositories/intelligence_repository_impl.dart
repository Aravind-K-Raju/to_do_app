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

    // --- Agenda Items ---
    List<AgendaItem> agendaToday = [];
    List<AgendaItem> agendaTomorrow = [];

    void addToAgenda(
      dynamic item,
      DateTime? date,
      String type,
      List<AgendaItem> list,
    ) {
      list.add(
        AgendaItem(
          id: item.id is int ? item.id : int.tryParse(item.id.toString()) ?? 0,
          title: item is Task
              ? item.title
              : item is Assignment
              ? item.title
              : item is Hackathon
              ? item.name
              : '',
          subtitle: item is Task
              ? (item.description ?? 'Task')
              : item is Assignment
              ? '${item.subject ?? "Assignment"} • ${item.type}'
              : item is Hackathon
              ? (item.theme ?? 'Hackathon')
              : '',
          time: date,
          type: type,
          isCompleted: false,
        ),
      );
    }

    // Tasks
    for (var t in validPendingTasks) {
      if (isSameDay(t.dueDate, todayStart)) {
        addToAgenda(t, t.dueDate, 'Task', agendaToday);
      } else if (isSameDay(t.dueDate, tomorrowStart)) {
        addToAgenda(t, t.dueDate, 'Task', agendaTomorrow);
      }
    }

    // Assignments
    for (var a in validPendingAssignments) {
      if (isSameDay(a.dueDate, todayStart)) {
        addToAgenda(a, a.dueDate, 'Assignment', agendaToday);
      } else if (isSameDay(a.dueDate, tomorrowStart)) {
        addToAgenda(a, a.dueDate, 'Assignment', agendaTomorrow);
      }
    }

    // Events
    for (var e in upcomingEvents) {
      // For events, checking start date
      if (isSameDay(e.startDate, todayStart)) {
        addToAgenda(e, e.startDate, 'Event', agendaToday);
      } else if (isSameDay(e.startDate, tomorrowStart)) {
        addToAgenda(e, e.startDate, 'Event', agendaTomorrow);
      }
    }

    return InsightsData(
      totalCourses: totalCourses,
      completedCourses: completedCourses,
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      totalAssignments: totalAssignments,
      completedAssignments: completedAssignments,
      totalEvents: totalEvents,
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
  Future<List<SearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final db = await _dbHelper.database;
    final List<SearchResult> results = [];
    final String likeQuery = '%$query%';

    // 1. Search Tasks
    final tasks = await db.query(
      'tasks',
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: [likeQuery, likeQuery],
    );
    results.addAll(
      tasks.map(
        (t) => SearchResult(
          id: t['id'].toString(),
          title: t['title'] as String,
          subtitle: t['description'] as String? ?? 'Task',
          type: 'Task',
          date: t['due_date'] != null
              ? DateTime.tryParse(t['due_date'] as String)
              : null,
          payload: t,
        ),
      ),
    );

    // 2. Search Assignments
    final assignments = await db.query(
      'assignments',
      where: 'title LIKE ? OR subject LIKE ? OR description LIKE ?',
      whereArgs: [likeQuery, likeQuery, likeQuery],
    );
    results.addAll(
      assignments.map(
        (a) => SearchResult(
          id: a['id'].toString(),
          title: a['title'] as String,
          subtitle: '${a['subject'] ?? "Assignment"} - ${a['type']}',
          type: 'Assignment',
          date: DateTime.fromMillisecondsSinceEpoch(a['due_date'] as int),
          payload: a,
        ),
      ),
    );

    // 3. Search Courses
    final courses = await db.query(
      'courses',
      where: 'title LIKE ? OR description LIKE ? OR platform LIKE ?',
      whereArgs: [likeQuery, likeQuery, likeQuery],
    );
    results.addAll(
      courses.map(
        (c) => SearchResult(
          id: c['id'].toString(),
          title: c['title'] as String,
          subtitle: c['platform'] as String? ?? 'Course',
          type: 'Course',
          date: DateTime.parse(c['start_date'] as String),
          payload: c,
        ),
      ),
    );

    // 4. Search Events (Hackathons)
    try {
      final events = await db.query(
        'hackathons',
        where: 'name LIKE ? OR theme LIKE ? OR description LIKE ?',
        whereArgs: [likeQuery, likeQuery, likeQuery],
      );
      results.addAll(
        events.map(
          (e) => SearchResult(
            id: e['id'].toString(),
            title: e['name'] as String,
            subtitle: e['theme'] as String? ?? 'Hackathon',
            type: 'Event',
            date: DateTime.tryParse(e['start_date'] as String),
            payload: e,
          ),
        ),
      );
    } catch (e) {
      // Table might not exist or be named differently, ignore for MVP or log
    }

    return results;
  }
}

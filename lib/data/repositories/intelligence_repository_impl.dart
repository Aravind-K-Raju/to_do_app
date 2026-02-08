import '../../domain/entities/assignment.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/daily_stats.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/entities/insights_data.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/intelligence_repository.dart';
import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

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
    // TODO: Implement new way to track study time if needed.
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

    // --- Score Calculation ---
    double getRate(int comp, int total) => total == 0 ? 0.0 : comp / total;

    double courseRate = getRate(completedCourses, totalCourses);
    double assignRate = getRate(completedAssignments, totalAssignments);
    double eventRate = getRate(completedEvents, totalEvents);
    double taskRate = getRate(completedTasks, totalTasks);

    double overallScore =
        (courseRate * 40) +
        (assignRate * 20) +
        (eventRate * 20) +
        (taskRate * 20);

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
}

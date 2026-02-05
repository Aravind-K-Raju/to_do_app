import '../../domain/entities/daily_stats.dart';
import '../../domain/repositories/intelligence_repository.dart';
import '../database/database_helper.dart';

class IntelligenceRepositoryImpl implements IntelligenceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<DailyStats> getDailyStats(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split(
      'T',
    )[0]; // simple YYYY-MM-DD for MVP regex/filtering

    // 1. Calculate Study Minutes for Date
    // Current DB stores generic 'start_time' string. SQLite string comparison for date part:
    // "start_time LIKE '2023-10-10%'"
    final sessions = await db.query(
      'study_sessions',
      where: "start_time LIKE ?",
      whereArgs: ['$dateStr%'],
    );
    int totalMinutes = 0;
    for (var s in sessions) {
      totalMinutes += (s['duration_minutes'] as int);
    }

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
}

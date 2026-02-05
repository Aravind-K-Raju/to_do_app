import '../../domain/entities/study_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../database/database_helper.dart';

class SessionRepositoryImpl implements SessionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<StudySession>> getSessions(int courseId) async {
    final result = await _dbHelper.getSessionsForCourse(courseId);
    return result.map((map) => _fromMap(map)).toList();
  }

  @override
  Future<int> startSession(StudySession session) async {
    return await _dbHelper.startSession(_toMap(session));
  }

  // Mapper methods
  StudySession _fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'],
      courseId: map['course_id'],
      startTime: DateTime.parse(map['start_time']),
      durationMinutes: map['duration_minutes'],
    );
  }

  Map<String, dynamic> _toMap(StudySession session) {
    return {
      'id': session.id,
      'course_id': session.courseId,
      'start_time': session.startTime.toIso8601String(),
      'duration_minutes': session.durationMinutes,
    };
  }
}

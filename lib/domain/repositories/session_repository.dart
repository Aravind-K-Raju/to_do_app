import '../entities/study_session.dart';

abstract class SessionRepository {
  Future<List<StudySession>> getSessions(int courseId);
  Future<int> startSession(StudySession session);
}

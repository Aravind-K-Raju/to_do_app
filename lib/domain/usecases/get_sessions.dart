import '../entities/study_session.dart';
import '../repositories/session_repository.dart';

class GetSessions {
  final SessionRepository repository;

  GetSessions(this.repository);

  Future<List<StudySession>> call(int courseId) async {
    return await repository.getSessions(courseId);
  }
}

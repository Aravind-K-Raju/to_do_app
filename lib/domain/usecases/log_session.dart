import '../entities/study_session.dart';
import '../repositories/session_repository.dart';

class LogSession {
  final SessionRepository repository;

  LogSession(this.repository);

  Future<int> call(StudySession session) async {
    return await repository.startSession(session);
  }
}

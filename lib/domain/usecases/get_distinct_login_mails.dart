import '../repositories/course_repository.dart';

class GetDistinctLoginMails {
  final CourseRepository repository;

  GetDistinctLoginMails(this.repository);

  Future<List<String>> call() async {
    return await repository.getDistinctLoginMails();
  }
}

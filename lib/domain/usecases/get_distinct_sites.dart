import '../repositories/course_repository.dart';

class GetDistinctSites {
  final CourseRepository repository;

  GetDistinctSites(this.repository);

  Future<List<String>> call() async {
    return await repository.getDistinctSites();
  }
}

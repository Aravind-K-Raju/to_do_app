import '../repositories/course_repository.dart';

class DeleteCourse {
  final CourseRepository repository;

  DeleteCourse(this.repository);

  Future<int> call(int id) async {
    return await repository.deleteCourse(id);
  }
}

import '../entities/course.dart';
import '../repositories/course_repository.dart';

class CreateCourse {
  final CourseRepository repository;

  CreateCourse(this.repository);

  Future<int> call(Course course) async {
    return await repository.createCourse(course);
  }
}

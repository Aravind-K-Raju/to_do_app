import '../entities/course.dart';
import '../repositories/course_repository.dart';

class UpdateCourse {
  final CourseRepository repository;

  UpdateCourse(this.repository);

  Future<int> call(Course course) async {
    return await repository.updateCourse(course);
  }
}

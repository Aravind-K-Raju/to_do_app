import '../entities/course.dart';

abstract class CourseRepository {
  Future<List<Course>> getCourses();
  Future<Course?> getCourse(int id);
  Future<int> createCourse(Course course);
  Future<int> updateCourse(Course course);
  Future<int> deleteCourse(int id);
  Future<List<String>> getDistinctSites();
  Future<List<String>> getDistinctLoginMails();
}

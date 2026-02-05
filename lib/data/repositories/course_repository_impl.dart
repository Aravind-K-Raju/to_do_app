import '../../domain/entities/course.dart';
import '../../domain/repositories/course_repository.dart';
import '../database/database_helper.dart';

class CourseRepositoryImpl implements CourseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Course>> getCourses() async {
    final result = await _dbHelper.getAllCourses();
    return result.map((map) => _fromMap(map)).toList();
  }

  @override
  Future<Course?> getCourse(int id) async {
    final result = await _dbHelper.getCourse(id);
    if (result != null) {
      return _fromMap(result);
    }
    return null;
  }

  @override
  Future<int> createCourse(Course course) async {
    return await _dbHelper.createCourse(_toMap(course));
  }

  @override
  Future<int> updateCourse(Course course) async {
    return await _dbHelper.updateCourse(_toMap(course));
  }

  @override
  Future<int> deleteCourse(int id) async {
    return await _dbHelper.deleteCourse(id);
  }

  // Mapper methods
  Course _fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      platform: map['platform'],
      startDate: DateTime.parse(map['start_date']),
      completionDate: map['completion_date'] != null
          ? DateTime.parse(map['completion_date'])
          : null,
      progressPercent: map['progress_percent'],
      status: map['status'],
    );
  }

  Map<String, dynamic> _toMap(Course course) {
    return {
      'id': course.id,
      'title': course.title,
      'description': course.description,
      'platform': course.platform,
      'start_date': course.startDate.toIso8601String(),
      'completion_date': course.completionDate?.toIso8601String(),
      'progress_percent': course.progressPercent,
      'status': course.status,
    };
  }
}

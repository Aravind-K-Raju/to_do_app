import 'package:flutter/material.dart';
import '../../domain/entities/course.dart';
import '../../domain/usecases/get_courses.dart';
import '../../domain/usecases/create_course.dart';
import '../../domain/usecases/update_course.dart';
import '../../domain/usecases/delete_course.dart';

class CourseProvider extends ChangeNotifier {
  final GetCourses getCourses;
  final CreateCourse createCourse;
  final UpdateCourse updateCourse;
  final DeleteCourse deleteCourse;

  CourseProvider({
    required this.getCourses,
    required this.createCourse,
    required this.updateCourse,
    required this.deleteCourse,
  });

  List<Course> _courses = [];
  List<Course> get courses => _courses;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();
    try {
      _courses = await getCourses();
    } catch (e) {
      // Handle error gracefully
      debugPrint('Error loading courses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCourse(Course course) async {
    await createCourse(course);
    await loadCourses();
  }

  Future<void> editCourse(Course course) async {
    await updateCourse(course);
    await loadCourses();
  }

  Future<void> removeCourse(int id) async {
    await deleteCourse(id);
    await loadCourses();
  }
}

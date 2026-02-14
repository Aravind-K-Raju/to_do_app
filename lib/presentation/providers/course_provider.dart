import 'package:flutter/material.dart';
import '../../domain/entities/course.dart';
import '../../domain/usecases/get_courses.dart';
import '../../domain/usecases/create_course.dart';
import '../../domain/usecases/update_course.dart';
import '../../domain/usecases/delete_course.dart';
import '../../domain/usecases/get_distinct_sites.dart';
import '../../domain/usecases/get_distinct_login_mails.dart';
import '../../core/services/notification_scheduler.dart';

class CourseProvider extends ChangeNotifier {
  final GetCourses getCourses;
  final CreateCourse createCourse;
  final UpdateCourse updateCourse;
  final DeleteCourse deleteCourse;
  final GetDistinctSites getDistinctSites;
  final GetDistinctLoginMails getDistinctLoginMails;

  CourseProvider({
    required this.getCourses,
    required this.createCourse,
    required this.updateCourse,
    required this.deleteCourse,
    required this.getDistinctSites,
    required this.getDistinctLoginMails,
  });

  List<Course> _courses = [];
  List<Course> get courses => _courses;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<String> _distinctSites = [];
  List<String> get distinctSites => _distinctSites;

  List<String> _distinctLoginMails = [];
  List<String> get distinctLoginMails => _distinctLoginMails;

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        getCourses(),
        getDistinctSites(),
        getDistinctLoginMails(),
      ]);

      _courses = results[0] as List<Course>;
      _distinctSites = results[1] as List<String>;
      _distinctLoginMails = results[2] as List<String>;
    } catch (e) {
      debugPrint('Error loading courses data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDistinctSites() async {
    try {
      _distinctSites = await getDistinctSites();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading distinct sites: $e');
    }
  }

  Future<void> loadDistinctLoginMails() async {
    try {
      _distinctLoginMails = await getDistinctLoginMails();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading distinct login mails: $e');
    }
  }

  Future<void> addCourse(Course course) async {
    await createCourse(course);
    await loadCourses();
    final created = _courses.where((c) => c.title == course.title).lastOrNull;
    if (created?.id != null) {
      await NotificationScheduler.scheduleForCourse(
        courseId: created!.id!,
        title: course.title,
        startDate: course.startDate,
        timeline: course.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }
  }

  Future<void> editCourse(Course course) async {
    if (course.id != null) {
      // 1. Cancel OS alarms for old rows
      // 2. Delete old DB rows
      await NotificationScheduler.cancelForItem('course_id', course.id!);
    }
    await updateCourse(course);
    await loadCourses();
    if (course.id != null) {
      // 3. Insert new rows + schedule OS
      await NotificationScheduler.scheduleForCourse(
        courseId: course.id!,
        title: course.title,
        startDate: course.startDate,
        timeline: course.timeline
            .map((e) => {'date': e.date, 'description': e.description})
            .toList(),
      );
    }
  }

  Future<void> removeCourse(int id) async {
    // 1. Query IDs → Cancel OS → Delete DB rows
    await NotificationScheduler.cancelForItem('course_id', id);
    // 2. Delete parent (CASCADE would also clean DB rows)
    await deleteCourse(id);
    await loadCourses();
  }
}

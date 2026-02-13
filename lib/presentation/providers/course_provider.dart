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

  Future<void> _scheduleCourseNotifications(Course course) async {
    final id = course.id;
    if (id == null) return;

    // Schedule for start date
    await NotificationScheduler.scheduleForItem(
      baseId: id,
      title: course.title,
      body: 'Course starts!',
      dueDate: course.startDate,
      type: 'Course',
    );

    // Schedule for each timeline entry
    for (int i = 0; i < course.timeline.length; i++) {
      final entry = course.timeline[i];
      await NotificationScheduler.scheduleForItem(
        baseId: id * 1000 + i + 1, // Unique ID per timeline entry
        title: course.title,
        body: 'Timeline: ${entry.description}',
        dueDate: entry.date,
        type: 'Course',
      );
    }
  }

  Future<void> _cancelCourseNotifications(int id) async {
    // Cancel start date notifications
    await NotificationScheduler.cancelForItem(id);
    // Cancel timeline notifications (up to 20 entries)
    for (int i = 0; i < 20; i++) {
      await NotificationScheduler.cancelForItem(id * 1000 + i + 1);
    }
  }

  Future<void> addCourse(Course course) async {
    await createCourse(course);
    await loadCourses();
    final created = _courses.where((c) => c.title == course.title).lastOrNull;
    if (created != null) {
      await _scheduleCourseNotifications(created);
    }
  }

  Future<void> editCourse(Course course) async {
    await updateCourse(course);
    await loadCourses();
    await _cancelCourseNotifications(course.id!);
    await _scheduleCourseNotifications(course);
  }

  Future<void> removeCourse(int id) async {
    await _cancelCourseNotifications(id);
    await deleteCourse(id);
    await loadCourses();
  }
}

import '../../domain/entities/course.dart';
import '../../domain/entities/course_link.dart';
import '../../domain/entities/course_date.dart';
import '../../domain/repositories/course_repository.dart';
import '../database/database_helper.dart';

class CourseRepositoryImpl implements CourseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Course>> getCourses() async {
    final db = await _dbHelper.database;
    final courseMaps = await _dbHelper.getAllCourses();

    if (courseMaps.isEmpty) return [];

    // Batch fetch all related data (More efficient than N+1 queries)
    // Assuming reasonable dataset size for a personal app
    final allLinks = await db.query('course_links');
    final allDates = await db.query('course_dates');

    // Group by course_id for O(1) access
    final linksMap = <int, List<CourseLink>>{};
    for (var l in allLinks) {
      final cId = l['course_id'] as int;
      if (!linksMap.containsKey(cId)) linksMap[cId] = [];
      linksMap[cId]!.add(
        CourseLink(
          id: l['id'] as int,
          url: l['url'] as String,
          description: l['description'] as String,
        ),
      );
    }

    final datesMap = <int, List<CourseDate>>{};
    for (var d in allDates) {
      final cId = d['course_id'] as int;
      if (!datesMap.containsKey(cId)) datesMap[cId] = [];
      datesMap[cId]!.add(
        CourseDate(
          id: d['id'] as int,
          date: DateTime.parse(d['date_val'] as String),
          description: d['description'] as String,
        ),
      );
    }

    // Map to entities
    return courseMaps.map((map) {
      final id = map['id'] as int;
      return Course(
        id: id,
        title: map['title'] as String,
        description: map['description'] as String?,
        type: _parseCourseType(map['type'] as String?),
        sourceName:
            map['source_name'] as String? ??
            map['platform'] as String? ??
            'Unknown',
        channelName: map['channel_name'] as String?,
        startDate: DateTime.parse(map['start_date'] as String),
        completionDate: map['completion_date'] != null
            ? DateTime.parse(map['completion_date'] as String)
            : null,
        progressPercent: (map['progress_percent'] as num).toDouble(),
        status: map['status'] as String,
        loginMail: map['login_mail'] as String?,
        links: linksMap[id] ?? [],
        timeline: datesMap[id] ?? [],
      );
    }).toList();
  }

  @override
  Future<Course?> getCourse(int id) async {
    final result = await _dbHelper.getCourse(id);
    if (result != null) {
      return await _fromMapWithDetails(result);
    }
    return null;
  }

  @override
  Future<int> createCourse(Course course) async {
    final id = await _dbHelper.createCourse(_toMap(course));
    if (course.links.isNotEmpty) {
      await _dbHelper.insertCourseLinks(
        id,
        course.links
            .map<Map<String, dynamic>>(
              (l) => {'url': l.url, 'description': l.description},
            )
            .toList(),
      );
    }
    if (course.timeline.isNotEmpty) {
      await _dbHelper.insertCourseDates(
        id,
        course.timeline
            .map<Map<String, dynamic>>(
              (d) => {
                'date_val': d.date.toIso8601String(),
                'description': d.description,
              },
            )
            .toList(),
      );
    }
    return id;
  }

  @override
  Future<int> updateCourse(Course course) async {
    final count = await _dbHelper.updateCourse(_toMap(course));
    if (course.id != null) {
      await _dbHelper.updateCourseLinks(
        course.id!,
        course.links
            .map<Map<String, dynamic>>(
              (l) => {'url': l.url, 'description': l.description},
            )
            .toList(),
      );
      await _dbHelper.updateCourseDates(
        course.id!,
        course.timeline
            .map<Map<String, dynamic>>(
              (d) => {
                'date_val': d.date.toIso8601String(),
                'description': d.description,
              },
            )
            .toList(),
      );
    }
    return count;
  }

  @override
  Future<int> deleteCourse(int id) async {
    return await _dbHelper.deleteCourse(id);
  }

  @override
  Future<List<String>> getDistinctSites() async {
    return await _dbHelper.getDistinctSites();
  }

  @override
  Future<List<String>> getDistinctLoginMails() async {
    return await _dbHelper.getDistinctLoginMails();
  }

  // Mapper methods
  Future<Course> _fromMapWithDetails(Map<String, dynamic> map) async {
    final courseId = map['id'] as int;

    // Fetch related data
    final linksData = await _dbHelper.getLinksForCourse(courseId);
    final datesData = await _dbHelper.getDatesForCourse(courseId);

    final links = linksData
        .map(
          (l) => CourseLink(
            id: l['id'],
            url: l['url'],
            description: l['description'],
          ),
        )
        .toList();

    final timeline = datesData
        .map(
          (d) => CourseDate(
            id: d['id'],
            date: DateTime.parse(d['date_val']),
            description: d['description'],
          ),
        )
        .toList();

    return Course(
      id: courseId,
      title: map['title'],
      description: map['description'],
      type: _parseCourseType(map['type']),
      sourceName:
          map['source_name'] ?? map['platform'] ?? 'Unknown', // Fallback
      channelName: map['channel_name'],
      startDate: DateTime.parse(map['start_date']),
      completionDate: map['completion_date'] != null
          ? DateTime.parse(map['completion_date'])
          : null,
      progressPercent: map['progress_percent'],
      status: map['status'],
      loginMail: map['login_mail'],
      links: links,
      timeline: timeline,
    );
  }

  CourseType _parseCourseType(String? typeStr) {
    if (typeStr == null) return CourseType.site;
    return CourseType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => CourseType.site,
    );
  }

  Map<String, dynamic> _toMap(Course course) {
    return {
      'id': course.id,
      'title': course.title,
      'description': course.description,
      'type': course.type.toString().split('.').last,
      'source_name': course.sourceName,
      'platform': course
          .sourceName, // Keep 'platform' updated for backward compatibility if useful
      'channel_name': course.channelName,
      'start_date': course.startDate.toIso8601String(),
      'completion_date': course.completionDate?.toIso8601String(),
      'progress_percent': course.progressPercent,
      'status': course.status,
      'login_mail': course.loginMail,
    };
  }
}

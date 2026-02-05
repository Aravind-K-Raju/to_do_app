import 'package:equatable/equatable.dart';
import 'course_link.dart';
import 'course_date.dart';

enum CourseType { site, platform, selfPaced }

class Course extends Equatable {
  final int? id;
  final String title;
  final String? description;
  final CourseType type;
  final String
  sourceName; // Stores Site Name, Platform Name, or "Self-paced" source
  final String? channelName; // Optional, mainly for Platform (e.g., YouTube)
  final DateTime startDate;
  final DateTime? completionDate;
  final double progressPercent;
  final String status; // 'planned', 'ongoing', 'completed'
  final List<CourseLink> links;
  final List<CourseDate> timeline;

  const Course({
    this.id,
    required this.title,
    this.description,
    this.type = CourseType.site, // Default for migration
    required this.sourceName,
    this.channelName,
    required this.startDate,
    this.completionDate,
    required this.progressPercent,
    required this.status,
    this.links = const [],
    this.timeline = const [],
  });

  // Helper to expose platform for backward compatibility if needed,
  // though now 'sourceName' is the primary field.
  String get platform => sourceName;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    type,
    sourceName,
    channelName,
    startDate,
    completionDate,
    progressPercent,
    status,
    links,
    timeline,
  ];
}

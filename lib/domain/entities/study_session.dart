import 'package:equatable/equatable.dart';

class StudySession extends Equatable {
  final int? id;
  final int courseId;
  final DateTime startTime;
  final int durationMinutes;

  const StudySession({
    this.id,
    required this.courseId,
    required this.startTime,
    required this.durationMinutes,
  });

  @override
  List<Object?> get props => [id, courseId, startTime, durationMinutes];
}

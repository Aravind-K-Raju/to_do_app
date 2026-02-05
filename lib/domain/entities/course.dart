import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final int? id;
  final String title;
  final String? description;
  final String platform;
  final DateTime startDate;
  final DateTime? completionDate;
  final double progressPercent;
  final String status; // 'planned', 'ongoing', 'completed'

  const Course({
    this.id,
    required this.title,
    this.description,
    required this.platform,
    required this.startDate,
    this.completionDate,
    required this.progressPercent,
    required this.status,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    platform,
    startDate,
    completionDate,
    progressPercent,
    status,
  ];
}

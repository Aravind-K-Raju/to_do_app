import 'package:equatable/equatable.dart';

class Assignment extends Equatable {
  final int? id;
  final String title;
  final String? description;
  final String? subject; // e.g. "Math", "Physics"
  final String type; // e.g. "Assignment", "Project", "Exam"
  final DateTime dueDate;
  final DateTime? submissionDate;
  final bool isCompleted;

  const Assignment({
    this.id,
    required this.title,
    this.description,
    this.subject,
    required this.type,
    required this.dueDate,
    this.submissionDate,
    this.isCompleted = false,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    subject,
    type,
    dueDate,
    submissionDate,
    isCompleted,
  ];
}

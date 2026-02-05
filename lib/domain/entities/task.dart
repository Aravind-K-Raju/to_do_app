import 'package:equatable/equatable.dart';

class Task extends Equatable {
  final int? id;
  final String title;
  final String? description;
  final bool isCompleted;
  final int? courseId;
  final DateTime? dueDate;

  const Task({
    this.id,
    required this.title,
    this.description,
    required this.isCompleted,
    this.courseId,
    this.dueDate,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    isCompleted,
    courseId,
    dueDate,
  ];
}

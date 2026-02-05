import 'package:equatable/equatable.dart';

class CourseDate extends Equatable {
  final int? id;
  final DateTime date;
  final String description;

  const CourseDate({this.id, required this.date, required this.description});

  @override
  List<Object?> get props => [id, date, description];
}

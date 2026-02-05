import 'package:equatable/equatable.dart';

class CourseLink extends Equatable {
  final int? id;
  final String url;
  final String description;

  const CourseLink({this.id, required this.url, required this.description});

  @override
  List<Object?> get props => [id, url, description];
}

import 'package:equatable/equatable.dart';

class EventDate extends Equatable {
  final int? id;
  final DateTime date;
  final String description;

  const EventDate({this.id, required this.date, required this.description});

  @override
  List<Object?> get props => [id, date, description];
}

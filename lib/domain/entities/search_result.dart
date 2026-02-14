import 'package:equatable/equatable.dart';

class SearchResult extends Equatable {
  final String id;
  final String title;
  final String subtitle;
  final String type; // Task, Assignment, Course, Event
  final DateTime? date; // Due date or Start date
  final String? route; // Navigation route if needed
  final dynamic payload; // The actual object if needed

  const SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.date,
    this.route,
    this.payload,
  });

  @override
  List<Object?> get props => [id, title, subtitle, type, date, route, payload];
}

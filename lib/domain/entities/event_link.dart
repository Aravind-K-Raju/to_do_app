import 'package:equatable/equatable.dart';

class EventLink extends Equatable {
  final int? id;
  final String url;
  final String description;

  const EventLink({this.id, required this.url, required this.description});

  @override
  List<Object?> get props => [id, url, description];
}

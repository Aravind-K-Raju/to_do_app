import 'package:equatable/equatable.dart';
import 'event_link.dart';
import 'event_date.dart';

class Hackathon extends Equatable {
  final int? id;
  final String name;
  final String? theme;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final int? teamSize;
  final String? techStack;
  final String? outcome;
  final String? projectLink;
  final String? loginMail;
  final List<EventLink> links;
  final List<EventDate> timeline;

  const Hackathon({
    this.id,
    required this.name,
    this.theme,
    this.description,
    required this.startDate,
    this.endDate,
    this.teamSize,
    this.techStack,
    this.outcome,
    this.projectLink,
    this.loginMail,
    this.links = const [],
    this.timeline = const [],
  });

  @override
  List<Object?> get props => [
    id,
    name,
    theme,
    description,
    startDate,
    endDate,
    teamSize,
    techStack,
    outcome,
    projectLink,
    loginMail,
    links,
    timeline,
  ];
}

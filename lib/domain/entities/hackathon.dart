import 'package:equatable/equatable.dart';

class Hackathon extends Equatable {
  final int? id;
  final String name;
  final String? theme;
  final DateTime startDate;
  final DateTime? endDate;
  final int? teamSize;
  final String? techStack;
  final String? outcome;
  final String? projectLink;

  const Hackathon({
    this.id,
    required this.name,
    this.theme,
    required this.startDate,
    this.endDate,
    this.teamSize,
    this.techStack,
    this.outcome,
    this.projectLink,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    theme,
    startDate,
    endDate,
    teamSize,
    techStack,
    outcome,
    projectLink,
  ];
}

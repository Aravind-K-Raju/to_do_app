import 'package:equatable/equatable.dart';
import 'course.dart';
import 'task.dart';
import 'assignment.dart';
import 'hackathon.dart';

class InsightsData extends Equatable {
  final int totalCourses;
  final int completedCourses;
  final int totalTasks;
  final int completedTasks;
  final int totalAssignments;
  final int completedAssignments;
  final int totalEvents;
  final int completedEvents;
  final double overallScore;

  final List<Course> activeCourses;
  final List<Task> pendingTasks;
  final List<Assignment> pendingAssignments;
  final List<Hackathon> upcomingEvents;
  final List<AgendaItem> agendaToday;
  final List<AgendaItem> agendaTomorrow;

  const InsightsData({
    required this.totalCourses,
    required this.completedCourses,
    required this.totalTasks,
    required this.completedTasks,
    required this.totalAssignments,
    required this.completedAssignments,
    required this.totalEvents,
    required this.completedEvents,
    required this.overallScore,
    required this.activeCourses,
    required this.pendingTasks,
    required this.pendingAssignments,
    required this.upcomingEvents,
    required this.agendaToday,
    required this.agendaTomorrow,
  });

  // Factory with defaults for empty state
  factory InsightsData.empty() {
    return const InsightsData(
      totalCourses: 0,
      completedCourses: 0,
      totalTasks: 0,
      completedTasks: 0,
      totalAssignments: 0,
      completedAssignments: 0,
      totalEvents: 0,
      completedEvents: 0,
      overallScore: 0.0,
      activeCourses: [],
      pendingTasks: [],
      pendingAssignments: [],
      upcomingEvents: [],
      agendaToday: [],
      agendaTomorrow: [],
    );
  }

  @override
  List<Object?> get props => [
    totalCourses,
    completedCourses,
    totalTasks,
    completedTasks,
    totalAssignments,
    completedAssignments,
    totalEvents,
    completedEvents,
    overallScore,
    activeCourses,
    pendingTasks,
    pendingAssignments,
    upcomingEvents,
    agendaToday,
    agendaTomorrow,
  ];
}

class AgendaItem extends Equatable {
  final int id;
  final String title;
  final String subtitle;
  final DateTime? time;
  final String type; // Task, Assignment, Event
  final bool isCompleted;

  const AgendaItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.time,
    required this.type,
    required this.isCompleted,
  });

  @override
  List<Object?> get props => [id, title, subtitle, time, type, isCompleted];
}

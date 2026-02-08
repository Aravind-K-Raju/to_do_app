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
  ];
}

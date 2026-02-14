import 'package:flutter/material.dart';
import '../../domain/entities/assignment.dart';
import '../../domain/usecases/assignment_usecases.dart';
import '../../core/services/notification_scheduler.dart';

class AssignmentProvider extends ChangeNotifier {
  final GetAssignments getAssignments;
  final AddAssignment addAssignment;
  final UpdateAssignment updateAssignment;
  final DeleteAssignment deleteAssignment;

  List<Assignment> _assignments = [];
  bool _isLoading = false;

  AssignmentProvider({
    required this.getAssignments,
    required this.addAssignment,
    required this.updateAssignment,
    required this.deleteAssignment,
  });

  List<Assignment> get assignments => _assignments;
  bool get isLoading => _isLoading;

  Future<void> loadAssignments() async {
    _isLoading = true;
    notifyListeners();
    try {
      _assignments = await getAssignments();
    } catch (e) {
      debugPrint("Error loading assignments: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> add(Assignment assignment) async {
    await addAssignment(assignment);
    await loadAssignments();
    // Schedule notification
    if (!assignment.isCompleted) {
      final created = _assignments
          .where((a) => a.title == assignment.title)
          .lastOrNull;
      if (created?.id != null) {
        await NotificationScheduler.scheduleForAssignment(
          assignmentId: created!.id!,
          title: assignment.title,
          body: '${assignment.subject ?? ''} - ${assignment.type}',
          dueDate: assignment.dueDate,
        );
      }
    }
  }

  Future<void> update(Assignment assignment) async {
    if (assignment.id != null) {
      // 1. Cancel OS alarms for old rows + delete DB rows
      await NotificationScheduler.cancelForItem(
        'assignment_id',
        assignment.id!,
      );
    }
    await updateAssignment(assignment);
    await loadAssignments();
    // 2. Re-schedule if not completed
    if (assignment.id != null && !assignment.isCompleted) {
      await NotificationScheduler.scheduleForAssignment(
        assignmentId: assignment.id!,
        title: assignment.title,
        body: '${assignment.subject ?? ''} - ${assignment.type}',
        dueDate: assignment.dueDate,
      );
    }
  }

  Future<void> delete(int id) async {
    // 1. Query IDs → Cancel OS → Delete DB rows
    await NotificationScheduler.cancelForItem('assignment_id', id);
    // 2. Delete parent
    await deleteAssignment(id);
    await loadAssignments();
  }

  Future<void> toggleCompletion(Assignment assignment) async {
    final updated = Assignment(
      id: assignment.id,
      title: assignment.title,
      description: assignment.description,
      subject: assignment.subject,
      type: assignment.type,
      dueDate: assignment.dueDate,
      submissionDate: assignment.submissionDate,
      isCompleted: !assignment.isCompleted,
    );
    await update(updated);
  }
}

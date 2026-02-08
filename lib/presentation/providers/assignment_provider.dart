import 'package:flutter/material.dart';
import '../../domain/entities/assignment.dart';
import '../../domain/usecases/assignment_usecases.dart';

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
  }

  Future<void> update(Assignment assignment) async {
    await updateAssignment(assignment);
    await loadAssignments();
  }

  Future<void> delete(int id) async {
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

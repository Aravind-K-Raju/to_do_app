import '../../domain/entities/assignment.dart';
import '../../domain/repositories/assignment_repository.dart';
import '../database/database_helper.dart';

class AssignmentRepositoryImpl implements AssignmentRepository {
  final _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Assignment>> getAssignments() async {
    final data = await _dbHelper.getAllAssignments();
    return data.map((map) {
      return Assignment(
        id: map['id'] as int,
        title: map['title'] as String,
        description: map['description'] as String?,
        subject: map['subject'] as String?,
        type: map['type'] as String,
        dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
        submissionDate: map['submission_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['submission_date'] as int)
            : null,
        isCompleted: (map['is_completed'] as int) == 1,
      );
    }).toList();
  }

  @override
  Future<void> addAssignment(Assignment assignment) async {
    final map = {
      'title': assignment.title,
      'description': assignment.description,
      'subject': assignment.subject,
      'type': assignment.type,
      'due_date': assignment.dueDate.millisecondsSinceEpoch,
      'submission_date': assignment.submissionDate?.millisecondsSinceEpoch,
      'is_completed': assignment.isCompleted ? 1 : 0,
    };
    await _dbHelper.createAssignment(map);
  }

  @override
  Future<void> updateAssignment(Assignment assignment) async {
    final map = {
      'id': assignment.id,
      'title': assignment.title,
      'description': assignment.description,
      'subject': assignment.subject,
      'type': assignment.type,
      'due_date': assignment.dueDate.millisecondsSinceEpoch,
      'submission_date': assignment.submissionDate?.millisecondsSinceEpoch,
      'is_completed': assignment.isCompleted ? 1 : 0,
    };
    await _dbHelper.updateAssignment(map);
  }

  @override
  Future<void> deleteAssignment(int id) async {
    await _dbHelper.deleteAssignment(id);
  }
}

import '../entities/assignment.dart';
import '../repositories/assignment_repository.dart';

class GetAssignments {
  final AssignmentRepository repository;

  GetAssignments(this.repository);

  Future<List<Assignment>> call() async {
    return await repository.getAssignments();
  }
}

class AddAssignment {
  final AssignmentRepository repository;

  AddAssignment(this.repository);

  Future<void> call(Assignment assignment) async {
    await repository.addAssignment(assignment);
  }
}

class UpdateAssignment {
  final AssignmentRepository repository;

  UpdateAssignment(this.repository);

  Future<void> call(Assignment assignment) async {
    await repository.updateAssignment(assignment);
  }
}

class DeleteAssignment {
  final AssignmentRepository repository;

  DeleteAssignment(this.repository);

  Future<void> call(int id) async {
    await repository.deleteAssignment(id);
  }
}

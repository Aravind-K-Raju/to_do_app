import '../entities/assignment.dart';

abstract class AssignmentRepository {
  Future<List<Assignment>> getAssignments();
  Future<void> addAssignment(Assignment assignment);
  Future<void> updateAssignment(Assignment assignment);
  Future<void> deleteAssignment(int id);
}

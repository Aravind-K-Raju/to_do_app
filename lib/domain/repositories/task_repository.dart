import '../entities/task.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasks(int courseId);
  Future<int> createTask(Task task);
  Future<int> updateTask(Task task);
  Future<int> deleteTask(int id);
}

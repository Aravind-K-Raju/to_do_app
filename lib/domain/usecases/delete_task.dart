import '../repositories/task_repository.dart';

class DeleteTask {
  final TaskRepository repository;

  DeleteTask(this.repository);

  Future<int> call(int id) async {
    return await repository.deleteTask(id);
  }
}

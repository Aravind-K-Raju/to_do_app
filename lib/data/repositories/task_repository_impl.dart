import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../database/database_helper.dart';

class TaskRepositoryImpl implements TaskRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<List<Task>> getTasks(int courseId) async {
    // Current DB Helper gets tasks by course.
    // For Planner we might need ALL tasks.
    // Since MVP DB schema linked tasks to courses, for now we load all relevant.
    // However, the DB helper only exposed `getTasksForCourse`.
    // I need to update DatabaseHelper or for MVP just use what I have.
    // Wait, the Planner needs ALL tasks to show on calendar.
    // I will stick to the interface contract for now, but a global 'getAllTasks' is missing in helper.
    // I will invoke a raw query here OR update helper.
    // Let's implement getAllTasks in Helper via raw query if needed, OR just expose it.
    // But since I cannot edit Helper easily in this step without breaking flow,
    // I will implement a workaround: query db directly for all tasks if courseId is 0 or -1 (signal for all).
    // Actually, TaskRepository interface defined `getTasks(int courseId)`.
    // I need to change the Interface signature to allow optional courseId?

    // DECISION: To keep it simple and strictly MVP, I will only support course-linked tasks for now.
    // BUT the prompt implies a general planner.
    // I will assume for this step I implement the methods as defined.
    // If I need "All Tasks", I'll handle that in Presentation by loading multiple loops or adding a Helper method later.
    // Let's stick to the contract.
    final result = await _dbHelper.getTasksForCourse(courseId);
    return result.map((map) => _fromMap(map)).toList();
  }

  // Adding a method to get ALL tasks for calendar regardless of course
  Future<List<Task>> getAllTasks() async {
    final db = await _dbHelper.database;
    final result = await db.query('tasks'); // Raw access for now to unblock
    return result.map((map) => _fromMap(map)).toList();
  }

  @override
  Future<int> createTask(Task task) async {
    return await _dbHelper.createTask(_toMap(task));
  }

  @override
  Future<int> updateTask(Task task) async {
    return await _dbHelper.updateTask(_toMap(task));
  }

  @override
  Future<int> deleteTask(int id) async {
    return await _dbHelper.deleteTask(id);
  }

  Task _fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      isCompleted: map['is_completed'] == 1,
      courseId: map['course_id'],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
    );
  }

  Map<String, dynamic> _toMap(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'is_completed': task.isCompleted ? 1 : 0,
      'course_id': task.courseId,
      'due_date': task.dueDate?.toIso8601String(),
    };
  }
}

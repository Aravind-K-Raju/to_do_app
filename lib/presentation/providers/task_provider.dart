import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/create_task.dart';
import '../../domain/usecases/update_task.dart';
import '../../domain/usecases/delete_task.dart';
import '../../data/repositories/task_repository_impl.dart';

class TaskProvider extends ChangeNotifier {
  final TaskRepositoryImpl
  repository; // Direct Impl access for 'getAllTasks' workaround
  final CreateTask createTask;
  final UpdateTask updateTask;
  final DeleteTask deleteTask;

  TaskProvider({
    required this.repository,
    required this.createTask,
    required this.updateTask,
    required this.deleteTask,
  });

  List<Task> _allTasks = [];
  List<Task> _selectedDayTasks = [];
  DateTime _selectedDay = DateTime.now();

  List<Task> get selectedDayTasks => _selectedDayTasks;
  DateTime get selectedDay => _selectedDay;

  Map<DateTime, List<Task>> _events = {};

  // Calendar Event Loader
  List<Task> getTasksForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    _selectedDay = selectedDay;
    _updateSelectedDayTasks();
    notifyListeners();
  }

  void _updateSelectedDayTasks() {
    // We can use the formatted key to look up
    _selectedDayTasks = getTasksForDay(_selectedDay);
  }

  Future<void> loadAllTasks() async {
    try {
      _allTasks = await repository.getAllTasks();
      _groupTasksByDay();
      _updateSelectedDayTasks();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading tasks: $e");
    }
  }

  void _groupTasksByDay() {
    _events = {};
    for (var task in _allTasks) {
      if (task.dueDate != null) {
        final date = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        if (_events[date] == null) _events[date] = [];
        _events[date]!.add(task);
      }
    }
  }

  Future<void> addTask(Task task) async {
    await createTask(task);
    await loadAllTasks();
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      isCompleted: !task.isCompleted,
      courseId: task.courseId,
      dueDate: task.dueDate,
    );
    await updateTask(updatedTask);
    await loadAllTasks();
  }

  Future<void> removeTask(int id) async {
    await deleteTask(id);
    await loadAllTasks();
  }
}

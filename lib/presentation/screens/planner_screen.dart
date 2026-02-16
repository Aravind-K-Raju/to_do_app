import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/task_provider.dart';
import '../providers/course_provider.dart';
import '../widgets/task_list_item.dart';
import '../../domain/entities/task.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TaskProvider>(context, listen: false).loadAllTasks();
    });
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);

    final titleController = TextEditingController();
    // Use the currently selected day as default
    DateTime selectedDate = taskProvider.selectedDay;
    TimeOfDay? selectedTime;
    int? selectedCourseId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedCourseId,
                  hint: const Text('Link to Course (Optional)'),
                  items: courseProvider.courses
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.title.length > 20
                                ? '${c.title.substring(0, 20)}...'
                                : c.title,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => selectedCourseId = val),
                  isExpanded: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => selectedTime = time);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              selectedTime != null
                                  ? selectedTime!.format(context)
                                  : 'Add Time',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    // Combine Date and Time
                    final DateTime finalDueDate = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime?.hour ?? 0,
                      selectedTime?.minute ?? 0,
                    );

                    final newTask = Task(
                      title: titleController.text,
                      isCompleted: false,
                      dueDate: finalDueDate,
                      courseId: selectedCourseId,
                    );
                    taskProvider.addTask(newTask);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            appBar: AppBar(title: const Text('Planner')),
            body: Column(
              children: [
                TableCalendar<Task>(
                  firstDay: DateTime(2020, 10, 16),
                  lastDay: DateTime(2030, 3, 14),
                  focusedDay: _focusedDay,
                  headerStyle: const HeaderStyle(formatButtonVisible: false),
                  selectedDayPredicate: (day) =>
                      isSameDay(provider.selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });

                    provider.onDaySelected(selectedDay, focusedDay);

                    if (provider.getTasksForDay(selectedDay).isEmpty) {
                      _showAddTaskDialog(context);
                    }
                  },
                  eventLoader: provider.getTasksForDay,
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final tasks = provider.getTasksForDay(day);
                      if (tasks.isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(6.0),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                    todayBuilder: (context, day, focusedDay) {
                      final tasks = provider.getTasksForDay(day);
                      if (tasks.isNotEmpty) {
                        // Prioritize Task View over Today View
                        return Container(
                          margin: const EdgeInsets.all(6.0),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      // Standard Today View
                      return Container(
                        margin: const EdgeInsets.all(6.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.amberAccent,
                            width: 2.0,
                          ),
                        ),
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      final tasks = provider.getTasksForDay(day);
                      if (tasks.isNotEmpty) {
                        return Container(
                          margin: const EdgeInsets.all(6.0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.0),
                          ),
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                    markerBuilder: (context, day, events) {
                      return const SizedBox(); // Hide default green dot
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    // markerDecoration removed as we hide markers
                    todayDecoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.selectedDayTasks.length,
                    itemBuilder: (context, index) {
                      final task = provider.selectedDayTasks[index];
                      return TaskListItem(
                        task: task,
                        onToggle: () => provider.toggleTaskCompletion(task),
                        onDelete: () => provider.removeTask(task.id!),
                        key: ValueKey(task.id),
                      );
                    },
                  ),
                ),
              ],
            ),
            floatingActionButton: provider.selectedDayTasks.isNotEmpty
                ? FloatingActionButton(
                    onPressed: () => _showAddTaskDialog(context),
                    child: const Icon(Icons.add_task),
                  )
                : null,
          );
        },
      ),
    );
  }
}

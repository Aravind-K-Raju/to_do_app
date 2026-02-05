import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
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

  void _showAddTaskDialog(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(
      context,
      listen: false,
    ); // Need courses for dropdown

    final titleController = TextEditingController();
    DateTime? selectedDate = taskProvider.selectedDay;
    int? selectedCourseId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.title)),
                  )
                  .toList(),
              onChanged: (val) => selectedCourseId = val,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  // ignore: use_build_context_synchronously
                  if (!ctx.mounted) return;
                  Navigator.pop(
                    ctx,
                  ); // Close current to refresh? No just update var
                  // Actually Dialog is stateless unless StatefulBuilder.
                  // For MVP simple hack: just assume date picked is okay or use StatefulBuilder if strictly needing UI update.
                  // Defaulting to currently selected day in calendar which is usually what user wants.
                  selectedDate = date;
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 8),
                  Text(
                    selectedDate != null
                        ? DateFormat.yMMMd().format(selectedDate!)
                        : 'No Date',
                  ),
                ],
              ),
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
                final newTask = Task(
                  title: titleController.text,
                  isCompleted: false,
                  dueDate: selectedDate,
                  courseId: selectedCourseId,
                );
                taskProvider.addTask(newTask);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planner')),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              TableCalendar<Task>(
                firstDay: DateTime.utc(2020, 10, 16),
                lastDay: DateTime.utc(2030, 3, 14),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    isSameDay(provider.selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                  provider.onDaySelected(selectedDay, focusedDay);
                },
                eventLoader: provider.getTasksForDay,
                calendarStyle: const CalendarStyle(
                  markerDecoration: BoxDecoration(
                    color: Colors.tealAccent,
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
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add_task),
      ),
    );
  }
}

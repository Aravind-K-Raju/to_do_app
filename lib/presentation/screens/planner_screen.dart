import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../providers/task_provider.dart';
import '../widgets/task_list_item.dart';
import '../../domain/entities/task.dart';
import '../widgets/glass/prism_floating_action_button.dart';
import 'task_add_edit_screen.dart';

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
    _focusedDay = Provider.of<TaskProvider>(context, listen: false).selectedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TaskProvider>(context, listen: false).loadAllTasks();
    });
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => TaskAddEditScreen(initialDate: taskProvider.selectedDay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

          final calendarWidget = TableCalendar<Task>(
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2.0),
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
          );

          final taskListWidget = ListView.builder(
            itemCount: provider.selectedDayTasks.length,
            padding: const EdgeInsets.only(bottom: 90), // Prevent overlap with bottom nav
            itemBuilder: (context, index) {
              final task = provider.selectedDayTasks[index];
              return TaskListItem(
                task: task,
                onEdit: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskAddEditScreen(
                        initialDate: provider.selectedDay,
                        task: task,
                      ),
                    ),
                  );
                },
                onToggle: () => provider.toggleTaskCompletion(task),
                onDelete: () => provider.removeTask(task.id!),
                key: ValueKey(task.id),
              );
            },
          );

          return Scaffold(
            appBar: AppBar(title: const Text('Planner')),
            body: isLandscape
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 90),
                          child: calendarWidget,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 5,
                        child: taskListWidget,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      calendarWidget,
                      const Divider(),
                      Expanded(
                        child: taskListWidget,
                      ),
                    ],
                  ),
            floatingActionButton: provider.selectedDayTasks.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 80.0),
                    child: PrismFloatingActionButton(
                      heroTag: 'add_task_fab',
                      onPressed: () => _showAddTaskDialog(context),
                      icon: Icons.add_task,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}



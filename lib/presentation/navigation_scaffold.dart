import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/notification_service.dart';
import 'screens/assignment_list_screen.dart';
import 'screens/course_list_screen.dart';
import 'screens/hackathon_list_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/planner_screen.dart';
import 'providers/task_provider.dart';
import 'providers/assignment_provider.dart';

class NavigationScaffold extends StatefulWidget {
  const NavigationScaffold({super.key});

  @override
  State<NavigationScaffold> createState() => _NavigationScaffoldState();
}

class _NavigationScaffoldState extends State<NavigationScaffold> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    final service = NotificationService();
    await service.initialize((response) async {
      if (response.actionId == NotificationService.actionMarkDone) {
        final payload = response.payload;
        if (payload != null) {
          await _handleMarkDone(payload);
        }
      }
    });
  }

  Future<void> _handleMarkDone(String payload) async {
    // format: type|id
    final parts = payload.split('|');
    if (parts.length < 2) return;
    final type = parts[0];
    final idStr = parts[1];
    final id = int.tryParse(idStr);
    if (id == null) return;

    if (type == 'Task') {
      // Need TaskProvider. But we are in a method.
      // We can use Provider.of(context, listen: false) if context is valid.
      // If app was launched from background, context might be ready?
      if (mounted) {
        final provider = Provider.of<TaskProvider>(context, listen: false);
        // We need to toggle completion. But we only have ID.
        // TaskProvider.removeTask exists. toggleTaskCompletion takes a Task object.
        // We need to fetch the task first or add a method to toggle by ID.
        // Adding toggleTaskCompletionById to TaskProvider is best.
        // For now, let's load tasks and find it.
        // Or blindly call update if we can construct a dummy task? No.

        // provider.allTasks is available now.
        try {
          final task = provider.allTasks.firstWhere((t) => t.id == id);
          await provider.toggleTaskCompletion(task);
        } catch (_) {
          // Task not found or other error
        }
      }
    } else if (type == 'Assignment') {
      if (mounted) {
        final provider = Provider.of<AssignmentProvider>(
          context,
          listen: false,
        );
        try {
          final assignment = provider.assignments.firstWhere((a) => a.id == id);
          await provider.toggleCompletion(assignment);
        } catch (_) {}
      }
    }
  }

  final List<Widget> _screens = [
    const CourseListScreen(),
    const PlannerScreen(),
    const HackathonListScreen(),
    const AssignmentListScreen(),
    const InsightsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Needed for 4+ items
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Courses'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Planner',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.code), label: 'Events'),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Assignments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}

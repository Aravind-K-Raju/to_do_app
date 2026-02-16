import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/notification_service.dart';
import '../core/services/notification_scheduler.dart';
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

class _NavigationScaffoldState extends State<NavigationScaffold>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshProviders(); // Ensure data is loaded on launch
    _initNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[NavScaffold] App resumed - refreshing data...');
      _refreshProviders();
    }
  }

  Future<void> _refreshProviders() async {
    if (!mounted) return;
    // Refresh Tasks
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    await taskProvider.loadAllTasks();

    if (!mounted) return;
    // Refresh Assignments
    final assignmentProvider = Provider.of<AssignmentProvider>(
      context,
      listen: false,
    );
    await assignmentProvider.loadAssignments();
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
    // Refresh all schedules to ensure they have the new payload format (RowId)
    await NotificationScheduler.rescheduleAllFromDb();

    // Backfill scheduled_notifications table from existing data (V8 migration)
    if (mounted) {
      await NotificationScheduler.backfillFromExisting(context);
    }
  }

  Future<void> _handleMarkDone(String payload) async {
    debugPrint('[NavScaffold] Mark Done received with payload: $payload');
    // format: type|itemId|rowId
    final parts = payload.split('|');
    if (parts.length < 2) return;
    final type = parts[0];
    final idStr = parts[1];
    final id = int.tryParse(idStr);

    // Check for rowId (3rd part)
    int? rowId;
    if (parts.length >= 3) {
      rowId = int.tryParse(parts[2]);
    }
    debugPrint('[NavScaffold] Parsed: ID=$id, RowID=$rowId');

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
        } catch (e) {
          debugPrint('[NavScaffold] Error finding task to complete: $e');
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

    // Use NotificationScheduler's cancelForItem to handle DB lookup and multi-notification cleanup
    // this handles the "rowId vs itemId" mismatch automatically by querying the DB
    if (type == 'Task') {
      await NotificationScheduler.cancelForItem('task_id', id);
    } else if (type == 'Assignment') {
      await NotificationScheduler.cancelForItem('assignment_id', id);
    } else if (type == 'Course') {
      await NotificationScheduler.cancelForItem('course_id', id);
    } else if (type == 'Event') {
      await NotificationScheduler.cancelForItem('hackathon_id', id);
    } else {
      // Fallback for unknown types or legacy
      if (rowId != null) {
        await NotificationService().cancelNotification(rowId);
      } else {
        await NotificationService().cancelNotification(id);
      }
    }
  }

  final List<Widget> _screens = [
    const InsightsScreen(),
    const CourseListScreen(),
    const PlannerScreen(),
    const HackathonListScreen(),
    const AssignmentListScreen(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
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
        ],
      ),
    );
  }
}

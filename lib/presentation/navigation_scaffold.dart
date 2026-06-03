import 'dart:ui';
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
import '../data/database/database_helper.dart';
import 'widgets/glass/glass_container.dart';
import 'providers/draft_provider.dart';

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
      } else if (response.actionId == NotificationService.actionMarkRead) {
        final payload = response.payload;
        if (payload != null) {
          final parts = payload.split('|');
          if (parts.length >= 3) {
            final rowId = int.tryParse(parts[2]);
            if (rowId != null) {
              await DatabaseHelper.instance.database.then(
                (db) => db.delete('scheduled_notifications', where: 'id = ?', whereArgs: [rowId])
              );
              await NotificationService().cancelNotification(rowId);
            }
          } else if (parts.length >= 2) {
             final id = int.tryParse(parts[1]);
             if (id != null) await NotificationService().cancelNotification(id);
          }
        }
      } else if (response.actionId == NotificationService.actionRemindLater) {
        final payload = response.payload;
        if (payload != null) {
          _handleRemindLater(payload);
        }
      }
    });
    // Refresh all schedules to ensure they have the new payload format (RowId)
    // Removed rescheduleAllFromDb() as it clears active notifications.

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

  Future<void> _handleRemindLater(String payload) async {
    final parts = payload.split('|');
    if (parts.length < 2) return;
    
    int? rowId;
    if (parts.length >= 3) {
      rowId = int.tryParse(parts[2]);
    }
    
    if (!mounted) return;

    final delay = await showDialog<Duration>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remind me in...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('15 Minutes'),
                onTap: () => Navigator.pop(context, const Duration(minutes: 15)),
              ),
              ListTile(
                title: const Text('1 Hour'),
                onTap: () => Navigator.pop(context, const Duration(hours: 1)),
              ),
              ListTile(
                title: const Text('2 Hours'),
                onTap: () => Navigator.pop(context, const Duration(hours: 2)),
              ),
              ListTile(
                title: const Text('1 Day'),
                onTap: () => Navigator.pop(context, const Duration(days: 1)),
              ),
            ],
          ),
        );
      }
    );

    if (delay != null && rowId != null) {
      final rows = await DatabaseHelper.instance.database.then(
        (db) => db.query('scheduled_notifications', where: 'id = ?', whereArgs: [rowId])
      );
      if (rows.isNotEmpty) {
          final row = rows.first;
          final String title = row['title'] as String;
          final String body = row['body'] as String;
          
          final newTime = DateTime.now().add(delay);
          await NotificationService().scheduleNotification(
            id: rowId,
            title: title,
            body: body,
            scheduledDate: newTime,
            payload: payload,
            ongoing: true,
          );
          
          await DatabaseHelper.instance.database.then(
            (db) => db.update(
              'scheduled_notifications', 
              {'scheduled_at': newTime.toIso8601String()}, 
              where: 'id = ?', 
              whereArgs: [rowId]
            )
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reminder delayed.')),
            );
          }
      }
    } else if (delay == null && rowId != null) {
      // User cancelled, put the notification back right away
      final rows = await DatabaseHelper.instance.database.then(
        (db) => db.query('scheduled_notifications', where: 'id = ?', whereArgs: [rowId])
      );
      if (rows.isNotEmpty) {
          final row = rows.first;
          final String title = row['title'] as String;
          final String body = row['body'] as String;
          
          final newTime = DateTime.now().add(const Duration(seconds: 2));
          await NotificationService().scheduleNotification(
            id: rowId,
            title: title,
            body: body,
            scheduledDate: newTime,
            payload: payload,
            ongoing: true,
          );
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

  Widget _buildCustomNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    icon,
                    size: isSelected ? 26 : 24,
                    color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
                Consumer<DraftProvider>(
                  builder: (context, draftProvider, child) {
                    bool hasDraft = false;
                    if (index == 1) {
                      hasDraft = draftProvider.hasCourseDraft;
                    } else if (index == 2) {
                      hasDraft = draftProvider.hasTaskDraft;
                    } else if (index == 3) {
                      hasDraft = draftProvider.hasHackathonDraft;
                    } else if (index == 4) {
                      hasDraft = draftProvider.hasAssignmentDraft;
                    }
                    
                    if (hasDraft) {
                      return Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red,
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027), // Deep dark gradient
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        opacity: 0.15,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2))),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth) / 5;
                return Stack(
                  children: [
                    // Sliding Glass Marble Indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: _currentIndex * itemWidth,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                            child: Container(
                              width: itemWidth - 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                                  colors: [
                                    Colors.white.withValues(alpha: 0.6),
                                    const Color(0xFF8CE6FF).withValues(alpha: 0.15), // Cyan tint
                                    const Color(0xFFFF8CC6).withValues(alpha: 0.1),  // Pink tint
                                    const Color(0xFFFFF08C).withValues(alpha: 0.15), // Yellow tint
                                    Colors.white.withValues(alpha: 0.3),
                                  ],
                                ),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              // Inner glow effect
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: RadialGradient(
                                    center: const Alignment(-0.5, -0.5),
                                    radius: 1.5,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Navigation Items
                    Row(
                      children: [
                        _buildCustomNavItem(Icons.insights, 'Insights', 0),
                        _buildCustomNavItem(Icons.school, 'Courses', 1),
                        _buildCustomNavItem(Icons.calendar_month, 'Planner', 2),
                        _buildCustomNavItem(Icons.code, 'Events', 3),
                        _buildCustomNavItem(Icons.assignment, 'Assignments', 4),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

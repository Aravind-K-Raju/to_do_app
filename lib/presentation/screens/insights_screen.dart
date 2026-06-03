import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/intelligence_provider.dart';
import '../providers/task_provider.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/entities/insights_data.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_settings_dialog.dart';
import '../../core/app_theme.dart';
import 'planner_screen.dart';
import 'assignment_list_screen.dart';
import 'course_list_screen.dart';
import 'hackathon_list_screen.dart';
import 'notes/folder_list_screen.dart';
import '../../data/database/database_helper.dart';
import '../widgets/glass/glass_container.dart';
import '../../core/services/notification_prefs_service.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/notification_service.dart';
import 'pre_planner_screen.dart';
import 'full_schedule_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import '../../core/services/widget_sync_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _swipeHintController;
  late Animation<Offset> _swipeHintAnimation;
  final NotificationPrefsService _prefsService = NotificationPrefsService();
  List<Map<String, dynamic>>? _cachedPlan;
  bool _isLoadingPlan = false;
  String? _planError;
  Timer? _planCheckTimer;
  Timer? _swipeHintTimer;
  bool _isTodayHoliday = false;

  // Widget pause/resume state parameters
  bool _isPaused = false;
  String _pausedAt = '';
  String _pausedTaskTitle = '';
  int _pausedRemainingMins = 0;
  bool _isOngoingExpanded = false;

  // Search-related states
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchResults = false;
  final List<String> _filters = ['Task', 'Assignment', 'Course', 'Event', 'Yet to Complete'];
  final List<String> _selectedFilters = [];
  final List<DateTime> _selectedDates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _swipeHintAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.25, 0.0))
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(-0.25, 0.0)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(-0.25, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 40.0,
      ),
    ]).animate(_swipeHintController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<IntelligenceProvider>(
        context,
        listen: false,
      ).loadStatsForToday();
      _checkAndGeneratePlan();
      _checkWidgetPauseState();

      // Trigger the swipe hint animation after a short delay via a cancelable Timer
      _swipeHintTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _swipeHintController.forward();
        }
      });
    });

    _planCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndGeneratePlan();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _planCheckTimer?.cancel();
    _swipeHintTimer?.cancel();
    _swipeHintController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWidgetPauseState();
    }
  }

  Future<void> _loadWidgetPauseState() async {
    try {
      final isPaused = await HomeWidget.getWidgetData<bool>('is_paused') ?? false;
      final pausedAt = await HomeWidget.getWidgetData<String>('paused_at') ?? '';
      final pausedTaskTitle = await HomeWidget.getWidgetData<String>('paused_task_title') ?? '';
      final pausedRemaining = await HomeWidget.getWidgetData<int>('paused_remaining_minutes') ?? 0;

      if (mounted) {
        setState(() {
          _isPaused = isPaused;
          _pausedAt = pausedAt;
          _pausedTaskTitle = pausedTaskTitle;
          _pausedRemainingMins = pausedRemaining;
        });
      }
    } catch (e) {
      debugPrint('[InsightsScreen] Error loading widget pause state: $e');
    }
  }

  Future<void> _checkWidgetPauseState() async {
    try {
      final isPausedOnWidget = await HomeWidget.getWidgetData<bool>('is_paused') ?? false;
      final isPausedInApp = await HomeWidget.getWidgetData<bool>('app_last_known_paused') ?? false;
      final pausedAt = await HomeWidget.getWidgetData<String>('paused_at') ?? '';

      await _loadWidgetPauseState();

      if (isPausedOnWidget != isPausedInApp) {
        await HomeWidget.saveWidgetData<bool>('app_last_known_paused', isPausedOnWidget);
        if (isPausedOnWidget) {
          await WidgetSyncService.runBackgroundReschedule(action: 'pause', pausedAt: pausedAt);
          await _loadWidgetPauseState();
        } else {
          await _runAiReschedule(action: 'resume');
        }
      }
    } catch (e) {
      debugPrint('[InsightsScreen] Error checking widget pause state: $e');
    }
  }

  int _parseTimeToMinutes(String timeStr) {
    try {
      final cleaned = timeStr.trim().toUpperCase();
      final ampmParts = cleaned.split(' ');
      final hmParts = ampmParts[0].split(':');
      var hour = int.parse(hmParts[0]);
      final minute = int.parse(hmParts[1]);

      final ampm = ampmParts.length > 1 ? ampmParts[1] : (cleaned.contains('PM') ? 'PM' : 'AM');

      if (ampm == 'PM' && hour != 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _runAiReschedule({
    required String action,
    String? pausedAt,
  }) async {
    if (_isLoadingPlan) return;

    if (mounted) {
      setState(() {
        _isLoadingPlan = true;
        _planError = null;
      });
    }

    try {
      await WidgetSyncService.runBackgroundReschedule(action: action, pausedAt: pausedAt);

      final cachedPlanJson = await _prefsService.getAiDayPlanJson();
      if (cachedPlanJson != null) {
        final parsed = GeminiService.parseScheduleList(cachedPlanJson);
        if (mounted) {
          setState(() {
            _cachedPlan = parsed;
            _isLoadingPlan = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPlan = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[AI Reschedule] Error: $e');
      if (mounted) {
        setState(() {
          _planError = 'Reschedule failed: $e';
          _isLoadingPlan = false;
        });
      }
    }
  }

  Future<void> _togglePauseStateInApp(String activeTitle, int remainingMins) async {
    final nextPaused = !_isPaused;

    await HomeWidget.saveWidgetData<bool>('is_paused', nextPaused);
    await HomeWidget.saveWidgetData<bool>('app_last_known_paused', nextPaused);

    if (nextPaused) {
      final nowStr = DateFormat('hh:mm a').format(DateTime.now());
      await HomeWidget.saveWidgetData<String>('paused_at', nowStr);
      await HomeWidget.saveWidgetData<String>('paused_task_title', activeTitle);
      await HomeWidget.saveWidgetData<int>('paused_remaining_minutes', remainingMins);
      
      setState(() {
        _isPaused = true;
        _pausedAt = nowStr;
        _pausedTaskTitle = activeTitle;
        _pausedRemainingMins = remainingMins;
      });

      // Skip AI reschedule when pausing. Toggles paused states with zero latency!
      await WidgetSyncService.runBackgroundReschedule(action: 'pause', pausedAt: nowStr);
    } else {
      await HomeWidget.saveWidgetData<String>('paused_at', '');
      
      setState(() {
        _isPaused = false;
        _pausedAt = '';
      });

      // Run AI reschedule on resume!
      await _runAiReschedule(action: 'resume');
    }
  }

  Widget _buildActiveTaskControlBlock(Map<String, dynamic> ongoingBlock) {
    final activeTitle = _isPaused && _pausedTaskTitle.isNotEmpty
        ? _pausedTaskTitle
        : (ongoingBlock['work'] ?? 'Study Session');
    final activeTimeSlot = ongoingBlock['time'] ?? '';
    
    final activeCategory = activeTitle.contains("Study") || activeTitle.contains("Lecture")
        ? "Course Study"
        : activeTitle.contains("Assignment") || activeTitle.contains("Project")
            ? "Task Focus"
            : activeTitle.contains("Break") || activeTitle.contains("Lunch") || activeTitle.contains("Dinner")
                ? "Relaxation"
                : "Routine Activity";

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    int remainingMins = _isPaused && _pausedRemainingMins > 0 ? _pausedRemainingMins : 60;
    if (!_isPaused) {
      final rangeParts = activeTimeSlot.split('-');
      if (rangeParts.length >= 2) {
        final end = _parseTimeToMinutes(rangeParts[1]);
        remainingMins = end - currentMinutes;
        if (remainingMins < 0) remainingMins = 0;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _isOngoingExpanded = false;
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isPaused 
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : const Color(0xFF7C3AED).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isPaused 
                                ? Colors.redAccent.withValues(alpha: 0.3)
                                : const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _isPaused ? 'Paused' : 'LIVE NOW',
                          style: TextStyle(
                            color: _isPaused ? Colors.redAccent : const Color(0xFFC4B5FD),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activeTimeSlot,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activeTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        activeCategory == "Course Study"
                            ? Icons.menu_book
                            : activeCategory == "Task Focus"
                                ? Icons.check_box
                                : Icons.schedule,
                        size: 13,
                        color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activeCategory,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isPaused) ...[
                  Text(
                    'Paused at $_pausedAt',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Ends in ${remainingMins}m',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _togglePauseStateInApp(activeTitle, remainingMins),
            child: Container(
              width: 72,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isPaused ? const Color(0xFF10B981) : const Color(0xFF7C3AED),
                      boxShadow: [
                        BoxShadow(
                          color: (_isPaused ? const Color(0xFF10B981) : const Color(0xFF7C3AED))
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPaused ? 'IN' : 'OUT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isPaused ? const Color(0xFF10B981) : const Color(0xFFC4B5FD),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _performSearch() {
    final query = _searchController.text;
    final hasQuery = query.trim().isNotEmpty;
    final hasDates = _selectedDates.isNotEmpty;
    final hasFilters = _selectedFilters.isNotEmpty;

    if (hasQuery || hasDates || hasFilters) {
      setState(() => _showSearchResults = true);
      Provider.of<IntelligenceProvider>(
        context,
        listen: false,
      ).search(
        query,
        dates: _selectedDates,
        types: _selectedFilters.where((f) => f != 'Yet to Complete').toList(),
        yetToCompleteOnly: _selectedFilters.contains('Yet to Complete'),
      );
    } else {
      setState(() => _showSearchResults = false);
      Provider.of<IntelligenceProvider>(context, listen: false).clearSearch();
    }
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
    _performSearch();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: AppTheme.darkTheme.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.tealAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final exists = _selectedDates.any((d) =>
          d.year == picked.year && d.month == picked.month && d.day == picked.day);
      if (!exists) {
        setState(() {
          _selectedDates.add(picked);
        });
        _performSearch();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        actions: [
          _buildHeaderIconButton(
            icon: Icons.edit_note,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FolderListScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _buildHeaderIconButton(
            icon: Icons.settings,
            hasBadge: false,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const NotificationSettingsDialog(),
              ).then((_) => _checkAndGeneratePlan());
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<IntelligenceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = provider.insightsData;
          if (stats == null) {
            return const Center(child: Text('No data available.'));
          }

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                // Stats Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                      return Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF15151D),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: isLandscape
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Row(
                                      children: [
                                        Expanded(flex: 4, child: _buildOverallScore(stats)),
                                        const SizedBox(width: 24),
                                        Expanded(flex: 5, child: _buildCategoryColumn(stats)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  Expanded(
                                    flex: 5,
                                    child: _buildAIDayPlanSection(isLandscape: true),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(flex: 4, child: _buildOverallScore(stats)),
                                      const SizedBox(width: 24),
                                      Expanded(flex: 5, child: _buildCategoryColumn(stats)),
                                    ],
                                  ),
                                  _buildAIDayPlanSection(isLandscape: false),
                                ],
                              ),
                      );
                    },
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF15151D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search tasks, courses...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                 if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.clearSearch();
                                      setState(() {
                                        _showSearchResults = false;
                                        _selectedDates.clear();
                                        _selectedFilters.clear();
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: _selectedDates.isNotEmpty
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[400],
                                  ),
                                  onPressed: _selectDate,
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.filter_list,
                                    color: _selectedFilters.isNotEmpty
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey[400],
                                  ),
                                  onSelected: _toggleFilter,
                                  itemBuilder: (BuildContext context) {
                                    return _filters.map((String choice) {
                                      return CheckedPopupMenuItem<String>(
                                        value: choice,
                                        checked: _selectedFilters.contains(choice),
                                        child: Text(choice),
                                      );
                                    }).toList();
                                  },
                                ),
                              ],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onChanged: (value) {
                            _performSearch();
                          },
                        ),
                      ),
                      if (_selectedFilters.isNotEmpty || _selectedDates.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [
                              ..._selectedDates.map((date) {
                                return Chip(
                                  label: Text(
                                    DateFormat('MMM d, y').format(date),
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedDates.remove(date);
                                    });
                                    _performSearch();
                                  },
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.2),
                                  avatar: const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                );
                              }),
                              ..._selectedFilters.map((filter) {
                                return Chip(
                                  label: Text(filter),
                                  onDeleted: () => _toggleFilter(filter),
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.2),
                                );
                              }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Content Area (Results OR Timeline)
                if (_showSearchResults)
                  _buildSearchResults(provider)
                else ...[
                  _buildTimelineHeader(),
                  _buildAgendaList(stats),
                ],
                const SizedBox(height: 120),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderIconButton({required IconData icon, required VoidCallback onTap, bool hasBadge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF15151D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (hasBadge)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(IntelligenceProvider provider) {
    if (provider.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = provider.searchResults;

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No results found.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final result = results[index];
        return GlassContainer(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.white,
          opacity: 0.05,
          border: Border.all(color: Colors.white12),
          child: ListTile(
            leading: _getIconForType(result.type),
            title: Text(
              result.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(result.subtitle),
            trailing: Text(
              result.type,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            onTap: () {
              _navigateToDetail(context, result);
            },
          ),
        );
      },
    );
  }

  // Navigation Logic
  void _navigateToDetail(BuildContext context, SearchResult result) {
    final int? id = int.tryParse(result.id);
    if (id == null) return;

    switch (result.type) {
      case 'Task':
        if (result.date != null) {
          final taskProvider = Provider.of<TaskProvider>(context, listen: false);
          taskProvider.onDaySelected(result.date!, result.date!);
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlannerScreen()),
        );
        break;
      case 'Assignment':
        // Go to Assignment Add/Edit (Edit mode)
        // We need an Assignment object or just ID.
        // Assuming AssignmentAddEditScreen takes an assignment object or id.
        // Let's check AssignmentAddEditScreen wrapper or similar.
        // If not readily available, we might default to AssignmentList.
        // Better: Open AssignmentListScreen.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssignmentListScreen()),
        );
        break;
      case 'Course':
        // Go to Course Detail
        // We need to fetch the course or pass ID.
        // CourseDetailScreen usually takes a Course object.
        // We might need to fetch it first? Or does it take ID?
        // Let's assume we navigate to CourseList for now to be safe,
        // OR try to fetch.
        // Simpler: CourseListScreen.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CourseListScreen()),
        );
        break;
      case 'Event':
        // Go to Hackathon Detail
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HackathonListScreen()),
        );
        break;
    }
  }

  Widget _buildOverallScore(InsightsData stats) {
    int totalCompleted =
        stats.completedCourses +
        stats.completedTasks +
        stats.completedAssignments +
        stats.completedEvents;

    final now = DateTime.now();
    bool isFutureOrToday(DateTime? date) {
      if (date == null) return true;
      final todayStart = DateTime(now.year, now.month, now.day);
      return date.isAfter(now) ||
          (date.year == todayStart.year &&
              date.month == todayStart.month &&
              date.day == todayStart.day);
    }

    int validPendingTasks = stats.pendingTasks
        .where((t) => isFutureOrToday(t.dueDate))
        .length;
    int validPendingAssignments = stats.pendingAssignments
        .where((a) => isFutureOrToday(a.dueDate))
        .length;
    int totalPendingActive =
        stats.activeCourses.length +
        validPendingTasks +
        validPendingAssignments +
        stats.upcomingEvents.length;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showStatsPopup(context, stats),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CircularProgressIndicator(
                value: stats.overallScore / 100,
                strokeWidth: 14,
                backgroundColor: const Color(0xFF1E1E28),
                color: const Color(0xFF7C3AED),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$totalCompleted : $totalPendingActive',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Completion Rate',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stats.overallScore.toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFFC4B5FD),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatsPopup(BuildContext context, InsightsData stats) async {
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          child: AlertDialog(
            title: const Text('Details'),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Colors.tealAccent,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.tealAccent,
                    tabs: [
                      Tab(text: 'Completed'),
                      Tab(text: 'Active/Pending'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCompletedTab(),
                        _buildActivePendingTab(stats),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivePendingTab(InsightsData stats) {
    final Map<String, List<dynamic>> activeItems = {
      'Courses': stats.activeCourses,
      'Tasks': stats.pendingTasks.where((t) {
        if (t.dueDate == null) return true;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        return t.dueDate!.isAfter(now) || (t.dueDate!.year == todayStart.year && t.dueDate!.month == todayStart.month && t.dueDate!.day == todayStart.day);
      }).toList(),
      'Assignments': stats.pendingAssignments.where((a) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        return a.dueDate.isAfter(now) || (a.dueDate.year == todayStart.year && a.dueDate.month == todayStart.month && a.dueDate.day == todayStart.day);
      }).toList(),
      'Events': stats.upcomingEvents,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: activeItems.entries.expand((entry) {
        if (entry.value.isEmpty) return <Widget>[];
        return [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.tealAccent)),
          ),
          ...entry.value.map((item) => ListTile(
            dense: true,
            title: Text(item.title ?? item.name ?? 'Item'),
            subtitle: Text(item.description ?? ''),
          )),
        ];
      }).toList(),
    );
  }

  Widget _buildCompletedTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchCompletedItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No completed items.'));
        }
        
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var row in snapshot.data!) {
          grouped.putIfAbsent(row['type'], () => []).add(row);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: grouped.entries.expand((entry) {
            return [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.tealAccent)),
              ),
              ...entry.value.map((item) => ListTile(
                dense: true,
                title: Text(item['title'] ?? ''),
                subtitle: Text(item['subtitle'] ?? ''),
              )),
            ];
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCompletedItems() async {
    final db = await DatabaseHelper.instance.database;
    final results = <Map<String, dynamic>>[];
    
    final tasks = await db.query('tasks', where: 'is_completed = 1');
    for (var t in tasks) {
      results.add({'type': 'Tasks', 'title': t['title'], 'subtitle': t['description']});
    }
    
    final assignments = await db.query('assignments', where: 'is_completed = 1');
    for (var a in assignments) {
      results.add({'type': 'Assignments', 'title': a['title'], 'subtitle': a['subject']});
    }
    
    final courses = await db.query('courses', where: 'status = ?', whereArgs: ['Completed']);
    for (var c in courses) {
      results.add({'type': 'Courses', 'title': c['title'], 'subtitle': c['description']});
    }
    
    final events = await DatabaseHelper.instance.getAllHackathons();
    final now = DateTime.now();
    for (var map in events) {
      String? endDateStr = map['end_date'] as String?;
      DateTime? endDate;
      if (endDateStr != null && endDateStr.isNotEmpty) {
        endDate = DateTime.tryParse(endDateStr);
      } else {
        endDate = DateTime.tryParse(map['start_date'] as String);
      }
      bool isPast = endDate != null && endDate.isBefore(now);
      if (isPast) results.add({'type': 'Events', 'title': map['name'], 'subtitle': map['description']});
    }
    
    return results;
  }

  int _selectedAgendaIndex = 0; // 0 for Today, 1 for Tomorrow
  Widget _buildTimelineHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Text(
            'Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF15151D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTimelineTab(0, 'Today'),
                _buildTimelineTab(1, 'Tomorrow'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(int index, String label) {
    final isSelected = _selectedAgendaIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAgendaIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[500],
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusing _buildCategoryColumn, _buildCompactStatCard, _buildAgendaList from previous context
  // but need to ensure 'Agenda' labels are updated to 'Timeline' if used inside them.
  // Actually, _buildAgendaList implementation is generic enough.
  // just need to include them in the replacement content to be safe or rely on merging.
  // Since I am replacing a huge block, I should probably include them.

  Widget _buildCategoryColumn(InsightsData stats) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCompactStatCard(
          'Courses',
          stats.completedCourses,
          stats.totalCourses,
          const Color(0xFF3B82F6),
          Icons.menu_book,
        ),
        const SizedBox(height: 8),
        _buildCompactStatCard(
          'Tasks',
          stats.completedTasks,
          stats.totalTasks,
          const Color(0xFF10B981),
          Icons.check_box,
        ),
        const SizedBox(height: 8),
        _buildCompactStatCard(
          'Assignments',
          stats.completedAssignments,
          stats.totalAssignments,
          const Color(0xFF8B5CF6),
          Icons.assignment,
        ),
        const SizedBox(height: 8),
        _buildCompactStatCard(
          'Events',
          stats.completedEvents,
          stats.totalEvents,
          const Color(0xFFF59E0B),
          Icons.emoji_events,
        ),
      ],
    );
  }

  Widget _buildCompactStatCard(
    String title,
    int completed,
    int total,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A), // Very dark
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.white)),
            ],
          ),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // existing _buildAgendaHeader is replaced by _buildTimelineHeader above
  // but I still need _buildAgendaList

  Widget _buildAgendaList(InsightsData stats) {
    final items = _selectedAgendaIndex == 0
        ? stats.agendaToday
        : stats.agendaTomorrow;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                        blurRadius: 40,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.event_available,
                  size: 100,
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.8),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _selectedAgendaIndex == 0
                  ? 'No tasks scheduled for today!'
                  : 'Nothing scheduled for tomorrow yet.',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your free time or add a new task.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),

            const SizedBox(height: 20),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF15151D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            leading: _getIconForType(item.type),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(item.subtitle, style: TextStyle(color: Colors.grey[400])),
            trailing: item.time != null
                ? Text(
                    DateFormat.Hm().format(item.time!),
                    style: TextStyle(color: Colors.grey[500]),
                  )
                : null,
            onTap: () {
              final defaultDate = _selectedAgendaIndex == 0
                  ? DateTime.now()
                  : DateTime.now().add(const Duration(days: 1));
              _navigateToDetail(
                context,
                SearchResult(
                  id: item.id.toString(),
                  title: item.title,
                  subtitle: item.subtitle,
                  type: item.type,
                  date: item.time ?? defaultDate,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Icon _getIconForType(String type) {
    switch (type) {
      case 'Task':
        return const Icon(Icons.check_circle_outline, color: Colors.teal);
      case 'Assignment':
        return const Icon(Icons.assignment, color: Colors.purple);
      case 'Event':
        return const Icon(Icons.event, color: Colors.orange);
      case 'Course': // for search results
        return const Icon(Icons.school, color: Colors.blue);
      default:
        return const Icon(Icons.circle, size: 12, color: Colors.grey);
    }
  }

  Widget _buildAIDayPlanSection({bool isLandscape = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isLandscape)
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tap heading to open chatbot edit screen
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrePlannerScreen(),
                  ),
                ).then((refresh) {
                  if (refresh == true) {
                    _checkAndGeneratePlan();
                  }
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Plan My Day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            
            // Holiday Toggle and Refresh Button Row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.celebration,
                  size: 13,
                  color: Colors.amberAccent,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Holiday',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  height: 20,
                  width: 38,
                  child: Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: _isTodayHoliday,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) async {
                        final today = DateTime.now();
                        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                        
                        await _prefsService.setManualHolidayOverride(dateStr, val);
                        
                        setState(() {
                          _isTodayHoliday = val;
                        });
                        
                        await _prefsService.clearAiDayPlan();
                        final apiKey = await _prefsService.getGeminiApiKey();
                        if (apiKey != null && apiKey.trim().isNotEmpty) {
                          _generateAiPlanToday(apiKey);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isLoadingPlan)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      final apiKey = await _prefsService.getGeminiApiKey();
                      if (apiKey != null && apiKey.trim().isNotEmpty) {
                        _generateAiPlanToday(apiKey);
                      } else {
                        setState(() {
                          _planError = 'Please configure your Gemini API Key in Settings to enable the AI Day Planner.';
                        });
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Drag to left to open full day schedule
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Dismissible(
            key: const Key('ai_day_plan_dismissible'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const FullScheduleScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeOutCubic;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                ).then((_) => _checkAndGeneratePlan());
              }
              return false; // Return false so the card does not get removed from the widget tree
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Full Schedule',
                    style: TextStyle(
                      color: Color(0xFFC4B5FD),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Color(0xFFC4B5FD)),
                ],
              ),
            ),
            child: SlideTransition(
              position: _swipeHintAnimation,
              child: _buildPlannerCardContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlannerCardContent() {
    if (_isLoadingPlan) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
          ),
        ),
        child: const Column(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)),
            ),
            SizedBox(height: 12),
            Text(
              'AI is optimizing your perfect day plan...',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_planError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C0F1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _planError!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.4),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const NotificationSettingsDialog(),
                ).then((_) => _checkAndGeneratePlan());
              },
              child: const Text('Open Settings', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (_cachedPlan == null || _cachedPlan!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F111A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Text(
              'Analyze your courses, pending tasks, assignments, and events to organize your perfect schedule.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              label: const Text('Generate Plan Now', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () async {
                final apiKey = await _prefsService.getGeminiApiKey();
                if (apiKey != null && apiKey.trim().isNotEmpty) {
                  _generateAiPlanToday(apiKey);
                } else {
                  setState(() {
                    _planError = 'Please configure your Gemini API Key in Settings to enable the AI Day Planner.';
                  });
                }
              },
            ),
          ],
        ),
      );
    }

    // Display ongoing + next 2 schedules in tabular format
    final timelineBlocks = _getOngoingAndNextBlocks(_cachedPlan!);

    Map<String, dynamic>? ongoingBlock;
    for (final block in timelineBlocks) {
      if (block['isOngoing'] == true) {
        ongoingBlock = block;
        break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F111A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ongoingBlock != null && _isOngoingExpanded) ...[
            _buildActiveTaskControlBlock(ongoingBlock),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
          ],
          Table(
            columnWidths: const {
              0: FlexColumnWidth(4.5), // Time range
              1: FlexColumnWidth(5.5), // Work/Activity
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: timelineBlocks.where((b) => _isOngoingExpanded ? b['isOngoing'] != true : true).map((block) {
              final bool isOngoing = block['isOngoing'] == true;
              return TableRow(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isOngoing ? () {
                      setState(() {
                        _isOngoingExpanded = true;
                      });
                    } : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          if (isOngoing)
                            Container(
                              width: 3,
                              height: 18,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981), // Neon green for active
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                            ),
                          Expanded(
                            child: Text(
                              block['time'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isOngoing ? FontWeight.bold : FontWeight.normal,
                                color: isOngoing ? const Color(0xFF10B981) : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isOngoing ? () {
                      setState(() {
                        _isOngoingExpanded = true;
                      });
                    } : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            block['work'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isOngoing ? FontWeight.bold : FontWeight.normal,
                              color: isOngoing ? Colors.white : Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (block['options'] != null && (block['options'] as List).isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...(block['options'] as List).map((opt) {
                              final String optionText = opt.toString();
                              final bool isChecked = block['selectedOption'] == optionText;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: InkWell(
                                  onTap: () async {
                                    setState(() {
                                      block['selectedOption'] = optionText;
                                    });
                                    if (_cachedPlan != null) {
                                      await _prefsService.setAiDayPlanJson(jsonEncode(_cachedPlan));
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                                        size: 13,
                                        color: isChecked ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          optionText,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isChecked ? Colors.white : Colors.grey,
                                            fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<DateTime> _getEarliestActivityTime(DateTime now) async {
    DateTime earliest = DateTime(now.year, now.month, now.day, 8, 0); // Default fallback: 8:00 AM
    
    try {
      final routineStr = await _prefsService.getDailyRoutine(date: now);
      final List decodedRoutine = jsonDecode(routineStr);
      
      final prePlannedJson = await _prefsService.getPrePlannedEvents();
      List decodedPrePlanned = [];
      if (prePlannedJson != null) {
        decodedPrePlanned = jsonDecode(prePlannedJson);
      }
      
      DateTime? parseTimeStr(String? timeStr) {
        if (timeStr == null || timeStr.trim().isEmpty) return null;
        try {
          final cleaned = timeStr.trim().toUpperCase();
          final format = DateFormat('h:mm a');
          final parsedDate = format.parse(cleaned);
          return DateTime(now.year, now.month, now.day, parsedDate.hour, parsedDate.minute);
        } catch (_) {
          try {
            final format2 = DateFormat('hh:mm a');
            final parsedDate = format2.parse(timeStr.trim().toUpperCase());
            return DateTime(now.year, now.month, now.day, parsedDate.hour, parsedDate.minute);
          } catch (_) {}
        }
        return null;
      }

      for (final item in decodedRoutine) {
        final timeStr = item['time'] as String?;
        final parsed = parseTimeStr(timeStr);
        if (parsed != null && parsed.isBefore(earliest)) {
          earliest = parsed;
        }
      }

      for (final item in decodedPrePlanned) {
        final timeStr = item['startTime'] as String?;
        final parsed = parseTimeStr(timeStr);
        if (parsed != null && parsed.isBefore(earliest)) {
          earliest = parsed;
        }
      }
    } catch (e) {
      debugPrint('[AI Day Plan] Error finding earliest activity: $e');
    }
    
    return earliest;
  }

  Future<void> _checkAndGeneratePlan() async {
    if (_isLoadingPlan) return;

    final today = DateTime.now();
    final isHoliday = await _prefsService.checkIsHoliday(today);
    if (mounted) {
      setState(() {
        _isTodayHoliday = isHoliday;
      });
    }

    final apiKey = await _prefsService.getGeminiApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _planError = 'Please configure your Gemini API Key in Settings to enable the AI Day Planner.';
          _cachedPlan = null;
        });
      }
      await WidgetSyncService.syncWidget();
      return;
    }

    final now = DateTime.now();
    final todayDateStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Auto-schedule trigger 5 minutes before 1st activity of the day
    final earliestActivityTime = await _getEarliestActivityTime(now);
    final planTriggerTime = earliestActivityTime.subtract(const Duration(minutes: 5));
    final diffInSeconds = planTriggerTime.difference(now).inSeconds;

    // 1. Clears/invalidates cached plan 1-2 minutes prior to the trigger time.
    if (diffInSeconds > 0 && diffInSeconds <= 120) {
      final cachedPlanJson = await _prefsService.getAiDayPlanJson();
      if (cachedPlanJson != null) {
        debugPrint('[AI Day Plan] Within 2 minutes pre-trigger window. Clearing cache.');
        await _prefsService.clearAiDayPlan();
        if (mounted) {
          setState(() {
            _cachedPlan = null;
            _planError = null;
          });
        }
      }
      return;
    }

    // 2. Load cached plan
    final cachedPlanJson = await _prefsService.getAiDayPlanJson();
    final cachedPlanDate = await _prefsService.getAiDayPlanDate();

    if (cachedPlanJson != null && cachedPlanDate == todayDateStr) {
      try {
        final parsed = GeminiService.parseScheduleList(cachedPlanJson);
        if (mounted) {
          setState(() {
            _cachedPlan = parsed;
            _planError = null;
          });
        }
      } catch (e) {
        debugPrint('[AI Day Plan] Error parsing cached plan: $e');
      }
    } else {
      // No plan for today in cache
      // 3. Automatically plans the day at 5 minutes before 1st activity.
      if (now.isAfter(planTriggerTime) || now.isAtSameMomentAs(planTriggerTime)) {
        debugPrint('[AI Day Plan] Past notification trigger time. Auto-generating plan.');
        _generateAiPlanToday(apiKey);
      } else {
        if (mounted) {
          setState(() {
            _cachedPlan = null;
            _planError = null;
          });
        }
      }
    }
    await WidgetSyncService.syncWidget();
  }

  Future<void> _generateAiPlanToday(String apiKey) async {
    if (mounted) {
      setState(() {
        _isLoadingPlan = true;
        _planError = null;
      });
    }

    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Prioritize explicit overrides
      bool isHoliday = await _prefsService.checkIsHoliday(today);
      final manualOverride = await _prefsService.getManualHolidayOverride(dateStr);
      if (manualOverride == null) {
        await _prefsService.setManualHolidayOverride(dateStr, isHoliday);
      }

      if (mounted) {
        setState(() {
          _isTodayHoliday = isHoliday;
        });
      }

      final routineStr = await _prefsService.getDailyRoutine(date: today);
      final List decodedRoutine = jsonDecode(routineStr);
      final List<Map<String, dynamic>> routineList =
          decodedRoutine.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (!mounted) return;
      final provider = Provider.of<IntelligenceProvider>(context, listen: false);
      final stats = provider.insightsData;
      if (stats == null) {
        throw Exception('Academic data not loaded yet. Please wait.');
      }

      final todayStart = DateTime(today.year, today.month, today.day);

      // Load Pre-planned events
      final eventsJson = await _prefsService.getPrePlannedEvents();
      List<Map<String, dynamic>> customEvents = [];
      if (eventsJson != null) {
        try {
          final List decoded = jsonDecode(eventsJson);
          customEvents = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (e) {
          debugPrint('[AI Day Plan] Error decoding pre-planned events: $e');
        }
      }

      // 4. Gather only active items (exclude if end-dated / past due)
      final coursesMap = stats.activeCourses.map((c) => {
        'title': c.title,
        'description': c.description ?? '',
      }).toList();

      final tasksMap = stats.pendingTasks.where((t) {
        if (t.dueDate == null) return true;
        final taskDate = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        return !taskDate.isBefore(todayStart);
      }).map((t) => {
        'title': t.title,
        'description': t.description ?? '',
      }).toList();

      final assignmentsMap = stats.pendingAssignments.where((a) {
        final assignmentDate = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
        return !assignmentDate.isBefore(todayStart);
      }).map((a) => {
        'title': a.title,
        'description': a.description ?? '',
        'subject': a.subject ?? '',
        'type': a.type,
      }).toList();

      final eventsMap = stats.upcomingEvents.where((e) {
        final compareDate = e.endDate ?? e.startDate;
        final eventDate = DateTime(compareDate.year, compareDate.month, compareDate.day);
        return !eventDate.isBefore(todayStart);
      }).map((e) => {
        'name': e.name,
        'description': e.description ?? '',
      }).toList();

      final newPlan = await GeminiService.generatePlan(
        apiKey: apiKey,
        routine: routineList,
        tasks: tasksMap,
        courses: coursesMap,
        assignments: assignmentsMap,
        events: eventsMap,
        prePlannedEvents: customEvents,
      );

      final newPlanJson = jsonEncode(newPlan);
      final now = DateTime.now();
      final todayDateStr = DateFormat('yyyy-MM-dd').format(now);

      await _prefsService.setAiDayPlanJson(newPlanJson);
      await _prefsService.setAiDayPlanDate(todayDateStr);
      await _prefsService.setAiDayPlanTimestamp(now.millisecondsSinceEpoch.toString());

      if (mounted) {
        setState(() {
          _cachedPlan = newPlan;
          _isLoadingPlan = false;
        });
      }

      // Show immediate notification
      try {
        final service = NotificationService();
        await service.flutterLocalNotificationsPlugin.show(
          id: 99998,
          title: 'Plan My Day Ready! ⚡',
          body: 'Your AI has crafted today\'s optimized schedule. Swipe to view!',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'todo_persistent_channel',
              'To-Do Alerts',
              channelDescription: 'Reminders for daily plans',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'ic_notification',
            ),
          ),
        );
      } catch (notifErr) {
        debugPrint('[AI Day Plan] Error triggering notification: $notifErr');
      }
      await WidgetSyncService.syncWidget();
    } catch (e) {
      debugPrint('Error generating plan: $e');
      if (mounted) {
        setState(() {
          _planError = 'Error generating daily plan: $e';
          _isLoadingPlan = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getOngoingAndNextBlocks(List<Map<String, dynamic>> schedule) {
    final now = DateTime.now();
    
    DateTime? parseTime(String tStr) {
      try {
        tStr = tStr.trim().toUpperCase();
        final ampmParts = tStr.split(' ');
        final hmParts = ampmParts[0].split(':');
        int hour = int.parse(hmParts[0]);
        int minute = int.parse(hmParts[1]);
        if (ampmParts.length > 1) {
          final ampm = ampmParts[1];
          if (ampm == 'PM' && hour != 12) hour += 12;
          if (ampm == 'AM' && hour == 12) hour = 0;
        }
        return DateTime(now.year, now.month, now.day, hour, minute);
      } catch (_) {
        return null;
      }
    }

    List<Map<String, dynamic>> blocksWithTimes = [];
    for (var block in schedule) {
      final timeRange = block['time'] as String? ?? '';
      final parts = timeRange.split('-');
      DateTime? start;
      DateTime? end;
      if (parts.length == 2) {
        start = parseTime(parts[0]);
        end = parseTime(parts[1]);
      }
      blocksWithTimes.add({
        'block': block,
        'start': start,
        'end': end,
      });
    }

    blocksWithTimes.sort((a, b) {
      final aStart = a['start'] as DateTime?;
      final bStart = b['start'] as DateTime?;
      if (aStart == null && bStart == null) return 0;
      if (aStart == null) return 1;
      if (bStart == null) return -1;
      return aStart.compareTo(bStart);
    });

    int ongoingIdx = -1;
    for (int i = 0; i < blocksWithTimes.length; i++) {
      final start = blocksWithTimes[i]['start'] as DateTime?;
      final end = blocksWithTimes[i]['end'] as DateTime?;
      if (start != null && end != null) {
        if (now.isAfter(start) && now.isBefore(end)) {
          ongoingIdx = i;
          break;
        }
      }
    }

    List<Map<String, dynamic>> results = [];
    if (ongoingIdx != -1) {
      final ongoingBlock = Map<String, dynamic>.from(blocksWithTimes[ongoingIdx]['block'] as Map);
      ongoingBlock['isOngoing'] = true;
      results.add(ongoingBlock);

      int count = 0;
      for (int i = ongoingIdx + 1; i < blocksWithTimes.length; i++) {
        if (count < 2) {
          final nextBlock = Map<String, dynamic>.from(blocksWithTimes[i]['block'] as Map);
          nextBlock['isOngoing'] = false;
          results.add(nextBlock);
          count++;
        }
      }
    } else {
      int count = 0;
      for (int i = 0; i < blocksWithTimes.length; i++) {
        final start = blocksWithTimes[i]['start'] as DateTime?;
        if (start != null && start.isAfter(now)) {
          if (count < 3) {
            final nextBlock = Map<String, dynamic>.from(blocksWithTimes[i]['block'] as Map);
            nextBlock['isOngoing'] = false;
            results.add(nextBlock);
            count++;
          }
        }
      }
      if (results.isEmpty && blocksWithTimes.isNotEmpty) {
        final startIdx = blocksWithTimes.length > 3 ? blocksWithTimes.length - 3 : 0;
        for (int i = startIdx; i < blocksWithTimes.length; i++) {
          final block = Map<String, dynamic>.from(blocksWithTimes[i]['block'] as Map);
          block['isOngoing'] = false;
          results.add(block);
        }
      }
    }

    return results;
  }
}

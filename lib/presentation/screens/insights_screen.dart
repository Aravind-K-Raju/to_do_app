import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/intelligence_provider.dart';
import '../../domain/entities/insights_data.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_settings_dialog.dart';
import '../../core/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<IntelligenceProvider>(
        context,
        listen: false,
      ).loadStatsForToday();
    });
  }

  final TextEditingController _searchController = TextEditingController();
  bool _showSearchResults = false;
  final List<String> _filters = ['Task', 'Assignment', 'Course', 'Event'];
  final List<String> _selectedFilters = [];
  DateTime? _selectedDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilter(String filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights v1.0.1.3'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const NotificationSettingsDialog(),
              );
            },
          ),
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

          return Column(
            children: [
              // Stats Section (Always Visible)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: _buildOverallScore(stats)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCategoryColumn(stats)),
                  ],
                ),
              ),
              const Divider(),

              // Search Bar (Moved Here)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tasks, courses...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  provider.clearSearch();
                                  setState(() {
                                    _showSearchResults = false;
                                    _selectedDate = null;
                                    _selectedFilters.clear();
                                  });
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.calendar_today,
                                color: _selectedDate != null
                                    ? Theme.of(context).primaryColor
                                    : null,
                              ),
                              onPressed: _selectDate,
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.filter_list,
                                color: _selectedFilters.isNotEmpty
                                    ? Theme.of(context).primaryColor
                                    : null,
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (value) {
                        if (value.trim().isNotEmpty) {
                          setState(() {
                            _showSearchResults = true;
                          });
                          provider.search(value);
                        } else {
                          setState(() {
                            _showSearchResults = false;
                          });
                          provider.clearSearch();
                        }
                      },
                    ),
                    if (_selectedFilters.isNotEmpty || _selectedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Wrap(
                          spacing: 8.0,
                          children: [
                            if (_selectedDate != null)
                              Chip(
                                label: Text(
                                  DateFormat('MMM d, y').format(_selectedDate!),
                                ),
                                onDeleted: () {
                                  setState(() {
                                    _selectedDate = null;
                                  });
                                },
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.2),
                                avatar: const Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                              ),
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
                Expanded(child: _buildSearchResults(provider))
              else ...[
                _buildTimelineHeader(),
                Expanded(child: _buildAgendaList(stats)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(IntelligenceProvider provider) {
    if (provider.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final results = provider.searchResults.where((result) {
      // 1. Filter by Type
      if (_selectedFilters.isNotEmpty &&
          !_selectedFilters.contains(result.type)) {
        return false;
      }

      // 2. Filter by Date
      if (_selectedDate != null) {
        if (result.date == null) return false;
        return result.date!.year == _selectedDate!.year &&
            result.date!.month == _selectedDate!.month &&
            result.date!.day == _selectedDate!.day;
      }

      return true;
    }).toList();

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
      itemBuilder: (context, index) {
        final result = results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.grey[900],
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
              // Handle navigation if needed
            },
          ),
        );
      },
    );
  }

  Widget _buildOverallScore(InsightsData stats) {
    // Calculate Total Completed
    int totalCompleted =
        stats.completedCourses +
        stats.completedTasks +
        stats.completedAssignments +
        stats.completedEvents;

    // Calculate Total Pending/Active (strictly per user definition: not completed AND not overdue)
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
    // Courses are active by status, Events are upcoming by logic
    int totalPendingActive =
        stats.activeCourses.length +
        validPendingTasks +
        validPendingAssignments +
        stats.upcomingEvents.length;

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CircularProgressIndicator(
              value: stats.overallScore / 100,
              strokeWidth: 12,
              backgroundColor: Colors.grey[800],
              color: _getScoreColor(stats.overallScore),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$totalCompleted / $totalPendingActive',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Completion Rate',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
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
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Today')),
              ButtonSegment(value: 1, label: Text('Tomorrow')),
            ],
            selected: {_selectedAgendaIndex},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _selectedAgendaIndex = newSelection.first;
              });
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
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
          Colors.blue,
        ),
        const SizedBox(height: 8),
        _buildCompactStatCard(
          'Tasks',
          stats.completedTasks,
          stats.totalTasks,
          Colors.teal,
        ),
        const SizedBox(height: 8),
        _buildCompactStatCard(
          'Assignments',
          stats.completedAssignments,
          stats.totalAssignments,
          Colors.purple,
        ),
        const SizedBox(height: 8),
        _buildCompactStatCard(
          'Events',
          stats.completedEvents,
          stats.totalEvents,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildCompactStatCard(
    String title,
    int completed,
    int total,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
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
            Icon(Icons.event_available, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              _selectedAgendaIndex == 0
                  ? 'No tasks scheduled for today!'
                  : 'Nothing scheduled for tomorrow yet.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.grey[900],
          child: ListTile(
            leading: _getIconForType(item.type),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(item.subtitle),
            trailing: item.time != null
                ? Text(
                    DateFormat.Hm().format(item.time!),
                    style: TextStyle(color: Colors.grey[400]),
                  )
                : null,
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

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}

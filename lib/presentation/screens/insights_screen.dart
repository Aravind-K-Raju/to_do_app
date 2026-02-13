import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/intelligence_provider.dart';
import '../../domain/entities/insights_data.dart';
import 'package:intl/intl.dart';
import '../widgets/notification_settings_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProductivityScore(stats.overallScore),
                const SizedBox(height: 24),
                _buildStatsGrid(stats),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showPendingItems(context, stats),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View Pending Items & Active Courses'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
                if (provider.currentStats != null)
                  _buildDailyStats(provider.currentStats!),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductivityScore(double score) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 16,
              backgroundColor: Colors.grey[800],
              color: _getScoreColor(score),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(score),
                ),
              ),
              const Text(
                'Overall Score',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _buildStatsGrid(InsightsData stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildStatCard(
          'Courses',
          stats.completedCourses,
          stats.totalCourses,
          Colors.blueAccent,
        ),
        _buildStatCard(
          'Tasks',
          stats.completedTasks,
          stats.totalTasks,
          Colors.tealAccent,
        ),
        _buildStatCard(
          'Assignments',
          stats.completedAssignments,
          stats.totalAssignments,
          Colors.purpleAccent,
        ),
        _buildStatCard(
          'Events',
          stats.completedEvents,
          stats.totalEvents,
          Colors.orangeAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int completed, int total, Color color) {
    double progress = total == 0 ? 0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completed',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                ' / $total',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  void _showPendingItems(BuildContext context, InsightsData stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Tasks'),
                Tab(text: 'Assignments'),
                Tab(text: 'Courses'),
                Tab(text: 'Events'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPendingList(
                    stats.pendingTasks,
                    (t) => ListTile(
                      title: Text(t.title),
                      subtitle: Text(
                        t.dueDate != null
                            ? 'Due: ${DateFormat.yMMMd().format(t.dueDate!)}'
                            : 'No Due Date',
                      ),
                      trailing: const Icon(Icons.check_circle_outline),
                    ),
                  ),
                  _buildPendingList(
                    stats.pendingAssignments,
                    (a) => ListTile(
                      title: Text(a.title),
                      subtitle: Text(
                        '${a.type} - ${DateFormat.yMMMd().format(a.dueDate)}',
                      ),
                    ),
                  ),
                  _buildPendingList(
                    stats.activeCourses,
                    (c) => ListTile(
                      title: Text(c.title),
                      subtitle: Text('${c.sourceName} - ${c.status}'),
                      trailing: Text('${c.progressPercent}%'),
                    ),
                  ),
                  _buildPendingList(
                    stats.upcomingEvents,
                    (e) => ListTile(
                      title: Text(e.name),
                      subtitle: Text(
                        'Starts: ${DateFormat.yMMMd().format(e.startDate)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList<T>(List<T> items, Widget Function(T) itemBuilder) {
    if (items.isEmpty) {
      return const Center(child: Text('No pending items. Great job!'));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => itemBuilder(items[index]),
    );
  }

  Widget _buildDailyStats(var dailyStats) {
    return Card(
      color: Colors.white10,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  '${dailyStats.studyMinutes}m',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Study Today'),
              ],
            ),
            Column(
              children: [
                Text(
                  '${dailyStats.tasksCompleted}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Tasks Done'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

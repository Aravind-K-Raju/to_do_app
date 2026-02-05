import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/intelligence_provider.dart';

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
      appBar: AppBar(title: const Text('Insights')),
      body: Consumer<IntelligenceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = provider.currentStats;
          if (stats == null) {
            return const Center(child: Text('No data for today.'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildScoreCard(stats.productivityScore),
                const SizedBox(height: 24),
                _buildStatRow('Tasks Completed', '${stats.tasksCompleted}'),
                _buildStatRow('Tasks Pending', '${stats.tasksPending}'),
                _buildStatRow('Study Time', '${stats.studyMinutes} min'),
                const Divider(height: 32),
                Text(
                  _getMotivationalMessage(stats.productivityScore),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.tealAccent,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreCard(double score) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Productivity Score',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            score.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey[800],
            color: Colors.tealAccent,
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _getMotivationalMessage(double score) {
    if (score >= 80) return 'Outstanding focus today! 🚀';
    if (score >= 50) return 'Good progress, keep it up! 👍';
    return 'Let\'s get to work! 💪';
  }
}

import '../entities/daily_stats.dart';
import '../entities/insights_data.dart';
import '../entities/search_result.dart';

abstract class IntelligenceRepository {
  Future<DailyStats> getDailyStats(DateTime date);
  Future<InsightsData> getInsightsData();
  Future<List<SearchResult>> search(
    String query, {
    DateTime? date,
    String? type,
  });
}

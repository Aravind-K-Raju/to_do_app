import '../entities/daily_stats.dart';
import '../entities/insights_data.dart';

abstract class IntelligenceRepository {
  Future<DailyStats> getDailyStats(DateTime date);
  Future<InsightsData> getInsightsData();
}

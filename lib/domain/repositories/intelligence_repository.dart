import '../entities/daily_stats.dart';

abstract class IntelligenceRepository {
  Future<DailyStats> getDailyStats(DateTime date);
}

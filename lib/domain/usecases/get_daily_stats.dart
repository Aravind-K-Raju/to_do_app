import '../entities/daily_stats.dart';
import '../repositories/intelligence_repository.dart';

class GetDailyStats {
  final IntelligenceRepository repository;
  GetDailyStats(this.repository);
  Future<DailyStats> call(DateTime date) async =>
      await repository.getDailyStats(date);
}

import '../repositories/intelligence_repository.dart';
import '../entities/insights_data.dart';

class GetInsightsData {
  final IntelligenceRepository repository;

  GetInsightsData(this.repository);

  Future<InsightsData> call() async {
    return await repository.getInsightsData();
  }
}

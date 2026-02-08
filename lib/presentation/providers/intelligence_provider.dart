import 'package:flutter/material.dart';
import '../../domain/entities/daily_stats.dart';
import '../../domain/entities/insights_data.dart';
import '../../domain/usecases/get_daily_stats.dart';
import '../../domain/usecases/get_insights_data.dart';

class IntelligenceProvider extends ChangeNotifier {
  final GetDailyStats getDailyStats;
  final GetInsightsData?
  getInsightsData; // Optional for now to not break main if not passed immediately, but we will fix main

  IntelligenceProvider({required this.getDailyStats, this.getInsightsData});

  DailyStats? _currentStats;
  DailyStats? get currentStats => _currentStats;

  InsightsData? _insightsData;
  InsightsData? get insightsData => _insightsData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadStatsForToday() async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentStats = await getDailyStats(DateTime.now());
      if (getInsightsData != null) {
        _insightsData = await getInsightsData!();
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

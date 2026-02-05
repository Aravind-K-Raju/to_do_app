import 'package:flutter/material.dart';
import '../../domain/entities/daily_stats.dart';
import '../../domain/usecases/get_daily_stats.dart';

class IntelligenceProvider extends ChangeNotifier {
  final GetDailyStats getDailyStats;

  IntelligenceProvider({required this.getDailyStats});

  DailyStats? _currentStats;
  DailyStats? get currentStats => _currentStats;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadStatsForToday() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Just today for now
      _currentStats = await getDailyStats(DateTime.now());
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

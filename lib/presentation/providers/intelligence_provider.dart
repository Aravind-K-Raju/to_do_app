import 'package:flutter/material.dart';
import '../../domain/entities/daily_stats.dart';
import '../../domain/entities/insights_data.dart';
import '../../domain/usecases/get_daily_stats.dart';
import '../../domain/usecases/get_insights_data.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/intelligence_repository.dart';

class IntelligenceProvider extends ChangeNotifier {
  final GetDailyStats getDailyStats;
  final GetInsightsData? getInsightsData;
  final IntelligenceRepository? repository;

  IntelligenceProvider({
    required this.getDailyStats,
    this.getInsightsData,
    this.repository,
  });

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

  // Search Logic
  List<SearchResult> _searchResults = [];
  List<SearchResult> get searchResults => _searchResults;
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  Future<void> search(String query) async {
    if (repository == null) return;

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await repository!.search(query);
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }
}

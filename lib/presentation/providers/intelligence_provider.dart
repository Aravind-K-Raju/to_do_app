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

  Future<void> search(
    String query, {
    List<DateTime>? dates,
    List<String>? types,
    bool yetToCompleteOnly = false,
  }) async {
    if (repository == null) return;

    // If query is empty AND no dates AND no types, clear results
    if (query.trim().isEmpty &&
        (dates == null || dates.isEmpty) &&
        (types == null || types.isEmpty)) {
      clearSearch();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      // Gather results.
      List<SearchResult> allResults = [];

      if (types != null && types.isNotEmpty) {
        for (var type in types) {
          final results = await repository!.search(
            query,
            dates: dates,
            type: type,
            yetToCompleteOnly: yetToCompleteOnly,
          );
          allResults.addAll(results);
        }
      } else {
        allResults = await repository!.search(
          query,
          dates: dates,
          yetToCompleteOnly: yetToCompleteOnly,
        );
      }

      // Deduplicate if needed? (Unlikely with distinct types, but possible if query matches same row multiple times? No, loop is by type)
      // Actually, if I search "Milk" with Types A and B, I get "Milk" from A and "Milk" from B. Distinct sets.

      // Sort by date again?
      allResults.sort((a, b) {
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return a.date!.compareTo(b.date!);
      });

      _searchResults = allResults;
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

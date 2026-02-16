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
    DateTime? date,
    List<String>? types,
  }) async {
    if (repository == null) return;

    // If query is empty AND no date AND no types, clear results (unless we want to show ALL?)
    // User asked "show even if only the date selected... or subject selected".
    // If EVERYTHING is empty, maybe clear?
    if (query.trim().isEmpty &&
        date == null &&
        (types == null || types.isEmpty)) {
      clearSearch();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      // Repository search only accepts ONE type string in current impl for simplicity?
      // Or I should update repository to accept List<String>?
      // For now, let's just loop or pick the first type if multiple?
      // Actually, my repo impl handles single `type`.
      // If UI passes multiple, I need to adjust logic.
      // The UI passes `_selectedFilters` (List<String>).
      // Let's iterate if needed, or update repo to accept List.
      // User likely selects one or few.
      // If repo only takes String?, I can call search multiple times and merge?
      // OR better: Update repo to take List<String>?
      // BUT I ALREADY UPDATED REPO TO TAKE String?.
      // Let's stick to simple: If multiple types, we might need a better query.
      // For now, let's assume valid calls.
      // Wait, if I pass `types` here, I need to handle it.

      // Temporary solution: If types has elements, use the first one OR
      // call repo search for each type and merge.
      // Actually, SQL `OR item_id IS NOT NULL` is cleaner if I pass list.
      // But I didn't do that.

      // Let's gather results.
      List<SearchResult> allResults = [];

      if (types != null && types.isNotEmpty) {
        for (var type in types) {
          final results = await repository!.search(
            query,
            date: date,
            type: type,
          );
          allResults.addAll(results);
        }
      } else {
        allResults = await repository!.search(query, date: date);
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

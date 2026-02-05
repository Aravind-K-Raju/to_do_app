import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/usecases/get_sessions.dart';
import '../../domain/usecases/log_session.dart';

class SessionProvider extends ChangeNotifier {
  final GetSessions getSessions;
  final LogSession logSession;

  SessionProvider({required this.getSessions, required this.logSession});

  // Timer State
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isRunning = false;
  int? _selectedCourseId;

  int get secondsElapsed => _secondsElapsed;
  bool get isRunning => _isRunning;
  int? get selectedCourseId => _selectedCourseId;

  // History State
  List<StudySession> _sessions = [];
  List<StudySession> get sessions => _sessions;

  void selectCourse(int? courseId) {
    _selectedCourseId = courseId;
    notifyListeners();
    if (courseId != null) {
      loadSessions(courseId);
    } else {
      _sessions = [];
      notifyListeners();
    }
  }

  void startTimer() {
    if (_timer != null) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsElapsed++;
      notifyListeners();
    });
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    notifyListeners();
  }

  Future<void> stopAndSaveTimer() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;

    if (_secondsElapsed > 60 && _selectedCourseId != null) {
      // Only save if > 1 minute
      final session = StudySession(
        courseId: _selectedCourseId!,
        startTime: DateTime.now().subtract(Duration(seconds: _secondsElapsed)),
        durationMinutes: (_secondsElapsed / 60).round(),
      );
      await logSession(session);
      await loadSessions(_selectedCourseId!);
    }

    _secondsElapsed = 0;
    notifyListeners();
  }

  Future<void> loadSessions(int courseId) async {
    _sessions = await getSessions(courseId);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

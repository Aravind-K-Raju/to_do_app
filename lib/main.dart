import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'presentation/screens/pin_screen.dart';
import 'presentation/providers/course_provider.dart';
import 'presentation/providers/session_provider.dart';
import 'presentation/providers/task_provider.dart';
import 'presentation/providers/hackathon_provider.dart';
import 'presentation/providers/intelligence_provider.dart';
import 'data/repositories/course_repository_impl.dart';
import 'data/repositories/session_repository_impl.dart';
import 'data/repositories/task_repository_impl.dart';
import 'data/repositories/hackathon_repository_impl.dart';
import 'data/repositories/intelligence_repository_impl.dart';
import 'domain/usecases/get_courses.dart';
import 'domain/usecases/create_course.dart';
import 'domain/usecases/update_course.dart';
import 'domain/usecases/delete_course.dart';
import 'domain/usecases/get_sessions.dart';
import 'domain/usecases/log_session.dart';
import 'domain/usecases/create_task.dart';
import 'domain/usecases/update_task.dart';
import 'domain/usecases/delete_task.dart';
import 'domain/usecases/hackathon_usecases.dart';
import 'domain/usecases/get_daily_stats.dart';
import 'domain/usecases/get_distinct_sites.dart';
import 'domain/usecases/get_distinct_login_mails.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OfflineApp());
}

class OfflineApp extends StatefulWidget {
  const OfflineApp({super.key});

  @override
  State<OfflineApp> createState() => _OfflineAppState();
}

class _OfflineAppState extends State<OfflineApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PinScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseRepository = CourseRepositoryImpl();
    final sessionRepository = SessionRepositoryImpl();
    final taskRepository = TaskRepositoryImpl();
    final hackathonRepository = HackathonRepositoryImpl();
    final intelligenceRepository = IntelligenceRepositoryImpl();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CourseProvider(
            getCourses: GetCourses(courseRepository),
            createCourse: CreateCourse(courseRepository),
            updateCourse: UpdateCourse(courseRepository),
            deleteCourse: DeleteCourse(courseRepository),
            getDistinctSites: GetDistinctSites(courseRepository),
            getDistinctLoginMails: GetDistinctLoginMails(courseRepository),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(
            getSessions: GetSessions(sessionRepository),
            logSession: LogSession(sessionRepository),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TaskProvider(
            repository: taskRepository,
            createTask: CreateTask(taskRepository),
            updateTask: UpdateTask(taskRepository),
            deleteTask: DeleteTask(taskRepository),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => HackathonProvider(
            getHackathons: GetHackathons(hackathonRepository),
            createHackathon: CreateHackathon(hackathonRepository),
            updateHackathon: UpdateHackathon(hackathonRepository),
            deleteHackathon: DeleteHackathon(hackathonRepository),
            getDistinctLoginMails: GetHackathonDistinctLoginMails(
              hackathonRepository,
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => IntelligenceProvider(
            getDailyStats: GetDailyStats(intelligenceRepository),
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: AppConstants.appTitle,
        theme: AppTheme.darkTheme,
        home: const PinScreen(),
      ),
    );
  }
}

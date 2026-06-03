import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'presentation/navigation_scaffold.dart';
import 'presentation/providers/course_provider.dart';
import 'presentation/providers/task_provider.dart';
import 'presentation/providers/hackathon_provider.dart';
import 'presentation/providers/intelligence_provider.dart';
import 'presentation/providers/assignment_provider.dart';
import 'data/repositories/course_repository_impl.dart';
import 'data/repositories/task_repository_impl.dart';
import 'data/repositories/hackathon_repository_impl.dart';
import 'data/repositories/intelligence_repository_impl.dart';
import 'data/repositories/assignment_repository_impl.dart';
import 'data/repositories/note_repository_impl.dart';
import 'presentation/providers/note_provider.dart';
import 'core/services/draft_service.dart';
import 'presentation/providers/draft_provider.dart';
import 'domain/usecases/get_courses.dart';
import 'domain/usecases/create_course.dart';
import 'domain/usecases/update_course.dart';
import 'domain/usecases/delete_course.dart';
import 'domain/usecases/create_task.dart';
import 'domain/usecases/update_task.dart';
import 'domain/usecases/delete_task.dart';
import 'domain/usecases/hackathon_usecases.dart';
import 'domain/usecases/get_daily_stats.dart';
import 'domain/usecases/get_insights_data.dart';
import 'domain/usecases/get_distinct_sites.dart';
import 'domain/usecases/get_distinct_login_mails.dart';
import 'domain/usecases/assignment_usecases.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:home_widget/home_widget.dart';
import 'core/services/widget_sync_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'toggle_pause') {
    final isPaused = uri?.queryParameters['is_paused'] == 'true';
    final action = isPaused ? 'pause' : 'resume';
    final pausedAt = uri?.queryParameters['paused_at'];
    await WidgetSyncService.runBackgroundReschedule(action: action, pausedAt: pausedAt);
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Register background callback for home screen widget interactions
  HomeWidget.registerInteractivityCallback(backgroundCallback);

  // Synchronize the home screen widgets on application startup asynchronously
  WidgetSyncService.syncWidget();
  runApp(const OfflineApp());
}

class OfflineApp extends StatelessWidget {
  const OfflineApp({super.key});

  @override
  Widget build(BuildContext context) {
    final courseRepository = CourseRepositoryImpl();
    final taskRepository = TaskRepositoryImpl();
    final hackathonRepository = HackathonRepositoryImpl();
    final intelligenceRepository = IntelligenceRepositoryImpl();
    final assignmentRepository = AssignmentRepositoryImpl();
    final noteRepository = NoteRepositoryImpl();
    final draftService = DraftService();

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
            getInsightsData: GetInsightsData(intelligenceRepository),
            repository: intelligenceRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AssignmentProvider(
            getAssignments: GetAssignments(assignmentRepository),
            addAssignment: AddAssignment(assignmentRepository),
            updateAssignment: UpdateAssignment(assignmentRepository),
            deleteAssignment: DeleteAssignment(assignmentRepository),
          ),
        ),
        ChangeNotifierProvider(create: (_) => NoteProvider(noteRepository)),
        ChangeNotifierProvider(create: (_) => DraftProvider(draftService)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appTitle,
        theme: AppTheme.darkTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US'), Locale('en', 'GB')],
        home: const NavigationScaffold(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/course.dart';
import '../providers/course_provider.dart';
import '../providers/session_provider.dart';

class StudyTimerScreen extends StatelessWidget {
  const StudyTimerScreen({super.key});

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    final courseProvider = Provider.of<CourseProvider>(context);

    // Filter active/planned courses
    final activeCourses = courseProvider.courses
        .where((c) => c.status != 'completed')
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Study Timer')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Course Selector
            DropdownButtonFormField<int>(
              value: sessionProvider.selectedCourseId,
              hint: const Text('Select a Course to Study'),
              items: activeCourses.map((Course c) {
                return DropdownMenuItem<int>(value: c.id, child: Text(c.title));
              }).toList(),
              onChanged: sessionProvider.isRunning
                  ? null // Disable change while running
                  : (val) => sessionProvider.selectCourse(val),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const Spacer(),

            // Timer Display
            Center(
              child: Text(
                _formatTime(sessionProvider.secondsElapsed),
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('MM:SS', style: TextStyle(color: Colors.grey)),
            ),

            const Spacer(),

            // Controls
            if (sessionProvider.selectedCourseId != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!sessionProvider.isRunning)
                    ElevatedButton.icon(
                      onPressed: sessionProvider.startTimer,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('START'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  if (sessionProvider.isRunning)
                    ElevatedButton.icon(
                      onPressed: sessionProvider.pauseTimer,
                      icon: const Icon(Icons.pause),
                      label: const Text('PAUSE'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  if (sessionProvider.secondsElapsed > 0 &&
                      !sessionProvider.isRunning)
                    ElevatedButton.icon(
                      onPressed: () async {
                        await sessionProvider.stopAndSaveTimer();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session Logged!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('FINISH'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],

            if (sessionProvider.selectedCourseId == null)
              const Center(child: Text('Select a course to start timer')),

            const Spacer(),

            // Recent Sessions
            const Text(
              'Recent Sessions (This Course)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: sessionProvider.sessions.length,
                itemBuilder: (ctx, i) {
                  final session = sessionProvider.sessions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text('${session.durationMinutes} minutes'),
                    subtitle: Text(session.startTime.toString().split('.')[0]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/course.dart';
import '../providers/course_provider.dart';
import 'course_add_edit_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(course.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseAddEditScreen(course: course),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Course?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                    TextButton(
                      child: const Text('Delete'),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (context.mounted) {
                  await Provider.of<CourseProvider>(
                    context,
                    listen: false,
                  ).removeCourse(course.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform: ${course.platform}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${course.status}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Started: ${DateFormat.yMMMd().format(course.startDate)}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (course.completionDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'Completed: ${DateFormat.yMMMd().format(course.completionDate!)}',
                style: const TextStyle(fontSize: 16, color: Colors.greenAccent),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Description:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(course.description ?? 'No description provided.'),
            const SizedBox(height: 24),
            const Text(
              'Progress:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            LinearProgressIndicator(
              value: course.progressPercent / 100,
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            Text('${course.progressPercent.toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }
}

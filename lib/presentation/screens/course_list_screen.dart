import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../widgets/items/course_list_item.dart';
import 'course_add_edit_screen.dart';
import 'course_detail_screen.dart';

import 'notes/folder_list_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  @override
  void initState() {
    super.initState();
    // Load courses when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CourseProvider>(context, listen: false).loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_alt),
            tooltip: 'Quick Notes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FolderListScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.courses.isEmpty) {
            return const Center(
              child: Text('No courses yet. Start your journey!'),
            );
          }

          return ListView.builder(
            itemCount: provider.courses.length,
            itemBuilder: (context, index) {
              final course = provider.courses[index];
              return CourseListItem(
                course: course,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailScreen(course: course),
                    ),
                  );
                },
                onDelete: () async {
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

                  if (confirm == true && context.mounted) {
                    Provider.of<CourseProvider>(
                      context,
                      listen: false,
                    ).removeCourse(course.id!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Course deleted')),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_course_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CourseAddEditScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

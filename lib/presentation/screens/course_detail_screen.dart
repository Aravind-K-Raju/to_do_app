import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/course.dart';

import 'course_add_edit_screen.dart';

class CourseDetailScreen extends StatelessWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
    }
  }

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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform
            const Text(
              'Platform:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${course.sourceName}${course.channelName != null && course.channelName!.isNotEmpty ? " • ${course.channelName}" : ""}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Status
            const Text(
              'Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(course.status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            // Start Date
            const Text(
              'Start Date:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              DateFormat.yMMMd().format(course.startDate),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Login
            if (course.loginMail != null && course.loginMail!.isNotEmpty) ...[
              const Text(
                'Login:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(course.loginMail!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],

            // Description
            const Text(
              'Description:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              course.description ?? 'No description provided.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Links
            if (course.links.isNotEmpty) ...[
              const Text(
                'Links:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...course.links.map(
                (link) => Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      InkWell(
                        onTap: () => _launchUrl(context, link.url),
                        child: Text(
                          link.url,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Timeline
            if (course.timeline.isNotEmpty) ...[
              const Text(
                'Timeline:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...course.timeline.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline dot and line visual
                      Column(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 12,
                            color: Colors.blue,
                          ),
                          // The following block replaces the original Container for the timeline line
                          // Assuming 'color' is a Color variable defined in the scope,
                          // and 'withValues' is an extension method on Color.
                          // If 'color' is not defined, this will cause a compilation error.
                          // For now, I'm assuming 'color' should be Colors.grey as it was previously.
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.grey.withValues(
                              alpha: 0.3,
                            ), // Replaced withOpacity with withValues
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.description,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              DateFormat.yMMMd().format(event.date),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }
}

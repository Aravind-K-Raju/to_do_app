import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/hackathon.dart';
import '../providers/hackathon_provider.dart';
import 'hackathon_add_edit_screen.dart';

class HackathonDetailScreen extends StatelessWidget {
  final Hackathon hackathon;

  const HackathonDetailScreen({super.key, required this.hackathon});

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
        title: Text(hackathon.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HackathonAddEditScreen(hackathon: hackathon),
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
                  title: const Text('Delete Event?'),
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
                  await Provider.of<HackathonProvider>(
                    context,
                    listen: false,
                  ).removeHackathon(hackathon.id!);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme / Platform Equivalent
            if (hackathon.theme != null && hackathon.theme!.isNotEmpty) ...[
              const Text(
                'Theme:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(hackathon.theme!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],

            // Tech Stack
            if (hackathon.techStack != null &&
                hackathon.techStack!.isNotEmpty) ...[
              const Text(
                'Tech Stack:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(hackathon.techStack!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],

            // Status (Derived) / Outcome
            const Text(
              'Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              hackathon.outcome != null && hackathon.outcome!.isNotEmpty
                  ? hackathon.outcome!
                  : (DateTime.now().isBefore(hackathon.startDate)
                        ? 'Upcoming'
                        : (hackathon.endDate != null &&
                                  DateTime.now().isAfter(hackathon.endDate!)
                              ? 'Completed'
                              : 'Ongoing')),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Start Date
            const Text(
              'Start Date:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${DateFormat.yMMMd().format(hackathon.startDate)}'
              '${hackathon.endDate != null ? ' - ${DateFormat.yMMMd().format(hackathon.endDate!)}' : ''}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Login
            if (hackathon.loginMail != null &&
                hackathon.loginMail!.isNotEmpty) ...[
              const Text(
                'Login:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(hackathon.loginMail!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],

            // Description
            const Text(
              'Description:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              hackathon.description ?? 'No description provided.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Project Link
            if (hackathon.projectLink != null &&
                hackathon.projectLink!.isNotEmpty) ...[
              const Text(
                'Project Link:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: () => _launchUrl(context, hackathon.projectLink!),
                child: Text(
                  hackathon.projectLink!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blueAccent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Links
            if (hackathon.links.isNotEmpty) ...[
              const Text(
                'Links:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...hackathon.links.map(
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
            if (hackathon.timeline.isNotEmpty) ...[
              const Text(
                'Timeline:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...hackathon.timeline.map(
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
                          Container(
                            width: 2,
                            height: 40,
                            color: Colors.grey.withValues(alpha: 0.3),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

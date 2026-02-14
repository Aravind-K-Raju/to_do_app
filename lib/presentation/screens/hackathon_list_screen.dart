import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hackathon_provider.dart';
import '../widgets/items/hackathon_list_item.dart';
import 'hackathon_add_edit_screen.dart';
import 'hackathon_detail_screen.dart';

class HackathonListScreen extends StatefulWidget {
  const HackathonListScreen({super.key});

  @override
  State<HackathonListScreen> createState() => _HackathonListScreenState();
}

class _HackathonListScreenState extends State<HackathonListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HackathonProvider>(context, listen: false).loadHackathons();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hackathons')),
      body: Consumer<HackathonProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.hackathons.isEmpty) {
            return const Center(child: Text('No hackathons registered.'));
          }

          return ListView.builder(
            itemCount: provider.hackathons.length,
            itemBuilder: (context, index) {
              final hackathon = provider.hackathons[index];
              return HackathonListItem(
                hackathon: hackathon,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HackathonDetailScreen(hackathon: hackathon),
                    ),
                  );
                },
                onDelete: () async {
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
                    Provider.of<HackathonProvider>(
                      context,
                      listen: false,
                    ).removeHackathon(hackathon.id!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Event deleted')),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HackathonAddEditScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

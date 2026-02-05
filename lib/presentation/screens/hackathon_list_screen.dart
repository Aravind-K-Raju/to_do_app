import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/hackathon_provider.dart';
import 'hackathon_add_edit_screen.dart';

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
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    hackathon.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${DateFormat.yMMMd().format(hackathon.startDate)} • ${hackathon.theme ?? "No Theme"}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HackathonAddEditScreen(hackathon: hackathon),
                        ),
                      );
                    },
                  ),
                ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/entities/event_link.dart';
import '../../domain/entities/event_date.dart';
import '../providers/hackathon_provider.dart';

class HackathonAddEditScreen extends StatefulWidget {
  final Hackathon? hackathon;

  const HackathonAddEditScreen({super.key, this.hackathon});

  @override
  State<HackathonAddEditScreen> createState() => _HackathonAddEditScreenState();
}

class _HackathonAddEditScreenState extends State<HackathonAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _themeController;
  late TextEditingController _descriptionController; // New
  late TextEditingController _techStackController;
  late TextEditingController _outcomeController;
  late TextEditingController
  _linkController; // Keeping original simple link as 'Project Link'

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // Dynamic Lists
  List<EventLink> _links = [];
  List<EventDate> _timeline = [];

  late StreamSubscription _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.hackathon?.name ?? '');
    _themeController = TextEditingController(
      text: widget.hackathon?.theme ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.hackathon?.description ?? '',
    );
    _techStackController = TextEditingController(
      text: widget.hackathon?.techStack ?? '',
    );
    _outcomeController = TextEditingController(
      text: widget.hackathon?.outcome ?? '',
    );
    _linkController = TextEditingController(
      text: widget.hackathon?.projectLink ?? '',
    );

    if (widget.hackathon != null) {
      _startDate = widget.hackathon!.startDate;
      _endDate = widget.hackathon!.endDate;
      _links = List.from(widget.hackathon!.links);
      _timeline = List.from(widget.hackathon!.timeline);
    } else {
      // Only listen for sharing intent if creating new event
      _initSharingListener();
    }
  }

  void _initSharingListener() {
    // For sharing or opening app from other apps
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty && value.first.path.isNotEmpty) {
          setState(() {
            // Assuming the shared text is in the path or we might need another API for pure text
            // Note: for text/plain, the path usually contains the text in some versions,
            // or we check 'message' if available?
            // The plugin documentation says for text, it returns a file with path as the text?
            // Actually, let's append it to description
            _descriptionController.text = value.first.path;
          });
        }
      },
      onError: (err) {
        debugPrint("getIntentDataStream error: $err");
      },
    );

    // Get the media from the intent that started the app
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty && value.first.path.isNotEmpty) {
        setState(() {
          _descriptionController.text = value.first.path;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _themeController.dispose();
    _descriptionController.dispose();
    _techStackController.dispose();
    _outcomeController.dispose();
    _linkController.dispose();
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addLink() {
    final urlController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Related Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                setState(() {
                  _links.add(
                    EventLink(
                      url: urlController.text,
                      description: descController.text.isEmpty
                          ? 'Link'
                          : descController.text,
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addTimelineEvent() {
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Timeline Event'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(DateFormat.yMMMd().format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (descController.text.isNotEmpty) {
                    setState(() {
                      _timeline.add(
                        EventDate(
                          date: selectedDate,
                          description: descController.text,
                        ),
                      );
                      _timeline.sort((a, b) => a.date.compareTo(b.date));
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newHackathon = Hackathon(
        id: widget.hackathon?.id,
        name: _nameController.text,
        theme: _themeController.text,
        description: _descriptionController.text, // New
        startDate: _startDate,
        endDate: _endDate,
        techStack: _techStackController.text,
        outcome: _outcomeController.text,
        projectLink: _linkController.text,
        links: _links,
        timeline: _timeline,
      );

      final provider = Provider.of<HackathonProvider>(context, listen: false);
      if (widget.hackathon == null) {
        provider.addHackathon(newHackathon);
      } else {
        provider.editHackathon(newHackathon);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hackathon == null ? 'Add Event' : 'Edit Event'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Event Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _themeController,
                decoration: const InputDecoration(
                  labelText: 'Theme / Topic',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat.yMMMd().format(_startDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _endDate != null
                              ? DateFormat.yMMMd().format(_endDate!)
                              : 'Optional',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _techStackController,
                decoration: const InputDecoration(
                  labelText: 'Tech Stack',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _outcomeController,
                decoration: const InputDecoration(
                  labelText: 'Outcome / Result',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Main Project URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Multiple Links Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Additional Links',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Colors.tealAccent,
                    ),
                    onPressed: _addLink,
                  ),
                ],
              ),
              if (_links.isEmpty)
                const Text(
                  'No additional links.',
                  style: TextStyle(color: Colors.grey),
                ),
              ..._links.asMap().entries.map((entry) {
                final index = entry.key;
                final link = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    link.url,
                    style: const TextStyle(color: Colors.blue),
                  ),
                  subtitle: Text(link.description),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => setState(() => _links.removeAt(index)),
                  ),
                );
              }),
              const Divider(),

              // Timeline Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Timeline',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: Colors.tealAccent,
                    ),
                    onPressed: _addTimelineEvent,
                  ),
                ],
              ),
              if (_timeline.isEmpty)
                const Text(
                  'No timeline events.',
                  style: TextStyle(color: Colors.grey),
                ),
              ..._timeline.asMap().entries.map((entry) {
                final index = entry.key;
                final event = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 12),
                  title: Text(DateFormat.yMMMd().format(event.date)),
                  subtitle: Text(event.description),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    onPressed: () => setState(() => _timeline.removeAt(index)),
                  ),
                );
              }),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

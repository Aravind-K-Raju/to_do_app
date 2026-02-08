import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/entities/event_link.dart';
import '../../domain/entities/event_date.dart';
import '../providers/hackathon_provider.dart';
// Import reusable widgets
import '../widgets/form/dynamic_link_section.dart';
import '../widgets/form/dynamic_timeline_section.dart';
import '../widgets/form/login_mail_autocomplete.dart';

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
  late TextEditingController _loginMailController;

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  // Dynamic Lists
  List<EventLink> _links = [];
  List<EventDate> _timeline = [];

  StreamSubscription? _intentDataStreamSubscription;

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
    _loginMailController = TextEditingController(
      text: widget.hackathon?.loginMail ?? '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HackathonProvider>(
        context,
        listen: false,
      ).loadDistinctLoginMails();
    });

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
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty && value.first.path.isNotEmpty) {
              setState(() {
                // Assuming the shared text is in the path
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
    _loginMailController.dispose();
    _intentDataStreamSubscription?.cancel();
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
        loginMail: _loginMailController.text.isNotEmpty
            ? _loginMailController.text
            : null,
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

              Consumer<HackathonProvider>(
                builder: (context, provider, child) {
                  return LoginMailAutocomplete(
                    controller: _loginMailController,
                    distinctLoginMails: provider.distinctLoginMails,
                  );
                },
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
              DynamicLinkSection<EventLink>(
                title: 'Additional Links',
                items: _links,
                onAdd: (url, desc) {
                  setState(() {
                    _links.add(EventLink(url: url, description: desc));
                  });
                },
                itemBuilder: (context, link, index) {
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
                },
              ),
              const Divider(),

              // Timeline Section
              DynamicTimelineSection<EventDate>(
                title: 'Timeline',
                items: _timeline,
                onAdd: (date, desc) {
                  setState(() {
                    _timeline.add(EventDate(date: date, description: desc));
                    _timeline.sort((a, b) => a.date.compareTo(b.date));
                  });
                },
                itemBuilder: (context, event, index) {
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
                      onPressed: () =>
                          setState(() => _timeline.removeAt(index)),
                    ),
                  );
                },
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}

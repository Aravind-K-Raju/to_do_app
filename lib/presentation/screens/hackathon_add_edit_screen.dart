import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../domain/entities/hackathon.dart';
import '../../domain/entities/event_link.dart';
import '../../domain/entities/event_date.dart';
import '../providers/hackathon_provider.dart';
import '../providers/draft_provider.dart';
import '../widgets/form/dynamic_link_section.dart';
import '../widgets/form/dynamic_timeline_section.dart';
import '../widgets/form/styled_app_bar.dart';
import '../widgets/form/styled_form_field.dart';

class HackathonAddEditScreen extends StatefulWidget {
  final Hackathon? hackathon;

  const HackathonAddEditScreen({super.key, this.hackathon});

  @override
  State<HackathonAddEditScreen> createState() => _HackathonAddEditScreenState();
}

class _HackathonAddEditScreenState extends State<HackathonAddEditScreen> with WidgetsBindingObserver {
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
  
  bool _isSaved = false;
  bool _canPop = false;

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
      _loadDraft();
      // Only listen for sharing intent if creating new event
      _initSharingListener();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadDraft() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final draftJson = await draftProvider.getDraft('draft_hackathon');
    if (draftJson != null && mounted) {
      try {
        final data = jsonDecode(draftJson);
        setState(() {
          _nameController.text = data['name'] ?? '';
          _themeController.text = data['theme'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _techStackController.text = data['techStack'] ?? '';
          _outcomeController.text = data['outcome'] ?? '';
          _linkController.text = data['projectLink'] ?? '';
          _loginMailController.text = data['loginMail'] ?? '';
        });
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  bool _hasData() {
    return _nameController.text.isNotEmpty || _themeController.text.isNotEmpty || _descriptionController.text.isNotEmpty;
  }

  Future<void> _saveDraft() async {
    if (_hasData()) {
      final draftData = {
        'name': _nameController.text,
        'theme': _themeController.text,
        'description': _descriptionController.text,
        'techStack': _techStackController.text,
        'outcome': _outcomeController.text,
        'projectLink': _linkController.text,
        'loginMail': _loginMailController.text,
      };
      await Provider.of<DraftProvider>(context, listen: false).saveDraft('draft_hackathon', jsonEncode(draftData));
    } else {
      await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_hackathon');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isSaved && widget.hackathon == null) {
        _saveDraft();
      }
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
    WidgetsBinding.instance.removeObserver(this);
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
      
      _isSaved = true;
      if (widget.hackathon == null) {
        Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_hackathon');
      }
      setState(() { _canPop = true; });
      Navigator.pop(context);
    }
  }

  Future<void> _handleBack() async {
    if (!_isSaved && widget.hackathon == null) {
      if (_hasData()) {
        await _saveDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
      } else {
        await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_hackathon');
      }
    }
    setState(() { _canPop = true; });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: StyledAppBar(
          title: widget.hackathon == null ? 'Add Event' : 'Edit Event',
          subtitle: 'Track hackathons and technical events',
          onBack: _handleBack,
          onSave: _save,
          isEditMode: widget.hackathon != null,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                StyledFormField(
                  label: 'Event Name',
                  icon: Icons.emoji_events,
                  iconColor: const Color(0xFFF59E0B),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'Enter event name'),
                    validator: (val) => val!.isEmpty ? 'Enter name' : null,
                  ),
                ),
                
                StyledFormField(
                  label: 'Theme / Topic',
                  icon: Icons.lightbulb,
                  iconColor: const Color(0xFF8B5CF6),
                  child: TextFormField(
                    controller: _themeController,
                    decoration: const InputDecoration(hintText: 'Enter theme or topic'),
                  ),
                ),

                Consumer<HackathonProvider>(
                  builder: (context, provider, child) {
                    return Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') return const Iterable<String>.empty();
                        return provider.distinctLoginMails.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) => _loginMailController.text = selection,
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        if (textEditingController.value != _loginMailController.value && _loginMailController.text.isNotEmpty && textEditingController.text.isEmpty) {
                          textEditingController.value = _loginMailController.value;
                        }
                        textEditingController.addListener(() {
                          if (_loginMailController.value != textEditingController.value) {
                            _loginMailController.value = textEditingController.value;
                          }
                        });
                        
                        return StyledFormField(
                          label: 'Login Mail (Optional)',
                          icon: Icons.email,
                          iconColor: const Color(0xFF0EA5E9),
                          helperText: 'Account used for login',
                          child: TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onFieldSubmitted: (String value) => onFieldSubmitted(),
                            decoration: const InputDecoration(hintText: 'Enter login email'),
                          ),
                        );
                      },
                    );
                  },
                ),

                StyledFormField(
                  label: 'Description',
                  icon: Icons.description,
                  iconColor: const Color(0xFF3B82F6),
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(hintText: 'Add a short description...'),
                    maxLines: 4,
                  ),
                ),

                // Dates
                Row(
                  children: [
                    Expanded(
                      child: StyledFormField(
                        label: 'Start Date',
                        icon: Icons.calendar_today,
                        iconColor: const Color(0xFF10B981),
                        trailing: const Icon(Icons.calendar_month, color: Colors.grey),
                        onTap: () => _selectDate(true),
                        child: Text(DateFormat.yMMMd().format(_startDate)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StyledFormField(
                        label: 'End Date',
                        icon: Icons.event_available,
                        iconColor: const Color(0xFFF43F5E),
                        trailing: const Icon(Icons.calendar_month, color: Colors.grey),
                        onTap: () => _selectDate(false),
                        child: Text(_endDate != null ? DateFormat.yMMMd().format(_endDate!) : 'Optional'),
                      ),
                    ),
                  ],
                ),

                StyledFormField(
                  label: 'Tech Stack',
                  icon: Icons.code,
                  iconColor: const Color(0xFFEC4899),
                  child: TextFormField(
                    controller: _techStackController,
                    decoration: const InputDecoration(hintText: 'Enter tech stack used'),
                  ),
                ),

                StyledFormField(
                  label: 'Outcome / Result',
                  icon: Icons.stars,
                  iconColor: const Color(0xFFEAB308),
                  child: TextFormField(
                    controller: _outcomeController,
                    decoration: const InputDecoration(hintText: 'Enter outcome or result'),
                  ),
                ),

                StyledFormField(
                  label: 'Main Project URL',
                  icon: Icons.link,
                  iconColor: const Color(0xFF14B8A6),
                  child: TextFormField(
                    controller: _linkController,
                    decoration: const InputDecoration(hintText: 'Enter project link'),
                  ),
                ),
                const SizedBox(height: 8),

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
      ),
    );
  }
}

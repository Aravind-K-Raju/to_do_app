import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_link.dart';
import '../../domain/entities/course_date.dart';
import '../providers/course_provider.dart';
import '../providers/draft_provider.dart';
import '../widgets/form/dynamic_link_section.dart';
import '../widgets/form/dynamic_timeline_section.dart';
import '../widgets/form/styled_app_bar.dart';
import '../widgets/form/styled_form_field.dart';

class CourseAddEditScreen extends StatefulWidget {
  final Course? course;

  const CourseAddEditScreen({super.key, this.course});

  @override
  State<CourseAddEditScreen> createState() => _CourseAddEditScreenState();
}

class _CourseAddEditScreenState extends State<CourseAddEditScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController
  _sourceNameController; // For Site Name, Platform Name, or Source
  late TextEditingController _channelNameController; // For YouTube Channel etc.
  late TextEditingController _loginMailController;
  late TextEditingController _descriptionController;

  CourseType _type = CourseType.site;
  String _status = 'planned';
  DateTime _startDate = DateTime.now();

  // Dynamic Lists
  List<CourseLink> _links = [];
  List<CourseDate> _timeline = [];
  
  bool _isSaved = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.course?.title ?? '');
    _sourceNameController = TextEditingController(
      text: widget.course?.sourceName ?? '',
    );
    _channelNameController = TextEditingController(
      text: widget.course?.channelName ?? '',
    );
    _loginMailController = TextEditingController(
      text: widget.course?.loginMail ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.course?.description ?? '',
    );

    // Load suggestions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CourseProvider>(
        context,
        listen: false,
      ).loadDistinctLoginMails();
      if (_type == CourseType.site) {
        Provider.of<CourseProvider>(context, listen: false).loadDistinctSites();
      }
    });

    if (widget.course != null) {
      _type = widget.course!.type;
      _status = widget.course!.status;
      _startDate = widget.course!.startDate;
      _links = List.from(widget.course!.links);
      _timeline = List.from(widget.course!.timeline);
    } else {
      _loadDraft();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadDraft() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final draftJson = await draftProvider.getDraft('draft_course');
    if (draftJson != null && mounted) {
      try {
        final data = jsonDecode(draftJson);
        setState(() {
          _titleController.text = data['title'] ?? '';
          _sourceNameController.text = data['sourceName'] ?? '';
          _channelNameController.text = data['channelName'] ?? '';
          _loginMailController.text = data['loginMail'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _type = CourseType.values.firstWhere((e) => e.name == data['type'], orElse: () => CourseType.site);
          _status = data['status'] ?? 'planned';
        });
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  bool _hasData() {
    return _titleController.text.isNotEmpty || _sourceNameController.text.isNotEmpty || _descriptionController.text.isNotEmpty;
  }

  Future<void> _saveDraft() async {
    if (_hasData()) {
      final draftData = {
        'title': _titleController.text,
        'sourceName': _sourceNameController.text,
        'channelName': _channelNameController.text,
        'loginMail': _loginMailController.text,
        'description': _descriptionController.text,
        'type': _type.name,
        'status': _status,
      };
      await Provider.of<DraftProvider>(context, listen: false).saveDraft('draft_course', jsonEncode(draftData));
    } else {
      await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_course');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isSaved && widget.course == null) {
        _saveDraft();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceNameController.dispose();
    _channelNameController.dispose();
    _loginMailController.dispose();
    _descriptionController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _selectDate({required Function(DateTime) onPicked}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  void _saveCourse() {
    if (_formKey.currentState!.validate()) {
      if (_type == CourseType.site && _sourceNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter a Site Name')),
        );
        return;
      }

      final newCourse = Course(
        id: widget.course?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        type: _type,
        sourceName: _sourceNameController.text,
        channelName: (_type == CourseType.platform)
            ? _channelNameController.text
            : null,
        loginMail: _loginMailController.text.isNotEmpty
            ? _loginMailController.text
            : null,
        startDate: _startDate,
        progressPercent: widget.course?.progressPercent ?? 0.0,
        status: _status,
        links: _links,
        timeline: _timeline,
      );

      final provider = Provider.of<CourseProvider>(context, listen: false);
      if (widget.course == null) {
        provider.addCourse(newCourse);
      } else {
        provider.editCourse(newCourse);
      }
      
      _isSaved = true;
      if (widget.course == null) {
        Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_course');
      }
      setState(() { _canPop = true; });
      Navigator.pop(context);
    }
  }

  Future<void> _handleBack() async {
    if (!_isSaved && widget.course == null) {
      if (_hasData()) {
        await _saveDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
      } else {
        await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_course');
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
          title: widget.course == null ? 'Add Project' : 'Edit Project',
          subtitle: 'Create a new project and stay organized',
          onBack: _handleBack,
          onSave: _saveCourse,
          isEditMode: widget.course != null,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                StyledFormField(
                  label: 'Title',
                  icon: Icons.description,
                  iconColor: const Color(0xFF7C3AED),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(hintText: 'Enter project title'),
                    validator: (val) => val!.isEmpty ? 'Enter title' : null,
                  ),
                ),
                StyledFormField(
                  label: 'Type',
                  icon: Icons.local_offer,
                  iconColor: const Color(0xFF3B82F6),
                  trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  child: DropdownButtonFormField<CourseType>(
                    value: _type,
                    icon: const SizedBox.shrink(), // hide default icon
                    items: CourseType.values.map((t) {
                      String label = t.toString().split('.').last;
                      label = label[0].toUpperCase() + label.substring(1);
                      if (label == 'SelfPaced') label = 'Self Paced';
                      return DropdownMenuItem(value: t, child: Text(label));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _type = val!;
                      });
                    },
                  ),
                ),

                if (_type == CourseType.site) ...[
                  Consumer<CourseProvider>(
                    builder: (context, provider, child) {
                      return Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') return const Iterable<String>.empty();
                          return provider.distinctSites.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) => _sourceNameController.text = selection,
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          if (textEditingController.value != _sourceNameController.value && _sourceNameController.text.isNotEmpty && textEditingController.text.isEmpty) {
                            textEditingController.value = _sourceNameController.value;
                          }
                          textEditingController.addListener(() {
                            if (_sourceNameController.value != textEditingController.value) {
                              _sourceNameController.value = textEditingController.value;
                            }
                          });
                          
                          return StyledFormField(
                            label: 'Site Name',
                            icon: Icons.domain,
                            iconColor: const Color(0xFF10B981),
                            helperText: 'Select from existing or type new',
                            child: TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              onFieldSubmitted: (String value) => onFieldSubmitted(),
                              decoration: const InputDecoration(hintText: 'Enter site name'),
                              validator: (val) => val!.isEmpty ? 'Enter Site Name' : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],

                if (_type == CourseType.platform) ...[
                  StyledFormField(
                    label: 'Platform Name (e.g., YouTube)',
                    icon: Icons.video_library,
                    iconColor: Colors.redAccent,
                    child: TextFormField(
                      controller: _sourceNameController,
                      decoration: const InputDecoration(hintText: 'Enter platform name'),
                      validator: (val) => val!.isEmpty ? 'Enter Platform Name' : null,
                    ),
                  ),
                  StyledFormField(
                    label: 'Channel/Creator Name (Optional)',
                    icon: Icons.person,
                    iconColor: Colors.deepOrangeAccent,
                    child: TextFormField(
                      controller: _channelNameController,
                      decoration: const InputDecoration(hintText: 'Enter channel name'),
                    ),
                  ),
                ],

                if (_type == CourseType.selfPaced) ...[
                  StyledFormField(
                    label: 'Source / Institution',
                    icon: Icons.school,
                    iconColor: Colors.tealAccent,
                    child: TextFormField(
                      controller: _sourceNameController,
                      decoration: const InputDecoration(hintText: 'Enter source'),
                      validator: (val) => val!.isEmpty ? 'Enter Source' : null,
                    ),
                  ),
                ],

                Row(
                  children: [
                    Expanded(
                      child: StyledFormField(
                        label: 'Status',
                        icon: Icons.flag,
                        iconColor: const Color(0xFF6366F1),
                        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        child: DropdownButtonFormField<String>(
                          value: _status,
                          icon: const SizedBox.shrink(),
                          items: ['planned', 'ongoing', 'completed']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1))))
                              .toList(),
                          onChanged: (val) => setState(() => _status = val!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StyledFormField(
                        label: 'Start Date',
                        icon: Icons.calendar_today,
                        iconColor: const Color(0xFF3B82F6),
                        trailing: const Icon(Icons.calendar_month, color: Colors.grey),
                        onTap: () => _selectDate(onPicked: (d) => setState(() => _startDate = d)),
                        child: Text(DateFormat.yMMMd().format(_startDate)),
                      ),
                    ),
                  ],
                ),

                Consumer<CourseProvider>(
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
                  label: 'Description (Optional)',
                  icon: Icons.description,
                  iconColor: const Color(0xFFF59E0B),
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(hintText: 'Add a short description about this project...'),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 8),

                // Multiple Links Section
              DynamicLinkSection<CourseLink>(
                title: 'Links',
                items: _links,
                onAdd: (url, desc) {
                  setState(() {
                    _links.add(CourseLink(url: url, description: desc));
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

              // Timeline/Dates Section
              DynamicTimelineSection<CourseDate>(
                title: 'Timeline',
                items: _timeline,
                onAdd: (date, desc) {
                  setState(() {
                    _timeline.add(CourseDate(date: date, description: desc));
                    // Sort timeline by date
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

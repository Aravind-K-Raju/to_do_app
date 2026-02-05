import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_link.dart';
import '../../domain/entities/course_date.dart';
import '../providers/course_provider.dart';

class CourseAddEditScreen extends StatefulWidget {
  final Course? course;

  const CourseAddEditScreen({super.key, this.course});

  @override
  State<CourseAddEditScreen> createState() => _CourseAddEditScreenState();
}

class _CourseAddEditScreenState extends State<CourseAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController
  _sourceNameController; // For Site Name, Platform Name, or Source
  late TextEditingController _channelNameController; // For YouTube Channel etc.
  late TextEditingController _descriptionController;

  CourseType _type = CourseType.site;
  String _status = 'planned';
  DateTime _startDate = DateTime.now();

  // Dynamic Lists
  List<CourseLink> _links = [];
  List<CourseDate> _timeline = [];

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
    _descriptionController = TextEditingController(
      text: widget.course?.description ?? '',
    );

    if (widget.course != null) {
      _type = widget.course!.type;
      _status = widget.course!.status;
      _startDate = widget.course!.startDate;
      _links = List.from(widget.course!.links);
      _timeline = List.from(widget.course!.timeline);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceNameController.dispose();
    _channelNameController.dispose();
    _descriptionController.dispose();
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

  void _addLink() {
    final urlController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Link'),
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
                    CourseLink(
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
                  decoration: const InputDecoration(
                    labelText: 'Description (e.g., Started module 1)',
                  ),
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
                        CourseDate(
                          date: selectedDate,
                          description: descController.text,
                        ),
                      );
                      // Sort timeline by date
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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course == null ? 'Add Project' : 'Edit Project'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveCourse),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),

              // Type Selection
              DropdownButtonFormField<CourseType>(
                value: _type,
                items: CourseType.values.map((t) {
                  String label = t.toString().split('.').last;
                  label = label[0].toUpperCase() + label.substring(1);
                  if (label == 'SelfPaced') label = 'Self Paced';
                  return DropdownMenuItem(value: t, child: Text(label));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _type = val!;
                    // Clear fields if switching types makes them irrelevant?
                    // Keeping text might be better for UX if user switches back.
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic Fields based on Type
              if (_type == CourseType.site) ...[
                Consumer<CourseProvider>(
                  builder: (context, provider, child) {
                    return Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<String>.empty();
                        }
                        return provider.distinctSites.where((String option) {
                          return option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          );
                        });
                      },
                      onSelected: (String selection) {
                        _sourceNameController.text = selection;
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            // Sync provided controller with ours
                            if (textEditingController.text !=
                                    _sourceNameController.text &&
                                _sourceNameController.text.isNotEmpty &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  _sourceNameController.text;
                            }
                            textEditingController.addListener(() {
                              _sourceNameController.text =
                                  textEditingController.text;
                            });

                            return TextFormField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              onFieldSubmitted: (String value) {
                                onFieldSubmitted();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Site Name',
                                border: OutlineInputBorder(),
                                helperText: 'Select from existing or type new',
                              ),
                              validator: (val) =>
                                  val!.isEmpty ? 'Enter Site Name' : null,
                            );
                          },
                    );
                  },
                ),
              ],

              if (_type == CourseType.platform) ...[
                TextFormField(
                  controller: _sourceNameController,
                  decoration: const InputDecoration(
                    labelText: 'Platform Name (e.g., YouTube)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val!.isEmpty ? 'Enter Platform Name' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _channelNameController,
                  decoration: const InputDecoration(
                    labelText: 'Channel/Creator Name (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              if (_type == CourseType.selfPaced) ...[
                TextFormField(
                  controller: _sourceNameController,
                  decoration: const InputDecoration(
                    labelText: 'Source / Institution',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val!.isEmpty ? 'Enter Source' : null,
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      items: ['planned', 'ongoing', 'completed']
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s[0].toUpperCase() + s.substring(1)),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _status = val!),
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(
                        onPicked: (d) => setState(() => _startDate = d),
                      ),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat.yMMMd().format(_startDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Multiple Links Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Links',
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
                  'No links added.',
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

              // Timeline/Dates Section
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

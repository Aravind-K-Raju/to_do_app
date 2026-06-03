import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import '../providers/course_provider.dart';
import '../providers/draft_provider.dart';
import '../widgets/form/styled_app_bar.dart';
import '../widgets/form/styled_form_field.dart';

class TaskAddEditScreen extends StatefulWidget {
  final DateTime initialDate;
  final Task? task;

  const TaskAddEditScreen({super.key, required this.initialDate, this.task});

  @override
  State<TaskAddEditScreen> createState() => _TaskAddEditScreenState();
}

class _TaskAddEditScreenState extends State<TaskAddEditScreen> with WidgetsBindingObserver {
  late TextEditingController _titleController;
  TimeOfDay? _selectedTime;
  int? _selectedCourseId;
  bool _isSaved = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _selectedCourseId = widget.task?.courseId;
    if (widget.task?.dueDate != null) {
      _selectedTime = TimeOfDay(hour: widget.task!.dueDate!.hour, minute: widget.task!.dueDate!.minute);
    }
    _loadDraft();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadDraft() async {
    if (widget.task != null) return;
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final draftJson = await draftProvider.getDraft('draft_task');
    if (draftJson != null && mounted) {
      try {
        final data = jsonDecode(draftJson);
        setState(() {
          _titleController.text = data['title'] ?? '';
          _selectedCourseId = data['courseId'];
          if (data['hour'] != null && data['minute'] != null) {
            _selectedTime = TimeOfDay(hour: data['hour'], minute: data['minute']);
          }
        });
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  bool _hasData() {
    return _titleController.text.isNotEmpty;
  }

  Future<void> _saveDraft() async {
    if (widget.task != null) return;
    if (_hasData()) {
      final draftData = {
        'title': _titleController.text,
        'courseId': _selectedCourseId,
        'hour': _selectedTime?.hour,
        'minute': _selectedTime?.minute,
      };
      await Provider.of<DraftProvider>(context, listen: false).saveDraft('draft_task', jsonEncode(draftData));
    } else {
      await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_task');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isSaved) _saveDraft();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    if (widget.task != null) {
      setState(() { _canPop = true; });
      Navigator.pop(context);
      return;
    }
    if (!_isSaved) {
      if (_hasData()) {
        await _saveDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
      } else {
        await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_task');
      }
    }
    setState(() { _canPop = true; });
    if (mounted) Navigator.pop(context);
  }

  void _saveTask() {
    if (_titleController.text.isNotEmpty) {
      final DateTime finalDueDate = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
        _selectedTime?.hour ?? 0,
        _selectedTime?.minute ?? 0,
      );

      final taskProvider = Provider.of<TaskProvider>(context, listen: false);

      if (widget.task != null) {
        final updatedTask = Task(
          id: widget.task!.id,
          title: _titleController.text,
          isCompleted: widget.task!.isCompleted,
          dueDate: finalDueDate,
          courseId: _selectedCourseId,
          description: widget.task!.description,
        );
        taskProvider.editTask(updatedTask);
      } else {
        final newTask = Task(
          title: _titleController.text,
          isCompleted: false,
          dueDate: finalDueDate,
          courseId: _selectedCourseId,
        );
        taskProvider.addTask(newTask);
      }
      
      _isSaved = true;
      if (widget.task == null) {
        Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_task');
      }
      
      setState(() { _canPop = true; });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);
    
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleDismiss();
      },
      child: Scaffold(
        appBar: StyledAppBar(
          title: widget.task != null ? 'Edit Task' : 'Add Task',
          subtitle: widget.task != null ? 'Modify your task details' : 'Create a new task for this day',
          onBack: _handleDismiss,
          onSave: _saveTask,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Form(
            child: ListView(
              children: [
                const SizedBox(height: 16),
                StyledFormField(
                  label: 'Title',
                  icon: Icons.task_alt,
                  iconColor: const Color(0xFF7C3AED),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(hintText: 'Enter task title'),
                    autofocus: true,
                  ),
                ),
                
                StyledFormField(
                  label: 'Link to Course (Optional)',
                  icon: Icons.link,
                  iconColor: const Color(0xFF10B981),
                  trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  child: DropdownButtonFormField<int>(
                    value: _selectedCourseId,
                    icon: const SizedBox.shrink(),
                    hint: const Text('Select a course', style: TextStyle(color: Colors.grey)),
                    items: courseProvider.courses
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.title.length > 20 ? '${c.title.substring(0, 20)}...' : c.title),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCourseId = val),
                  ),
                ),

                StyledFormField(
                  label: 'Time',
                  icon: Icons.access_time,
                  iconColor: const Color(0xFFF59E0B),
                  trailing: const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => _selectedTime = time);
                    }
                  },
                  child: Text(
                    _selectedTime != null ? _selectedTime!.format(context) : 'Select a time',
                    style: TextStyle(color: _selectedTime != null ? Colors.white : Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

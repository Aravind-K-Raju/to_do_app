import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../domain/entities/assignment.dart';
import '../providers/assignment_provider.dart';
import '../providers/draft_provider.dart';
import '../widgets/form/styled_app_bar.dart';
import '../widgets/form/styled_form_field.dart';

class AssignmentAddEditScreen extends StatefulWidget {
  final Assignment? assignment;

  const AssignmentAddEditScreen({super.key, this.assignment});

  @override
  State<AssignmentAddEditScreen> createState() =>
      _AssignmentAddEditScreenState();
}

class _AssignmentAddEditScreenState extends State<AssignmentAddEditScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _descriptionController;

  String _selectedType = 'Assignment';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  
  bool _isSaved = false;
  bool _canPop = false;

  final List<String> _types = [
    'Assignment',
    'Project',
    'Exam',
    'Quiz',
    'Presentation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.assignment?.title ?? '',
    );
    _subjectController = TextEditingController(
      text: widget.assignment?.subject ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.assignment?.description ?? '',
    );

    if (widget.assignment != null) {
      _selectedType = widget.assignment!.type;
      _dueDate = widget.assignment!.dueDate;
    } else {
      _loadDraft();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadDraft() async {
    final draftProvider = Provider.of<DraftProvider>(context, listen: false);
    final draftJson = await draftProvider.getDraft('draft_assignment');
    if (draftJson != null && mounted) {
      try {
        final data = jsonDecode(draftJson);
        setState(() {
          _titleController.text = data['title'] ?? '';
          _subjectController.text = data['subject'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          if (data['type'] != null && _types.contains(data['type'])) {
            _selectedType = data['type'];
          }
        });
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  bool _hasData() {
    return _titleController.text.isNotEmpty || _subjectController.text.isNotEmpty || _descriptionController.text.isNotEmpty;
  }

  Future<void> _saveDraft() async {
    if (_hasData()) {
      final draftData = {
        'title': _titleController.text,
        'subject': _subjectController.text,
        'description': _descriptionController.text,
        'type': _selectedType,
      };
      await Provider.of<DraftProvider>(context, listen: false).saveDraft('draft_assignment', jsonEncode(draftData));
    } else {
      await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_assignment');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isSaved && widget.assignment == null) {
        _saveDraft();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newAssignment = Assignment(
        id: widget.assignment?.id,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        subject: _subjectController.text.isEmpty
            ? null
            : _subjectController.text,
        type: _selectedType,
        dueDate: _dueDate,
        isCompleted: widget.assignment?.isCompleted ?? false,
      );

      final provider = Provider.of<AssignmentProvider>(context, listen: false);
      if (widget.assignment == null) {
        provider.add(newAssignment);
      } else {
        provider.update(newAssignment);
      }
      
      _isSaved = true;
      if (widget.assignment == null) {
        Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_assignment');
      }
      setState(() { _canPop = true; });
      Navigator.pop(context);
    }
  }

  Future<void> _handleBack() async {
    if (!_isSaved && widget.assignment == null) {
      if (_hasData()) {
        await _saveDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
        }
      } else {
        await Provider.of<DraftProvider>(context, listen: false).clearDraft('draft_assignment');
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
          title: widget.assignment == null ? 'Add Assignment' : 'Edit Assignment',
          subtitle: 'Track your academic tasks',
          onBack: _handleBack,
          onSave: _save,
          isEditMode: widget.assignment != null,
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
                  icon: Icons.assignment,
                  iconColor: const Color(0xFF7C3AED),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(hintText: 'Enter assignment title'),
                    validator: (val) => val!.isEmpty ? 'Enter title' : null,
                  ),
                ),
                
                StyledFormField(
                  label: 'Subject (e.g. Math)',
                  icon: Icons.menu_book,
                  iconColor: const Color(0xFF10B981),
                  child: TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(hintText: 'Enter subject name'),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: StyledFormField(
                        label: 'Type',
                        icon: Icons.category,
                        iconColor: const Color(0xFF3B82F6),
                        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          icon: const SizedBox.shrink(),
                          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => _selectedType = val!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StyledFormField(
                        label: 'Due Date',
                        icon: Icons.calendar_today,
                        iconColor: const Color(0xFFF43F5E),
                        trailing: const Icon(Icons.calendar_month, color: Colors.grey),
                        onTap: _selectDate,
                        child: Text(DateFormat.yMMMd().format(_dueDate)),
                      ),
                    ),
                  ],
                ),

                StyledFormField(
                  label: 'Description',
                  icon: Icons.description,
                  iconColor: const Color(0xFFF59E0B),
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(hintText: 'Add a short description...'),
                    maxLines: 3,
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

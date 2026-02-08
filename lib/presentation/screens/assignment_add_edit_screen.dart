import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/assignment.dart';
import '../providers/assignment_provider.dart';

class AssignmentAddEditScreen extends StatefulWidget {
  final Assignment? assignment;

  const AssignmentAddEditScreen({super.key, this.assignment});

  @override
  State<AssignmentAddEditScreen> createState() =>
      _AssignmentAddEditScreenState();
}

class _AssignmentAddEditScreenState extends State<AssignmentAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _descriptionController;

  String _selectedType = 'Assignment';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));

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
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assignment == null ? 'Add Assignment' : 'Edit Assignment',
        ),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
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
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject (e.g. Math)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat.yMMMd().format(_dueDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
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
            ],
          ),
        ),
      ),
    );
  }
}

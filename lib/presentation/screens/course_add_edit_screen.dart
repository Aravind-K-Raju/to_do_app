import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/course.dart';
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
  late TextEditingController _platformController;
  late TextEditingController _descriptionController;
  DateTime _startDate = DateTime.now();
  String _status = 'planned';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.course?.title ?? '');
    _platformController = TextEditingController(
      text: widget.course?.platform ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.course?.description ?? '',
    );
    if (widget.course != null) {
      _startDate = widget.course!.startDate;
      _status = widget.course!.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _platformController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _saveCourse() {
    if (_formKey.currentState!.validate()) {
      final newCourse = Course(
        id: widget.course?.id,
        title: _titleController.text,
        platform: _platformController.text,
        description: _descriptionController.text,
        startDate: _startDate,
        progressPercent: widget.course?.progressPercent ?? 0.0,
        status: _status,
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
        title: Text(widget.course == null ? 'Add Course' : 'Edit Course'),
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
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (val) => val!.isEmpty ? 'Enter title' : null,
              ),
              TextFormField(
                controller: _platformController,
                decoration: const InputDecoration(labelText: 'Platform'),
                validator: (val) => val!.isEmpty ? 'Enter platform' : null,
              ),
              DropdownButtonFormField<String>(
                value: _status,
                items: ['planned', 'ongoing', 'completed']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setState(() => _status = val!),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

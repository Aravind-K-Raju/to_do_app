import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/hackathon.dart';
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
  late TextEditingController _techStackController;
  late TextEditingController _outcomeController;
  late TextEditingController _linkController;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.hackathon?.name ?? '');
    _themeController = TextEditingController(
      text: widget.hackathon?.theme ?? '',
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
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _themeController.dispose();
    _techStackController.dispose();
    _outcomeController.dispose();
    _linkController.dispose();
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
        startDate: _startDate,
        endDate: _endDate,
        techStack: _techStackController.text,
        outcome: _outcomeController.text,
        projectLink: _linkController.text,
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
        title: Text(
          widget.hackathon == null ? 'Add Hackathon' : 'Edit Hackathon',
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
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Event Name'),
                validator: (val) => val!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _themeController,
                decoration: const InputDecoration(labelText: 'Theme / Topic'),
              ),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(true),
              ),
              ListTile(
                title: const Text('End Date (Optional)'),
                subtitle: Text(
                  _endDate != null
                      ? DateFormat.yMMMd().format(_endDate!)
                      : 'Not Set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(false),
              ),
              TextFormField(
                controller: _techStackController,
                decoration: const InputDecoration(labelText: 'Tech Stack Used'),
              ),
              TextFormField(
                controller: _outcomeController,
                decoration: const InputDecoration(
                  labelText: 'Outcome / Result',
                ),
              ),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Project Link / Repo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

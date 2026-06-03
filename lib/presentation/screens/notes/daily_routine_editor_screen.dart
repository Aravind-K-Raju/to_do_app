import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/services/notification_prefs_service.dart';

class DailyRoutineEditorScreen extends StatefulWidget {
  const DailyRoutineEditorScreen({super.key});

  @override
  State<DailyRoutineEditorScreen> createState() => _DailyRoutineEditorScreenState();
}

class _DailyRoutineEditorScreenState extends State<DailyRoutineEditorScreen>
    with SingleTickerProviderStateMixin {
  final _prefsService = NotificationPrefsService();
  late TabController _tabController;

  List<Map<String, String>> _workingRoutine = [];
  List<Map<String, String>> _holidayRoutine = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRoutines();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutines() async {
    final workingStr = await _prefsService.getWorkingRoutine();
    final holidayStr = await _prefsService.getHolidayRoutine();

    List<Map<String, String>> parsedWorking = [];
    List<Map<String, String>> parsedHoliday = [];

    try {
      final List decodedW = jsonDecode(workingStr);
      parsedWorking = decodedW.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {}

    try {
      final List decodedH = jsonDecode(holidayStr);
      parsedHoliday = decodedH.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _workingRoutine = parsedWorking;
        _holidayRoutine = parsedHoliday;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRoutines() async {
    setState(() => _isLoading = true);
    await _prefsService.setWorkingRoutine(jsonEncode(_workingRoutine));
    await _prefsService.setHolidayRoutine(jsonEncode(_holidayRoutine));
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily routine presets saved successfully.')),
      );
    }
  }

  void _resetToDefault(int tabIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15151D),
        title: const Text('Reset Preset?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reset the ${tabIndex == 0 ? "Working Days" : "Holidays"} routine to its original default preset?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (tabIndex == 0) {
                  final decoded = jsonDecode(NotificationPrefsService.defaultDailyRoutine) as List;
                  _workingRoutine = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
                } else {
                  final decoded = jsonDecode(NotificationPrefsService.defaultHolidayRoutine) as List;
                  _holidayRoutine = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
                }
              });
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addSlot(int tabIndex) {
    setState(() {
      final list = tabIndex == 0 ? _workingRoutine : _holidayRoutine;
      list.add({'time': '08:00 AM', 'activity': ''});
    });
  }

  void _removeSlot(int tabIndex, int index) {
    setState(() {
      final list = tabIndex == 0 ? _workingRoutine : _holidayRoutine;
      list.removeAt(index);
    });
  }

  void _onReorder(int tabIndex, int oldIndex, int newIndex) {
    setState(() {
      final list = tabIndex == 0 ? _workingRoutine : _holidayRoutine;
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
  }

  Future<void> _pickTime(int tabIndex, int index) async {
    final list = tabIndex == 0 ? _workingRoutine : _holidayRoutine;
    final item = list[index];

    TimeOfDay initial = const TimeOfDay(hour: 8, minute: 0);
    try {
      final timeStr = item['time']!;
      final parts = timeStr.split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && h != 12) h += 12;
        if (parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
      }
      initial = TimeOfDay(hour: h, minute: m);
    } catch (_) {}

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null && mounted) {
      setState(() {
        list[index]['time'] = picked.format(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Routine Presets', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF7C3AED),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Working Days'),
            Tab(text: 'Holidays Preset'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveRoutines,
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildRoutineList(0, _workingRoutine),
                  _buildRoutineList(1, _holidayRoutine),
                ],
              ),
      ),
    );
  }

  Widget _buildRoutineList(int tabIndex, List<Map<String, String>> routine) {
    if (routine.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No baseline slots added yet.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Routine Block', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              onPressed: () => _addSlot(tabIndex),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Drag items by the handle to reorder.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14, color: Colors.amberAccent),
                label: const Text('Reset Default', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                onPressed: () => _resetToDefault(tabIndex),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: routine.length,
            onReorder: (oldIdx, newIdx) => _onReorder(tabIndex, oldIdx, newIdx),
            itemBuilder: (context, index) {
              final item = routine[index];
              return Container(
                key: ValueKey('slot_${tabIndex}_${index}_${item['time']}'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF15151D).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    // Drag Handle
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_indicator, color: Colors.white38),
                    ),
                    const SizedBox(width: 12),
                    
                    // Time Picker
                    InkWell(
                      onTap: () => _pickTime(tabIndex, index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F111A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                        ),
                        child: Text(
                          item['time'] ?? '08:00 AM',
                          style: const TextStyle(fontSize: 13, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Activity Input
                    Expanded(
                      child: TextFormField(
                        initialValue: item['activity'],
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Activity description...',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          fillColor: const Color(0xFF0F111A),
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          routine[index]['activity'] = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _removeSlot(tabIndex, index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Add Button Footer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Timeline Slot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _addSlot(tabIndex),
          ),
        ),
      ],
    );
  }
}

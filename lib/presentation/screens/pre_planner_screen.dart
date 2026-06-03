import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/notification_prefs_service.dart';
import '../../core/services/gemini_service.dart';
import '../providers/intelligence_provider.dart';

class PrePlannerScreen extends StatefulWidget {
  const PrePlannerScreen({super.key});

  @override
  State<PrePlannerScreen> createState() => _PrePlannerScreenState();
}

class _PrePlannerScreenState extends State<PrePlannerScreen> {
  final _prefsService = NotificationPrefsService();
  
  List<Map<String, dynamic>> _customEvents = [];
  bool _isHolidayOverride = false;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _errorMessage;

  // Form Fields
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  final _durationController = TextEditingController();

  late DateTime _targetDate;
  late String _targetDateStr;

  @override
  void initState() {
    super.initState();
    // Default to planning for today or tomorrow if it is already late evening
    final now = DateTime.now();
    if (now.hour >= 20) {
      _targetDate = now.add(const Duration(days: 1)); // Plan for tomorrow
    } else {
      _targetDate = now; // Plan for today
    }
    _targetDateStr = DateFormat('yyyy-MM-dd').format(_targetDate);
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _timeController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 1. Load Pre-planned custom events
    final eventsJson = await _prefsService.getPrePlannedEvents();
    if (eventsJson != null) {
      try {
        final List decoded = jsonDecode(eventsJson);
        _customEvents = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        debugPrint('[PrePlanner] Error decoding preplanned events: $e');
      }
    }

    // 2. Load Holiday / Working Day manual override
    final manualHoliday = await _prefsService.getManualHolidayOverride(_targetDateStr);
    if (manualHoliday != null) {
      _isHolidayOverride = manualHoliday;
    } else {
      // Fallback to checking default logic (e.g. weekends)
      _isHolidayOverride = await _prefsService.checkIsHoliday(_targetDate);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    await _prefsService.setPrePlannedEvents(jsonEncode(_customEvents));
    await _prefsService.setManualHolidayOverride(_targetDateStr, _isHolidayOverride);
  }

  void _addCustomEvent() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final startTime = _timeController.text.trim();
    final duration = _durationController.text.trim();

    setState(() {
      _customEvents.add({
        'title': title,
        'startTime': startTime.isNotEmpty ? startTime : null,
        'duration': duration.isNotEmpty ? duration : null,
      });
      _titleController.clear();
      _timeController.clear();
      _durationController.clear();
    });
    _saveData();
  }

  void _deleteCustomEvent(int index) {
    setState(() {
      _customEvents.removeAt(index);
    });
    _saveData();
  }

  Future<void> _generatePlanWithAI() async {
    // 1. Load academic stats/data before async gap
    final provider = Provider.of<IntelligenceProvider>(context, listen: false);
    final stats = provider.insightsData;
    if (stats == null) {
      setState(() {
        _errorMessage = 'Academic data is not loaded. Please return to the dashboard and try again.';
      });
      return;
    }

    final apiKey = await _prefsService.getGeminiApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please configure your Gemini API Key in Settings first.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // 2. Ensure latest override settings are persisted
      await _saveData();

      // 3. Load baseline routine
      final routineStr = await _prefsService.getDailyRoutine(date: _targetDate);
      final List decodedRoutine = jsonDecode(routineStr);
      final List<Map<String, dynamic>> routineList =
          decodedRoutine.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final todayStart = DateTime(_targetDate.year, _targetDate.month, _targetDate.day);

      // 4. Gather only active items (exclude if end-dated / past due)
      final coursesMap = stats.activeCourses.map((c) => {
        'title': c.title,
        'description': c.description ?? '',
      }).toList();

      final tasksMap = stats.pendingTasks.where((t) {
        if (t.dueDate == null) return true;
        final taskDate = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        return !taskDate.isBefore(todayStart);
      }).map((t) => {
        'title': t.title,
        'description': t.description ?? '',
      }).toList();

      final assignmentsMap = stats.pendingAssignments.where((a) {
        final assignmentDate = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
        return !assignmentDate.isBefore(todayStart);
      }).map((a) => {
        'title': a.title,
        'description': a.description ?? '',
        'subject': a.subject ?? '',
        'type': a.type,
      }).toList();

      final eventsMap = stats.upcomingEvents.where((e) {
        final compareDate = e.endDate ?? e.startDate;
        final eventDate = DateTime(compareDate.year, compareDate.month, compareDate.day);
        return !eventDate.isBefore(todayStart);
      }).map((e) => {
        'name': e.name,
        'description': e.description ?? '',
      }).toList();

      // 5. Generate plan using Gemini with Pre-Planned events!
      final newPlan = await GeminiService.generatePlan(
        apiKey: apiKey,
        routine: routineList,
        tasks: tasksMap,
        courses: coursesMap,
        assignments: assignmentsMap,
        events: eventsMap,
        prePlannedEvents: _customEvents,
      );

      final newPlanJson = jsonEncode(newPlan);
      await _prefsService.setAiDayPlanJson(newPlanJson);
      await _prefsService.setAiDayPlanDate(_targetDateStr);
      await _prefsService.setAiDayPlanTimestamp(DateTime.now().millisecondsSinceEpoch.toString());

      if (mounted) {
        Navigator.pop(context, true); // Pop back and trigger reload
      }
    } catch (e) {
      debugPrint('[PrePlanner] Plan generation error: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Planning failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMMM d, yyyy').format(_targetDate);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0C10),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Day Pre-Planner',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Day summary header
                Text(
                  'Planning for: $formattedDate',
                  style: const TextStyle(fontSize: 14, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // Manual Toggle Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151724),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mark as Holiday',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Uses Holiday routine baseline preset',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isHolidayOverride,
                        activeColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          setState(() {
                            _isHolidayOverride = val;
                          });
                          _saveData();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form to Add Custom Event
                const Text(
                  'Add Miscellaneous Temporary Event',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151724),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Event Title (Required)',
                          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          hintText: 'e.g. Travel to Mumbai, Work at Home',
                          filled: true,
                          fillColor: const Color(0xFF0F111A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _timeController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Start Time (Optional)',
                                labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                hintText: 'e.g. 05:00 AM',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.access_time, size: 18, color: Colors.grey),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: const TimeOfDay(hour: 8, minute: 0),
                                    );
                                    if (picked != null) {
                                      final hour = picked.hourOfPeriod;
                                      final minute = picked.minute.toString().padLeft(2, '0');
                                      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
                                      final formattedTime = '${hour == 0 ? 12 : hour}:$minute $period';
                                      if (mounted) {
                                        _timeController.text = formattedTime;
                                      }
                                    }
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0F111A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Duration / End (Opt)',
                                labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                hintText: 'e.g. 2 hours or 8:00 AM',
                                filled: true,
                                fillColor: const Color(0xFF0F111A),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 14, color: Colors.white),
                          label: const Text('Add to Tomorrow\'s Plan', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _addCustomEvent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Added Events List
                const Text(
                  'Added Pre-Planned Events',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                _customEvents.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151724).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                        ),
                        child: const Center(
                          child: Text(
                            'No custom events added yet. Type an event title above to get started.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _customEvents.length,
                        itemBuilder: (context, index) {
                          final event = _customEvents[index];
                          final hasTime = event['startTime'] != null;
                          final hasDuration = event['duration'] != null;
                          return Card(
                            color: const Color(0xFF151724),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.event_note, color: Colors.tealAccent),
                              title: Text(
                                event['title'] as String,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Text(
                                [
                                  if (hasTime) 'Starts: ${event['startTime']}',
                                  if (hasDuration) 'Duration: ${event['duration']}',
                                  if (!hasTime && !hasDuration) 'Time varies / flexible',
                                ].join(' | '),
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteCustomEvent(index),
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 100), // padding at bottom
              ],
            ),
          ),

          // Generating Overlay
          if (_isGenerating)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151724),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.2)),
                      ),
                      child: const Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFF7C3AED)),
                          SizedBox(height: 16),
                          Text(
                            'Gemini AI is generating your schedule...',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Rescheduling routine blocks to match pre-plans',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error banner
          if (_errorMessage != null)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF0F111A),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            label: const Text(
              'Optimize & Generate Day Plan',
              style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isGenerating ? null : _generatePlanWithAI,
          ),
        ),
      ),
    );
  }
}

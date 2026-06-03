import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/notification_prefs_service.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/services/notification_service.dart';
import '../screens/notes/daily_routine_editor_screen.dart';

class NotificationSettingsDialog extends StatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  State<NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<NotificationSettingsDialog> {
  final _prefsService = NotificationPrefsService();
  final _notificationService = NotificationService();

  TimeOfDay _selectedTime = NotificationPrefsService.defaultTime;
  bool _notifySameDay = NotificationPrefsService.defaultSameDay;
  bool _notify1DayBefore = NotificationPrefsService.default1DayBefore;
  bool _notify3DaysBefore = NotificationPrefsService.default3DaysBefore;
  
  // AI Settings State
  final _apiKeyController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  bool _obscureApiKey = true;
  bool _showAiSettings = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final time = await _prefsService.getNotificationTime();
    final sameDay = await _prefsService.getNotifySameDay();
    final oneDay = await _prefsService.getNotify1DayBefore();
    final threeDays = await _prefsService.getNotify3DaysBefore();
    
    final apiKey = await _prefsService.getGeminiApiKey();
    final country = await _prefsService.getRegionCountry();
    final state = await _prefsService.getRegionState();

    if (mounted) {
      setState(() {
        _selectedTime = time;
        _notifySameDay = sameDay;
        _notify1DayBefore = oneDay;
        _notify3DaysBefore = threeDays;
        
        _apiKeyController.text = apiKey ?? '';
        _countryController.text = country;
        _stateController.text = state;
        
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    setState(() => _isLoading = true);

    try {
      // Request permissions if not granted
      await _notificationService.requestPermissions();

      await _prefsService.setNotificationTime(_selectedTime);
      await _prefsService.setNotifySameDay(_notifySameDay);
      await _prefsService.setNotify1DayBefore(_notify1DayBefore);
      await _prefsService.setNotify3DaysBefore(_notify3DaysBefore);
      
      // Save AI parameters
      await _prefsService.setGeminiApiKey(_apiKeyController.text.trim());
      await _prefsService.setRegionCountry(_countryController.text.trim());
      await _prefsService.setRegionState(_stateController.text.trim());

      if (mounted) {
        // Trigger reschedule
        await NotificationScheduler.rescheduleAll(context);
        if (mounted) {
          navigator.pop();
          messenger.showSnackBar(
            const SnackBar(content: Text('Notification & AI settings saved.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading settings...'),
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF15151D),
      title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure notifications & daily plan AI parameters.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notification Time', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(_selectedTime.format(context), style: const TextStyle(color: Colors.tealAccent)),
                trailing: const Icon(Icons.access_time, color: Colors.tealAccent),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (picked != null) {
                    setState(() => _selectedTime = picked);
                  }
                },
              ),
              const Divider(color: Colors.white10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF7C3AED),
                title: const Text('On the day of the event', style: TextStyle(color: Colors.white70, fontSize: 14)),
                value: _notifySameDay,
                onChanged: (val) => setState(() => _notifySameDay = val ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF7C3AED),
                title: const Text('1 day before', style: TextStyle(color: Colors.white70, fontSize: 14)),
                value: _notify1DayBefore,
                onChanged: (val) =>
                    setState(() => _notify1DayBefore = val ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF7C3AED),
                title: const Text('3 days before', style: TextStyle(color: Colors.white70, fontSize: 14)),
                value: _notify3DaysBefore,
                onChanged: (val) =>
                    setState(() => _notify3DaysBefore = val ?? false),
              ),
              const Divider(color: Colors.white10),
              
              // AI Day Planner Settings Expander
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Update AI Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC4B5FD)),
                ),
                subtitle: const Text('Gemini API, holiday parameters & presets', style: TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: Icon(
                  _showAiSettings ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color(0xFF7C3AED),
                ),
                onTap: () => setState(() => _showAiSettings = !_showAiSettings),
              ),
              
              if (_showAiSettings) ...[
                const SizedBox(height: 8),
                // API Key Textfield
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F111A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                
                const SizedBox(height: 16),
                const Text(
                  'Region (for AI Holiday Checks)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _countryController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Country',
                          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
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
                        controller: _stateController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'State / Province',
                          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
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
                
                // Link to full screen drag-reorder preset manager
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_calendar, size: 14, color: Color(0xFFC4B5FD)),
                    label: const Text(
                      'Manage Daily Routine Presets',
                      style: TextStyle(fontSize: 12, color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DailyRoutineEditorScreen(),
                        ),
                      ).then((changed) {
                        if (changed == true) {
                          _loadSettings();
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range_outlined, size: 14, color: Colors.amberAccent),
                    label: const Text(
                      'Manage Custom Date Overrides',
                      style: TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amberAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => _CustomOverridesDialog(prefsService: _prefsService),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _saveSettings,
          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _CustomOverridesDialog extends StatefulWidget {
  final NotificationPrefsService prefsService;
  const _CustomOverridesDialog({required this.prefsService});

  @override
  State<_CustomOverridesDialog> createState() => _CustomOverridesDialogState();
}

class _CustomOverridesDialogState extends State<_CustomOverridesDialog> {
  Set<String> _holidayDates = {};
  bool _isLoading = true;

  // Month navigation state
  late int _currentYear;
  late int _currentMonth;

  // Pan gesture tracking
  int? _panStartDay;
  int? _panCurrentDay;
  bool _isUnselecting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
    _loadOverrides();
  }

  Future<void> _loadOverrides() async {
    final jsonStr = await widget.prefsService.getCustomDateOverrides();
    if (jsonStr != null) {
      try {
        final List decoded = jsonDecode(jsonStr);
        setState(() {
          _holidayDates = decoded.map((e) => e.toString()).toSet();
        });
      } catch (e) {
        debugPrint('Error loading overrides: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveOverrides() async {
    await widget.prefsService.setCustomDateOverrides(jsonEncode(_holidayDates.toList()));
  }

  String _getDateStr(int day) {
    return '$_currentYear-${_currentMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
  }

  void _prevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        backgroundColor: Color(0xFF15151D),
        content: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
      );
    }

    final totalDays = DateTime(_currentYear, _currentMonth + 1, 0).day;
    final startOffset = DateTime(_currentYear, _currentMonth, 1).weekday % 7;
    final monthName = DateFormat('MMMM').format(DateTime(_currentYear, _currentMonth));

    final today = DateTime.now();
    final bool isCurrentMonth = today.year == _currentYear && today.month == _currentMonth;

    return AlertDialog(
      backgroundColor: const Color(0xFF15151D),
      title: const Text('Holiday Overrides Calendar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: SizedBox(
        width: 320,
        height: 380,
        child: Column(
          children: [
            const Text(
              'Click to toggle a holiday. Click and drag / slide to select a holiday date range.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Month Switcher Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Color(0xFFC4B5FD)),
                  onPressed: _prevMonth,
                ),
                Text(
                  '$monthName $_currentYear',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Color(0xFFC4B5FD)),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Weekdays row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _WeekdayHeader('S'),
                _WeekdayHeader('M'),
                _WeekdayHeader('T'),
                _WeekdayHeader('W'),
                _WeekdayHeader('T'),
                _WeekdayHeader('F'),
                _WeekdayHeader('S'),
              ],
            ),
            const SizedBox(height: 6),

            // Custom month calendar grid wrapping gestures
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cellW = constraints.maxWidth / 7;
                  final cellH = constraints.maxHeight / 6;

                  return GestureDetector(
                    onPanStart: (details) {
                      final localPos = details.localPosition;
                      final col = (localPos.dx / cellW).floor();
                      final row = (localPos.dy / cellH).floor();

                      if (col >= 0 && col < 7 && row >= 0 && row < 6) {
                        final day = row * 7 + col - startOffset + 1;
                        if (day >= 1 && day <= totalDays) {
                          setState(() {
                            _panStartDay = day;
                            _panCurrentDay = day;
                            _isUnselecting = _holidayDates.contains(_getDateStr(day));
                          });
                        }
                      }
                    },
                    onPanUpdate: (details) {
                      final localPos = details.localPosition;
                      final col = (localPos.dx / cellW).floor();
                      final row = (localPos.dy / cellH).floor();

                      if (col >= 0 && col < 7 && row >= 0 && row < 6) {
                        final day = row * 7 + col - startOffset + 1;
                        if (day >= 1 && day <= totalDays) {
                          setState(() {
                            _panCurrentDay = day;
                          });
                        }
                      }
                    },
                    onPanEnd: (details) {
                      if (_panStartDay != null && _panCurrentDay != null) {
                        if (_panStartDay == _panCurrentDay) {
                          // Single click to toggle
                          final dateStr = _getDateStr(_panStartDay!);
                          setState(() {
                            if (_holidayDates.contains(dateStr)) {
                              _holidayDates.remove(dateStr);
                            } else {
                              _holidayDates.add(dateStr);
                            }
                          });
                        } else {
                          // Slide select/unselect range
                          final start = min(_panStartDay!, _panCurrentDay!);
                          final end = max(_panStartDay!, _panCurrentDay!);
                          setState(() {
                            if (_isUnselecting) {
                              for (int d = start; d <= end; d++) {
                                _holidayDates.remove(_getDateStr(d));
                              }
                            } else {
                              for (int d = start; d <= end; d++) {
                                _holidayDates.add(_getDateStr(d));
                              }
                            }
                          });
                        }
                        _saveOverrides();
                      }
                      setState(() {
                        _panStartDay = null;
                        _panCurrentDay = null;
                        _isUnselecting = false;
                      });
                    },
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 42,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                      ),
                      itemBuilder: (context, index) {
                        final day = index - startOffset + 1;
                        if (day < 1 || day > totalDays) {
                          return const SizedBox();
                        }

                        final dateStr = _getDateStr(day);
                        final isHoliday = _holidayDates.contains(dateStr);
                        final isToday = isCurrentMonth && today.day == day;

                        // Check if in active drag highlight range
                        final isHighlighted = _panStartDay != null &&
                            _panCurrentDay != null &&
                            day >= min(_panStartDay!, _panCurrentDay!) &&
                            day <= max(_panStartDay!, _panCurrentDay!);

                        return Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isHoliday
                                  ? const Color(0xFF10B981) // Emerald marked holiday color
                                  : (isHighlighted
                                      ? (_isUnselecting
                                          ? const Color(0xFFEF4444).withAlpha(76) // Crimson drag unhighlight
                                          : const Color(0xFF7C3AED).withAlpha(76)) // Purple drag highlight
                                      : Colors.transparent),
                              border: isToday
                                  ? Border.all(color: const Color(0xFF7C3AED), width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              day.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: (isHoliday || isToday) ? FontWeight.bold : FontWeight.normal,
                                color: isHoliday
                                    ? Colors.white
                                    : (isToday ? const Color(0xFFC4B5FD) : Colors.white70),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}


import 'package:flutter/material.dart';
import '../../core/services/notification_prefs_service.dart';
import '../../core/services/notification_scheduler.dart';
import '../../core/services/notification_service.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final time = await _prefsService.getNotificationTime();
    final sameDay = await _prefsService.getNotifySameDay();
    final oneDay = await _prefsService.getNotify1DayBefore();
    final threeDays = await _prefsService.getNotify3DaysBefore();

    if (mounted) {
      setState(() {
        _selectedTime = time;
        _notifySameDay = sameDay;
        _notify1DayBefore = oneDay;
        _notify3DaysBefore = threeDays;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      // Request permissions if not granted
      await _notificationService.requestPermissions();

      await _prefsService.setNotificationTime(_selectedTime);
      await _prefsService.setNotifySameDay(_notifySameDay);
      await _prefsService.setNotify1DayBefore(_notify1DayBefore);
      await _prefsService.setNotify3DaysBefore(_notify3DaysBefore);

      if (mounted) {
        // Trigger reschedule
        await NotificationScheduler.rescheduleAll(context);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification settings saved.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
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
      title: const Text('Notification Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select when you want to be notified for tasks, assignments, and events.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Notification Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.access_time),
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
            const Divider(),
            CheckboxListTile(
              title: const Text('On the day of the event'),
              value: _notifySameDay,
              onChanged: (val) => setState(() => _notifySameDay = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('1 day before'),
              value: _notify1DayBefore,
              onChanged: (val) =>
                  setState(() => _notify1DayBefore = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('3 days before'),
              value: _notify3DaysBefore,
              onChanged: (val) =>
                  setState(() => _notify3DaysBefore = val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveSettings, child: const Text('Save')),
      ],
    );
  }
}

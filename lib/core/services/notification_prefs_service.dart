import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationPrefsService {
  static const _storage = FlutterSecureStorage();

  static const _keyTimeHour = 'notification_time_hour';
  static const _keyTimeMinute = 'notification_time_minute';
  static const _keyNotifySameDay = 'notify_same_day';
  static const _keyNotify1DayBefore = 'notify_1_day_before';
  static const _keyNotify3DaysBefore = 'notify_3_days_before';

  // Default values
  static const TimeOfDay defaultTime = TimeOfDay(hour: 9, minute: 0);
  static const bool defaultSameDay = true;
  static const bool default1DayBefore = false;
  static const bool default3DaysBefore = false;

  Future<TimeOfDay> getNotificationTime() async {
    final hourStr = await _storage.read(key: _keyTimeHour);
    final minuteStr = await _storage.read(key: _keyTimeMinute);

    if (hourStr != null && minuteStr != null) {
      return TimeOfDay(hour: int.parse(hourStr), minute: int.parse(minuteStr));
    }
    return defaultTime;
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    await _storage.write(key: _keyTimeHour, value: time.hour.toString());
    await _storage.write(key: _keyTimeMinute, value: time.minute.toString());
  }

  Future<bool> getNotifySameDay() async {
    final val = await _storage.read(key: _keyNotifySameDay);
    return val != null ? val == 'true' : defaultSameDay;
  }

  Future<void> setNotifySameDay(bool value) async {
    await _storage.write(key: _keyNotifySameDay, value: value.toString());
  }

  Future<bool> getNotify1DayBefore() async {
    final val = await _storage.read(key: _keyNotify1DayBefore);
    return val != null ? val == 'true' : default1DayBefore;
  }

  Future<void> setNotify1DayBefore(bool value) async {
    await _storage.write(key: _keyNotify1DayBefore, value: value.toString());
  }

  Future<bool> getNotify3DaysBefore() async {
    final val = await _storage.read(key: _keyNotify3DaysBefore);
    return val != null ? val == 'true' : default3DaysBefore;
  }

  Future<void> setNotify3DaysBefore(bool value) async {
    await _storage.write(key: _keyNotify3DaysBefore, value: value.toString());
  }
}

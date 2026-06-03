import 'dart:convert';
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

  // Gemini AI Settings
  static const _keyGeminiApiKey = 'gemini_api_key';
  static const _keyDailyRoutine = 'daily_routine'; // legacy fallback
  static const _keyWorkingRoutine = 'working_daily_routine';
  static const _keyHolidayRoutine = 'holiday_daily_routine';
  static const _keyManualHolidayPrefix = 'manual_holiday_';
  static const _keyAiHolidayPrefix = 'ai_holiday_';

  static const _keyAiDayPlanJson = 'ai_day_plan_json';
  static const _keyAiDayPlanDate = 'ai_day_plan_date';
  static const _keyAiDayPlanTimestamp = 'ai_day_plan_timestamp';

  static const String defaultDailyRoutine = '''
[
  {"time": "08:00 AM", "activity": "Morning Routine & Breakfast"},
  {"time": "09:00 AM", "activity": "Core Work & Lectures"},
  {"time": "12:00 PM", "activity": "Lunch & Rest"},
  {"time": "02:00 PM", "activity": "Afternoon Coding/Study Session"},
  {"time": "06:00 PM", "activity": "Dinner & Relaxation"},
  {"time": "08:00 PM", "activity": "Evening Revision / Project Work"},
  {"time": "10:00 PM", "activity": "Wind-down & Sleep Preparation"}
]
''';

  static const String defaultHolidayRoutine = '''
[
  {"time": "09:00 AM", "activity": "Late Wakeup & Lazy Breakfast"},
  {"time": "10:30 AM", "activity": "Hobbies & Free Study / Skill Building"},
  {"time": "01:00 PM", "activity": "Lunch & Relaxation / Movie"},
  {"time": "04:00 PM", "activity": "Light Reading or Outdoor Walk"},
  {"time": "07:00 PM", "activity": "Dinner & Socializing"},
  {"time": "10:00 PM", "activity": "Wind-down & Late Sleep Preparation"}
]
''';

  Future<String?> getGeminiApiKey() async {
    return await _storage.read(key: _keyGeminiApiKey);
  }

  Future<void> setGeminiApiKey(String value) async {
    await _storage.write(key: _keyGeminiApiKey, value: value);
  }

  Future<String> getWorkingRoutine() async {
    final val = await _storage.read(key: _keyWorkingRoutine);
    if (val != null) return val;
    // Fall back to legacy key if it has value
    final legacy = await _storage.read(key: _keyDailyRoutine);
    return legacy ?? defaultDailyRoutine;
  }

  Future<void> setWorkingRoutine(String value) async {
    await _storage.write(key: _keyWorkingRoutine, value: value);
    await _storage.write(key: _keyDailyRoutine, value: value); // sync to legacy
  }

  Future<String> getHolidayRoutine() async {
    final val = await _storage.read(key: _keyHolidayRoutine);
    return val ?? defaultHolidayRoutine;
  }

  Future<void> setHolidayRoutine(String value) async {
    await _storage.write(key: _keyHolidayRoutine, value: value);
  }

  Future<bool?> getManualHolidayOverride(String dateStr) async {
    final val = await _storage.read(key: '$_keyManualHolidayPrefix$dateStr');
    if (val == null) return null;
    return val == 'true';
  }

  Future<void> setManualHolidayOverride(String dateStr, bool? val) async {
    if (val == null) {
      await _storage.delete(key: '$_keyManualHolidayPrefix$dateStr');
    } else {
      await _storage.write(key: '$_keyManualHolidayPrefix$dateStr', value: val.toString());
    }
  }

  Future<bool?> getAiHolidayCache(String dateStr) async {
    final val = await _storage.read(key: '$_keyAiHolidayPrefix$dateStr');
    if (val == null) return null;
    return val == 'true';
  }

  Future<void> setAiHolidayCache(String dateStr, bool val) async {
    await _storage.write(key: '$_keyAiHolidayPrefix$dateStr', value: val.toString());
  }

  Future<bool> checkIsHoliday(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    // 1. Custom date overrides (list of custom holiday date strings)
    final overridesJson = await getCustomDateOverrides();
    if (overridesJson != null) {
      try {
        final List decoded = jsonDecode(overridesJson);
        if (decoded.contains(dateStr)) {
          return true;
        }
      } catch (e) {
        debugPrint('[PrefsService] Error checking custom overrides: $e');
      }
    }

    // 2. Manual override
    final manual = await getManualHolidayOverride(dateStr);
    if (manual != null) {
      return manual;
    }
    
    // 3. Sundays
    if (date.weekday == DateTime.sunday) {
      return true;
    }
    
    // 4. 2nd & 4th Saturdays
    if (date.weekday == DateTime.saturday) {
      final day = date.day;
      if (day >= 8 && day <= 14) return true; // 2nd Saturday
      if (day >= 22 && day <= 28) return true; // 4th Saturday
    }
    
    // 5. AI checked public holiday cache
    final aiCache = await getAiHolidayCache(dateStr);
    if (aiCache != null) {
      return aiCache;
    }
    
    return false;
  }

  Future<String> getDailyRoutine({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final isHoliday = await checkIsHoliday(targetDate);
    if (isHoliday) {
      return await getHolidayRoutine();
    }
    return await getWorkingRoutine();
  }

  Future<void> setDailyRoutine(String value) async {
    await setWorkingRoutine(value);
  }

  Future<String?> getAiDayPlanJson() async {
    return await _storage.read(key: _keyAiDayPlanJson);
  }

  Future<void> setAiDayPlanJson(String value) async {
    await _storage.write(key: _keyAiDayPlanJson, value: value);
  }

  Future<String?> getAiDayPlanDate() async {
    return await _storage.read(key: _keyAiDayPlanDate);
  }

  Future<void> setAiDayPlanDate(String value) async {
    await _storage.write(key: _keyAiDayPlanDate, value: value);
  }

  Future<String?> getAiDayPlanTimestamp() async {
    return await _storage.read(key: _keyAiDayPlanTimestamp);
  }

  Future<void> setAiDayPlanTimestamp(String value) async {
    await _storage.write(key: _keyAiDayPlanTimestamp, value: value);
  }

  static const _keyCountry = 'region_country';
  static const _keyState = 'region_state';

  Future<String> getRegionCountry() async {
    final val = await _storage.read(key: _keyCountry);
    return val ?? 'India';
  }

  Future<void> setRegionCountry(String value) async {
    await _storage.write(key: _keyCountry, value: value);
  }

  Future<String> getRegionState() async {
    final val = await _storage.read(key: _keyState);
    return val ?? 'Kerala';
  }

  Future<void> setRegionState(String value) async {
    await _storage.write(key: _keyState, value: value);
  }

  static const _keyPrePlannedEvents = 'pre_planned_events_json';
  static const _keyCustomDateOverrides = 'custom_date_overrides_json';

  Future<String?> getPrePlannedEvents() async {
    return await _storage.read(key: _keyPrePlannedEvents);
  }

  Future<void> setPrePlannedEvents(String value) async {
    await _storage.write(key: _keyPrePlannedEvents, value: value);
  }

  Future<void> clearPrePlannedEvents() async {
    await _storage.delete(key: _keyPrePlannedEvents);
  }

  Future<String?> getCustomDateOverrides() async {
    return await _storage.read(key: _keyCustomDateOverrides);
  }

  Future<void> setCustomDateOverrides(String value) async {
    await _storage.write(key: _keyCustomDateOverrides, value: value);
  }

  Future<void> clearAiDayPlan() async {
    await _storage.delete(key: _keyAiDayPlanJson);
    await _storage.delete(key: _keyAiDayPlanDate);
    await _storage.delete(key: _keyAiDayPlanTimestamp);
  }
}

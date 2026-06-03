import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class GeminiService {
  /// Calls Gemini 2.5 Flash API using native HttpClient
  static Future<String> _callApi({
    required String apiKey,
    required String prompt,
  }) async {
    final client = HttpClient();
    // Configure timeouts (15 seconds)
    client.connectionTimeout = const Duration(seconds: 15);
    
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        }
      });
      
      request.write(body);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      
      if (response.statusCode != 200) {
        throw HttpException('Gemini API returned status ${response.statusCode}: $responseBody');
      }
      
      final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
      final candidates = jsonResponse['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map?;
        if (content != null) {
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String? ?? '';
          }
        }
      }
      throw const FormatException('Empty or malformed response structure from Gemini API');
    } finally {
      client.close();
    }
  }

  /// Builds prompt and generates initial daily plan
  static Future<List<Map<String, dynamic>>> generatePlan({
    required String apiKey,
    required List<Map<String, dynamic>> routine,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> courses,
    required List<Map<String, dynamic>> assignments,
    required List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> prePlannedEvents = const [],
  }) async {
    final prompt = '''
You are an expert daily planner AI assistant. Your goal is to analyze the student's standard daily routine, their scheduled academic items for today, and additional custom pre-planned temporary events, and construct the absolute best, optimized daily schedule.

User's Base Daily Routine (Baseline):
${jsonEncode(routine)}

User's Additional Pre-planned Custom Events for Today:
${jsonEncode(prePlannedEvents)}

Scheduled Academic Items for Today:
- Active Courses: ${jsonEncode(courses)}
- Active Tasks: ${jsonEncode(tasks)}
- Assignments Due: ${jsonEncode(assignments)}
- Upcoming Events/Hackathons: ${jsonEncode(events)}

Instructions:
1. DYNAMIC ROUTINE RESCHEDULING & SHIFTING (CRITICAL):
   - If the user has additional pre-planned custom events (e.g., an early travel block at 5:00 AM), you MUST dynamically shift and reschedule the standard daily routine blocks earlier or later so that the timeline remains chronologically correct and realistic!
   - For example, if they have "Morning Routine & Breakfast" at 8:00 AM in their baseline routine, but they have a custom pre-planned "Travel" starting at 5:00 AM, you should dynamically shift the baseline "Morning Routine & Breakfast" earlier (e.g., to 4:00 AM) to fit perfectly. Never let them overlap or conflict.

2. REALISTIC & ADEQUATE TIME ALLOCATION:
   - Analyze the nature of each task, course, assignment, or custom event and allocate a realistic, adequate block of time for it.
   - For instance, deep focus items (like Hackathons or complex project tasks) should receive sufficient time blocks (e.g. 1.5 to 3 hours), while courses should receive 1 to 2 hours. Do not cram too many items into unrealistic, overly short blocks just to check them off the list. Quality and depth of focus are preferred.

3. TIGHT-SCHEDULE EQUAL PRECEDENCE OPTIONS:
   - If the day's schedule becomes extremely tight/crowded, do not overpack it. Instead, choose a set of items of equal precedence for a specific block, and place them inside the "options" field for that schedule entry.
   - The user will then choose which one they like to proceed with that day. If "options" are present, keep the main "work" description generic (e.g. "Choose one focus activity:").

4. JSON SCHEMA FORMAT constraints:
   - You MUST return ONLY a valid JSON array of objects representing the daily timeline blocks. Each block MUST have the exact keys "time" and "work", and optionally "options".
   - "time" must be a time range (e.g., "08:00 AM - 09:30 AM" or "02:00 PM - 03:30 PM"). Use 12-hour format with AM/PM.
   - "work" must be a concise description of the activity (e.g., "Morning Routine & Breakfast", "Review Course: Machine Learning", "Choose focus activity").
   - "options" (Optional JSON array of strings) must list the equal-precedence tasks for that block if the schedule is crowded (e.g., ["Complete Physics Assignment", "Work on ML Project"]).
   - Return ONLY raw valid JSON array. Do not include markdown codeblocks or extra text.
''';

    final rawResponse = await _callApi(apiKey: apiKey, prompt: prompt);
    debugPrint('[GeminiService] Raw initial plan response: $rawResponse');
    
    return parseScheduleList(rawResponse);
  }

  /// Reschedules remaining timeline blocks when a task is paused or resumed.
  static Future<List<Map<String, dynamic>>> rescheduleRemainingPlan({
    required String apiKey,
    required List<Map<String, dynamic>> currentPlan,
    required String currentTaskTitle,
    required String action, // "pause" or "resume"
    required String timeStr, // e.g. "02:35 PM"
    required int remainingMinutes,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> courses,
    required List<Map<String, dynamic>> assignments,
    required List<Map<String, dynamic>> events,
  }) async {
    final prompt = '''
You are an expert daily planner AI assistant. A student is using your schedule planner app, and they have just toggled the active schedule state:
- Action: The user just clicked the "$action" button.
- Action Time: $timeStr
- Active Task that was affected: "$currentTaskTitle"
- Remaining duration needed for this task: $remainingMinutes minutes.

Current Daily Plan (Before Rescheduling):
${jsonEncode(currentPlan)}

Scheduled Academic Items for Today:
- Active Courses: ${jsonEncode(courses)}
- Active Tasks: ${jsonEncode(tasks)}
- Assignments Due: ${jsonEncode(assignments)}
- Upcoming Events/Hackathons: ${jsonEncode(events)}

Instructions for Rescheduling:
1. PROCESS THE PAUSE/RESUME ACTION (CRITICAL):
   - If action is "pause": The task "$currentTaskTitle" was paused at $timeStr. The remaining $remainingMinutes minutes of this task must be shifted to start LATER when they resume. All subsequent activities for the rest of today must be dynamically shifted forward or compressed to fit within the remaining available time of the day.
   - If action is "resume": The task "$currentTaskTitle" is resuming right now at $timeStr. It needs $remainingMinutes minutes to complete (so it will run from $timeStr until a new end time). You must reschedule this task to run for $remainingMinutes minutes starting exactly at $timeStr, and dynamically reschedule and shift all remaining unfinished tasks, courses, and assignments to start after this task ends.
   - Ensure there are no chronological gaps or overlaps in the updated schedule.

2. COMPRESS & PRIORITIZE IF CROWDED:
   - If shifting the remaining items forward makes the schedule extremely tight or pushes items past standard bedtime (e.g. 10:00 PM), dynamically compress the durations of lower-priority activities (e.g. leisure, routines) or use the "options" field for equal-precedence items so they don't get omitted.
   - Respect deadlines and priorities. Ensure highly important tasks/assignments due today are scheduled first.

3. JSON SCHEMA FORMAT constraints:
   - Return ONLY a valid JSON array of objects representing the updated daily timeline.
   - Each block MUST have the exact keys "time" and "work", and optionally "options".
   - "time" must be a 12-hour format range with AM/PM (e.g., "02:35 PM - 04:00 PM").
   - Return ONLY raw valid JSON array. Do not include markdown codeblocks or extra text.
''';

    final rawResponse = await _callApi(apiKey: apiKey, prompt: prompt);
    debugPrint('[GeminiService] Raw reschedule plan response: $rawResponse');
    
    return parseScheduleList(rawResponse);
  }

  /// Refines plan using conversation history (Chatbot mode)
  static Future<Map<String, dynamic>> chatToModifyPlan({
    required String apiKey,
    required String currentPlanJson,
    required String userMessage,
    required List<Map<String, String>> chatHistory,
  }) async {
    final prompt = '''
You are an expert daily planner AI assistant. You have previously generated a daily plan for the student. The student wants to adjust or edit this schedule.

Current Day Plan:
$currentPlanJson

Chat Conversation History:
${jsonEncode(chatHistory)}

New User Request:
"$userMessage"

Instructions:
1. Modify the schedule based on the user's request. Ensure the schedule remains coherent, realistic, and covers the day correctly.
2. You MUST return a JSON object with exactly two keys:
   - "response": A friendly, helpful conversational response explaining the changes you made (keep it short and sweet).
   - "schedule": A valid JSON array of schedule objects with keys "time" and "work" representing the complete updated daily timeline.
3. Keep the conversational response concise and positive.
4. Return ONLY raw valid JSON matching this schema:
   {
     "response": "Sure, I shifted your study session to 3 PM...",
     "schedule": [
       {"time": "08:00 AM - 09:00 AM", "work": "Breakfast"},
       ...
     ]
   }
''';

    final rawResponse = await _callApi(apiKey: apiKey, prompt: prompt);
    debugPrint('[GeminiService] Raw chat response: $rawResponse');
    
    final cleaned = _cleanJsonString(rawResponse);
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
    
    return {
      'response': decoded['response'] as String? ?? 'Plan updated successfully.',
      'schedule': (decoded['schedule'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    };
  }

  /// Helper to clean raw response of markdown block wrappers if returned
  static String _cleanJsonString(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith('```')) {
        lines.removeLast();
      }
      cleaned = lines.join('\n').trim();
    }
    return cleaned;
  }

  /// Parses JSON array to schedule map list
  static List<Map<String, dynamic>> parseScheduleList(String raw) {
    final cleaned = _cleanJsonString(raw);
    final parsed = jsonDecode(cleaned);
    if (parsed is List) {
      return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    throw const FormatException('API response is not a valid JSON list');
  }

  /// Checks if today is a public holiday using Gemini
  static Future<bool> checkPublicHolidayFromAi({
    required String apiKey,
    required DateTime date,
    required String country,
    required String state,
  }) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final prompt = '''
Today is $dateStr (weekday: ${date.weekday}). Is today a recognized public holiday in the state of $state, $country?
Consider major national public holidays and region-specific holidays in $state, $country.
You MUST return ONLY a valid JSON object matching the exact schema:
{
  "isHoliday": true or false,
  "holidayName": "Name of the Holiday or empty string"
}
Return ONLY valid JSON.
''';

    try {
      final rawResponse = await _callApi(apiKey: apiKey, prompt: prompt);
      debugPrint('[GeminiService] Raw holiday check response: $rawResponse');
      final cleaned = _cleanJsonString(rawResponse);
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      return decoded['isHoliday'] as bool? ?? false;
    } catch (e) {
      debugPrint('[GeminiService] Error checking public holiday from AI: $e');
      return false;
    }
  }
}

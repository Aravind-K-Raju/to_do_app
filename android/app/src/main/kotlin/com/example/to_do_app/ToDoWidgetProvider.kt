package com.example.to_do_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class ToDoWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.example.to_do_app.TOGGLE_PAUSE") {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val isPaused = prefs.getBoolean("is_paused", false)
            val newIsPaused = !isPaused

            val editor = prefs.edit()
            editor.putBoolean("is_paused", newIsPaused)

            var timeStr = ""
            if (newIsPaused) {
                // Stash the exact paused system time
                val now = Calendar.getInstance()
                val format = SimpleDateFormat("hh:mm a", Locale.US)
                timeStr = format.format(now.time)
                editor.putString("paused_at", timeStr)
                editor.putBoolean("is_rescheduling", false) // Ensure no loading state when pausing
            } else {
                editor.remove("paused_at")
                editor.putBoolean("is_rescheduling", true) // Show loading spinner immediately on resume!
            }
            editor.commit() // Synchronous commit to prevent 3-second lag race conditions!

            // 1. Immediately redraw widget locally for a zero-lag interactive response
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, ToDoWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)

            // 2. Launch Flutter App in the background to run AI rescheduling using HomeWidgetBackgroundIntent
            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context,
                android.net.Uri.parse("todoapp://toggle_pause?is_paused=$newIsPaused&paused_at=$timeStr")
            )
            try {
                backgroundIntent.send()
            } catch (e: Exception) {
                android.util.Log.e("ToDoWidget", "Error sending background intent", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.to_do_widget_layout).apply {
                // Read preference payloads populated from Dart or local receiver toggles
                val dateStr = widgetData.getString("today_date_str", "Today") ?: "Today"
                val taskCount = widgetData.getInt("pending_task_count", 0)
                val isHoliday = widgetData.getBoolean("is_holiday", false)
                val scheduleJsonStr = widgetData.getString("schedule_json", "[]") ?: "[]"
                
                val isPaused = widgetData.getBoolean("is_paused", false)
                val pausedAt = widgetData.getString("paused_at", "") ?: ""
                val isRescheduling = widgetData.getBoolean("is_rescheduling", false)

                // Map header and footer parameters

                // Dynamically resolve current or paused active task details from schedule JSON
                var activeTitle = "No active task"
                var activeTimeSlot = "--:--"
                var activeCategory = "Study Session"
                var remainingMins = 60
                var activeIndex = -1

                try {
                    val jsonArray = JSONArray(scheduleJsonStr)
                    
                    // Parse target time reference based on pause state
                    val timeReferenceMinutes = if (isPaused && pausedAt.isNotEmpty()) {
                        parseTimeStrToMinutes(pausedAt)
                    } else {
                        val now = Calendar.getInstance()
                        now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
                    }

                    val parsedTimes = ArrayList<Int>()
                    for (i in 0 until jsonArray.length()) {
                        val item = jsonArray.getJSONObject(i)
                        val timeStr = item.optString("time", "")
                        parsedTimes.add(parseTimeStrToMinutes(timeStr))
                    }

                    // Identify active schedule block index
                    for (i in 0 until jsonArray.length()) {
                        val start = parsedTimes[i]
                        val nextStart = if (i + 1 < jsonArray.length()) parsedTimes[i + 1] else 1440
                        if (timeReferenceMinutes in start until nextStart) {
                            activeIndex = i
                            break
                        }
                    }

                    if (activeIndex != -1) {
                        val item = jsonArray.getJSONObject(activeIndex)
                        activeTitle = item.optString("work", "")
                        activeTimeSlot = item.optString("time", "")
                        
                        // Infer study categories
                        activeCategory = when {
                            activeTitle.contains("Study", ignoreCase = true) || activeTitle.contains("Lecture", ignoreCase = true) -> "Course Study"
                            activeTitle.contains("Assignment", ignoreCase = true) || activeTitle.contains("Project", ignoreCase = true) -> "Task Focus"
                            activeTitle.contains("Break", ignoreCase = true) || activeTitle.contains("Lunch", ignoreCase = true) || activeTitle.contains("Dinner", ignoreCase = true) -> "Relaxation"
                            else -> "Routine Activity"
                        }

                        val nextStart = if (activeIndex + 1 < jsonArray.length()) parsedTimes[activeIndex + 1] else 1440
                        remainingMins = nextStart - timeReferenceMinutes
                    }
                } catch (e: Exception) {
                    android.util.Log.e("ToDoWidget", "Error resolving active task details: ", e)
                }

                // Inflate active task parameters onto views
                setTextViewText(R.id.widget_active_title, activeTitle)
                setTextViewText(R.id.widget_time_slot, activeTimeSlot)
                setTextViewText(R.id.widget_category_label, activeCategory)

                // Render dynamic pause and active styles natively
                if (isPaused) {
                    // Paused Badge style (Translucent Red card)
                    setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_paused_badge)
                    setTextViewText(R.id.widget_status_badge, "Paused")

                    // Paused at label
                    setTextViewText(R.id.widget_remaining_time, "Paused at $pausedAt")
                    setTextColor(R.id.widget_remaining_time, android.graphics.Color.parseColor("#EF4444"))

                    // Toggle button -> Green Play "IN"
                    setInt(R.id.widget_toggle_button, "setBackgroundResource", R.drawable.widget_play_button)
                    setInt(R.id.widget_toggle_icon, "setImageResource", R.drawable.ic_play)
                    setTextViewText(R.id.widget_toggle_label, "IN")
                    setTextColor(R.id.widget_toggle_label, android.graphics.Color.parseColor("#10B981"))
                } else {
                    // Live Now Badge style (Purple card)
                    setInt(R.id.widget_status_badge, "setBackgroundResource", R.drawable.widget_live_badge)
                    setTextViewText(R.id.widget_status_badge, "LIVE NOW")

                    // Ends in remaining minutes
                    setTextViewText(R.id.widget_remaining_time, "Ends in ${remainingMins}m")
                    setTextColor(R.id.widget_remaining_time, android.graphics.Color.parseColor("#A78BFA"))

                    // Toggle button -> Purple Pause "OUT"
                    setInt(R.id.widget_toggle_button, "setBackgroundResource", R.drawable.widget_pause_button)
                    setInt(R.id.widget_toggle_icon, "setImageResource", R.drawable.ic_pause)
                    setTextViewText(R.id.widget_toggle_label, "OUT")
                    setTextColor(R.id.widget_toggle_label, android.graphics.Color.parseColor("#C4B5FD"))
                }

                // Render indeterminate loading spinner inside the toggle button when AI is rescheduling
                if (isRescheduling) {
                    setViewVisibility(R.id.widget_toggle_icon, android.view.View.GONE)
                    setViewVisibility(R.id.widget_loading_progress, android.view.View.VISIBLE)
                    setTextViewText(R.id.widget_toggle_label, "WAIT")
                    setTextColor(R.id.widget_toggle_label, android.graphics.Color.parseColor("#9CA3AF"))
                } else {
                    setViewVisibility(R.id.widget_toggle_icon, android.view.View.VISIBLE)
                    setViewVisibility(R.id.widget_loading_progress, android.view.View.GONE)
                }

                // 3. Render upcoming schedules (skip past/active items, start from activeIndex + 1)
                removeAllViews(R.id.widget_schedule_list)
                try {
                    val jsonArray = JSONArray(scheduleJsonStr)
                    val startIndex = if (activeIndex != -1) activeIndex + 1 else 0
                    val limit = Math.min(jsonArray.length(), startIndex + 2)

                    for (i in startIndex until limit) {
                        val item = jsonArray.getJSONObject(i)
                        val time = item.optString("time", "--:--")
                        val activity = item.optString("work", "")

                        val itemViews = RemoteViews(context.packageName, R.layout.widget_schedule_item)
                        itemViews.setTextViewText(R.id.item_time, parseTimeRangeToStartOnly(time))
                        itemViews.setTextViewText(R.id.item_activity, activity)

                        // Highlight upcoming items cleanly
                        itemViews.setTextColor(R.id.item_time, android.graphics.Color.parseColor("#9CA3AF"))
                        itemViews.setTextColor(R.id.item_activity, android.graphics.Color.parseColor("#FFFFFF"))

                        // Set dot node color
                        itemViews.setInt(R.id.timeline_dot, "setImageResource", R.drawable.widget_timeline_circle)

                        // Remove vertical line for the last item to create a clean connected segment
                        if (i == limit - 1) {
                            itemViews.setViewVisibility(R.id.timeline_line, android.view.View.INVISIBLE)
                        }

                        addView(R.id.widget_schedule_list, itemViews)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("ToDoWidget", "Error rendering timeline: ", e)
                }

                // 3.5. Render quick notes
                removeAllViews(R.id.widget_notes_list)
                try {
                    val notesJsonStr = widgetData.getString("widget_quick_notes", "[]") ?: "[]"
                    val notesArray = JSONArray(notesJsonStr)
                    val limit = Math.min(notesArray.length(), 2) // Display up to 2 latest notes to fit perfectly

                    if (notesArray.length() == 0) {
                        val itemViews = RemoteViews(context.packageName, R.layout.widget_note_item)
                        itemViews.setTextViewText(R.id.note_title, "Tap to write a note")
                        itemViews.setTextViewText(R.id.note_content, "Capture quick thoughts here directly from your home screen.")
                        addView(R.id.widget_notes_list, itemViews)
                    } else {
                        for (i in 0 until limit) {
                            val note = notesArray.getJSONObject(i)
                            val title = note.optString("title", "")
                            val content = note.optString("content", "")

                            val itemViews = RemoteViews(context.packageName, R.layout.widget_note_item)
                            itemViews.setTextViewText(R.id.note_title, if (title.isEmpty()) "Untitled Note" else title)
                            itemViews.setTextViewText(R.id.note_content, content)

                            addView(R.id.widget_notes_list, itemViews)
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("ToDoWidget", "Error rendering notes: ", e)
                }

                // 4. Bind action click broadcast PendingIntent to toggle button and entire card
                val toggleIntent = Intent(context, ToDoWidgetProvider::class.java).apply {
                    action = "com.example.to_do_app.TOGGLE_PAUSE"
                }
                val togglePendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    toggleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_button_glass_card, togglePendingIntent)

                // 4.5. Bind click PendingIntent to start QuickNoteActivity
                val noteIntent = Intent(context, QuickNoteActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val notePendingIntent = PendingIntent.getActivity(
                    context,
                    1,
                    noteIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_notes_header, notePendingIntent)
                setOnClickPendingIntent(R.id.widget_notes_list, notePendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun parseTimeStrToMinutes(timeStr: String): Int {
        try {
            val cleaned = timeStr.trim().toUpperCase(Locale.US)
            val ampmParts = cleaned.split(" ")
            
            // Extract the first time block if range is passed (e.g. "02:00 PM - 04:00 PM")
            val rawTime = ampmParts[0].split("-")[0].trim()
            val hmParts = rawTime.split(":")
            var hour = hmParts[0].toInt()
            val minute = hmParts[1].toInt()

            val ampm = if (ampmParts.size > 1) {
                ampmParts[1].substring(0, 2)
            } else if (cleaned.contains("PM")) {
                "PM"
            } else {
                "AM"
            }

            if (ampm == "PM" && hour != 12) hour += 12
            if (ampm == "AM" && hour == 12) hour = 0
            return hour * 60 + minute
        } catch (e: Exception) {
            return 0
        }
    }

    private fun parseTimeRangeToStartOnly(timeRange: String): String {
        try {
            // E.g. "04:15 PM - 04:30 PM" -> "04:15 PM"
            if (timeRange.contains("-")) {
                return timeRange.split("-")[0].trim()
            }
            return timeRange
        } catch (e: Exception) {
            return timeRange
        }
    }
}

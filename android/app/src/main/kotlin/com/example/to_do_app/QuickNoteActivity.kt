package com.example.to_do_app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class QuickNoteActivity : Activity() {

    private lateinit var noteInput: EditText
    private lateinit var btnSave: Button
    private lateinit var btnCancel: Button
    private lateinit var existingNotesList: LinearLayout
    private lateinit var notesListTitle: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_note)

        noteInput = findViewById(R.id.note_input)
        btnSave = findViewById(R.id.btn_save)
        btnCancel = findViewById(R.id.btn_cancel)
        existingNotesList = findViewById(R.id.existing_notes_list)
        notesListTitle = findViewById(R.id.notes_list_title)

        // Setup save and cancel actions
        btnSave.setOnClickListener {
            val noteText = noteInput.text.toString().trim()
            if (noteText.isNotEmpty()) {
                saveQuickNote(noteText)
            } else {
                finish()
            }
        }

        btnCancel.setOnClickListener {
            finish()
        }

        // Render current widget-specific quick notes
        renderExistingNotes()
    }

    private fun getQuickNotesArray(): JSONArray {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("widget_quick_notes", "[]") ?: "[]"
        return try {
            JSONArray(jsonStr)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun saveQuickNote(content: String) {
        val notes = getQuickNotesArray()
        val noteObj = JSONObject()

        // Use current date/time as subtitle or title
        val now = Calendar.getInstance()
        val format = SimpleDateFormat("MMM d, hh:mm a", Locale.US)
        val timestamp = format.format(now.time)

        noteObj.put("title", "Quick Note - $timestamp")
        noteObj.put("content", content)

        // Prepend notes to show the latest notes at the top!
        val newArray = JSONArray()
        newArray.put(noteObj)
        for (i in 0 until notes.length()) {
            newArray.put(notes.get(i))
        }

        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().putString("widget_quick_notes", newArray.toString()).apply()

        // Redraw widget immediately
        triggerWidgetUpdate()
        finish()
    }

    private fun deleteQuickNote(index: Int) {
        val notes = getQuickNotesArray()
        val newArray = JSONArray()
        for (i in 0 until notes.length()) {
            if (i != index) {
                newArray.put(notes.get(i))
            }
        }

        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().putString("widget_quick_notes", newArray.toString()).apply()

        // Redraw list locally
        renderExistingNotes()
        // Redraw widget immediately
        triggerWidgetUpdate()
    }

    private fun renderExistingNotes() {
        existingNotesList.removeAllViews()
        val notes = getQuickNotesArray()

        if (notes.length() == 0) {
            notesListTitle.visibility = View.GONE
            return
        }

        notesListTitle.visibility = View.VISIBLE

        for (i in 0 until notes.length()) {
            val note = notes.getJSONObject(i)
            val title = note.optString("title", "")
            val content = note.optString("content", "")

            // Row Container
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(0, 0, 0, 8)
                }
                setPadding(10, 10, 10, 10)
                setBackgroundResource(R.drawable.widget_inner_glass_card)
            }

            // Note Text Info Panel
            val textLayout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f
                )
            }

            val noteTitleTv = TextView(this).apply {
                text = title
                textColor = Color.parseColor("#9CA3AF")
                textSize = 10f
                setPadding(0, 0, 0, 2)
            }

            val noteContentTv = TextView(this).apply {
                text = content
                textColor = Color.WHITE
                textSize = 12f
            }

            textLayout.addView(noteTitleTv)
            textLayout.addView(noteContentTv)

            // Delete Action button
            val btnDelete = TextView(this).apply {
                text = "✕"
                textColor = Color.parseColor("#EF4444")
                textSize = 16f
                setPadding(12, 4, 12, 4)
                setOnClickListener {
                    deleteQuickNote(i)
                }
            }

            row.addView(textLayout)
            row.addView(btnDelete)

            existingNotesList.addView(row)
        }
    }

    private fun triggerWidgetUpdate() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val componentName = ComponentName(this, ToDoWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
        val provider = ToDoWidgetProvider()
        provider.onUpdate(this, appWidgetManager, appWidgetIds)
    }

    // Helper property to set text colors programmatically
    private var TextView.textColor: Int
        get() = currentTextColor
        set(value) = setTextColor(value)
}

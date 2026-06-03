import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/note_provider.dart';
import '../../../domain/entities/note.dart';
import 'markdown_text_editing_controller.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final int? folderId;

  const NoteEditorScreen({super.key, this.note, this.folderId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late MarkdownTextEditingController _contentController;
  
  Timer? _debounceTimer;
  Note? _currentNote;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _titleController = TextEditingController(text: _currentNote?.title ?? '');
    _contentController = MarkdownTextEditingController(text: _currentNote?.content ?? '');

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _saveNoteImmediate(); // save any remaining changes on exit
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges {
    final title = _titleController.text.trim();
    final content = _contentController.text; // keep original formatting in content comparison
    
    if (_currentNote == null) {
      return title.isNotEmpty || content.isNotEmpty;
    }
    return title != _currentNote!.title || content != _currentNote!.content;
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_hasUnsavedChanges && mounted) {
        _autosaveNote();
      }
    });
  }

  Future<void> _autosaveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (title.isEmpty && content.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);

    if (_currentNote == null) {
      final generatedTitle = title.isEmpty
          ? (content.split('\n').first.isEmpty ? 'Untitled Note' : content.split('\n').first)
          : title;
      final insertedId = await provider.createNote(
        generatedTitle,
        content,
        folderId: widget.folderId,
      );
      if (insertedId != null && mounted) {
        setState(() {
          _currentNote = Note(
            id: insertedId,
            title: generatedTitle,
            content: content,
            folderId: widget.folderId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });
      }
    } else {
      final updatedNote = Note(
        id: _currentNote!.id,
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        folderId: _currentNote!.folderId,
        createdAt: _currentNote!.createdAt,
        updatedAt: DateTime.now(),
      );
      await provider.updateNote(updatedNote);
      if (mounted) {
        setState(() {
          _currentNote = updatedNote;
        });
      }
    }
  }

  // Synchronous/immediate save used on manually clicking done or disposing the screen
  void _saveNoteImmediate() {
    if (!_hasUnsavedChanges) return;

    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (title.isEmpty && content.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);

    if (_currentNote == null) {
      final generatedTitle = title.isEmpty
          ? (content.split('\n').first.isEmpty ? 'Untitled Note' : content.split('\n').first)
          : title;
      // We run this without waiting inside dispose, but inside checks we can await
      provider.createNote(
        generatedTitle,
        content,
        folderId: widget.folderId,
      );
    } else {
      final updatedNote = Note(
        id: _currentNote!.id,
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        folderId: _currentNote!.folderId,
        createdAt: _currentNote!.createdAt,
        updatedAt: DateTime.now(),
      );
      provider.updateNote(updatedNote);
    }
  }

  // --- Keyboard Formatting Helpers ---

  void _wrapSelection(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    
    if (selection.start < 0 || selection.end < 0) return;
    
    final selectedText = text.substring(selection.start, selection.end);
    final wrappedText = '$tag$selectedText$tag';
    
    final newText = text.replaceRange(selection.start, selection.end, wrappedText);
    final newCursorStart = selection.start + tag.length;
    final newCursorEnd = selection.end + tag.length;
    
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: newCursorStart,
        extentOffset: newCursorEnd,
      ),
    );
  }

  void _toggleLinePrefix(String prefix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    
    int start = selection.start;
    if (start < 0) start = 0;
    
    int lineStart = text.lastIndexOf('\n', start - 1) + 1;
    int lineEnd = text.indexOf('\n', start);
    if (lineEnd == -1) lineEnd = text.length;
    
    final line = text.substring(lineStart, lineEnd);
    
    String newLine = line;
    if (line.startsWith(prefix)) {
      newLine = line.substring(prefix.length);
    } else {
      // Remove other known formatting prefixes
      if (line.startsWith('[ ] ')) {
        newLine = line.substring(4);
      } else if (line.startsWith('[x] ') || line.startsWith('[X] ')) {
        newLine = line.substring(4);
      } else if (line.startsWith('- ')) {
        newLine = line.substring(2);
      } else if (line.startsWith('• ')) {
        newLine = line.substring(2);
      } else if (RegExp(r'^[0-9]+\. ').hasMatch(line)) {
        final match = RegExp(r'^[0-9]+\. ').firstMatch(line);
        if (match != null) {
          newLine = line.substring(match.group(0)!.length);
        }
      }
      
      newLine = prefix + newLine;
    }
    
    final newText = text.replaceRange(lineStart, lineEnd, newLine);
    final diff = newLine.length - line.length;
    int newCursor = start + diff;
    if (newCursor < 0) newCursor = 0;
    if (newCursor > newText.length) newCursor = newText.length;
    
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white38),
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () {
              _debounceTimer?.cancel();
              _saveNoteImmediate();
              Navigator.pop(context);
            },
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
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white30),
                  ),
                  style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                  maxLines: null,
                  expands: true,
                ),
              ),
            ),
            
            // Premium Glassmorphic Formatting Toolbar
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF15151D).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_box_outlined, color: Colors.white70),
                    tooltip: 'Checklist',
                    onPressed: () => _toggleLinePrefix('[ ] '),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_bold, color: Colors.white70),
                    tooltip: 'Bold',
                    onPressed: () => _wrapSelection('**'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_strikethrough, color: Colors.white70),
                    tooltip: 'Strikethrough',
                    onPressed: () => _wrapSelection('~~'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted, color: Colors.white70),
                    tooltip: 'Bullet List',
                    onPressed: () => _toggleLinePrefix('• '),
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_numbered, color: Colors.white70),
                    tooltip: 'Numbered List',
                    onPressed: () => _toggleLinePrefix('1. '),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

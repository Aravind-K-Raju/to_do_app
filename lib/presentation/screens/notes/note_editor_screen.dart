import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/note_provider.dart';
import '../../../domain/entities/note.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final int? folderId;

  const NoteEditorScreen({super.key, this.note, this.folderId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    final provider = Provider.of<NoteProvider>(context, listen: false);

    if (widget.note == null) {
      if (title.isEmpty) {
        // Auto-generate title if missing
        final generatedTitle = content.split('\n').first;
        provider.createNote(
          generatedTitle.isEmpty ? 'Untitled Note' : generatedTitle,
          content,
          folderId: widget.folderId,
        );
      } else {
        provider.createNote(title, content, folderId: widget.folderId);
      }
    } else {
      final updatedNote = Note(
        id: widget.note!.id,
        title: title.isEmpty ? 'Untitled Note' : title,
        content: content,
        folderId: widget.note!.folderId,
        createdAt: widget.note!.createdAt,
        updatedAt: DateTime.now(),
      );
      provider.updateNote(updatedNote);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _saveNote();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _contentController,
          decoration: const InputDecoration(
            hintText: 'Start writing...',
            border: InputBorder.none,
          ),
          maxLines: null,
          expands: true,
        ),
      ),
    );
  }
}

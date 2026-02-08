import 'package:flutter/material.dart';
import '../../domain/entities/folder.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _repository;

  List<Folder> _folders = [];
  List<Note> _notes = [];
  bool _isLoading = false;
  String? _error;

  NoteProvider(this._repository);

  List<Folder> get folders => _folders;
  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- Folders ---

  Future<void> loadFolders({int? parentId}) async {
    _setLoading(true);
    try {
      _folders = await _repository.getFolders(parentId: parentId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createFolder(String name, {int? parentId}) async {
    _setLoading(true);
    try {
      final folder = Folder(
        name: name,
        parentId: parentId,
        createdAt: DateTime.now(),
      );
      await _repository.createFolder(folder);
      await loadFolders(parentId: parentId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateFolder(Folder folder) async {
    _setLoading(true);
    try {
      await _repository.updateFolder(folder);
      await loadFolders(parentId: folder.parentId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteFolder(int id, {int? parentId}) async {
    _setLoading(true);
    try {
      await _repository.deleteFolder(id);
      await loadFolders(parentId: parentId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // --- Notes ---

  Future<void> loadNotes({int? folderId}) async {
    _setLoading(true);
    try {
      _notes = await _repository.getNotes(folderId: folderId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createNote(String title, String content, {int? folderId}) async {
    _setLoading(true);
    try {
      final note = Note(
        title: title,
        content: content,
        folderId: folderId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repository.createNote(note);
      await loadNotes(folderId: folderId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateNote(Note note) async {
    _setLoading(true);
    try {
      final updatedNote = Note(
        id: note.id,
        title: note.title,
        content: note.content,
        folderId: note.folderId,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
      );
      await _repository.updateNote(updatedNote);
      await loadNotes(folderId: note.folderId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteNote(int id, {int? folderId}) async {
    _setLoading(true);
    try {
      await _repository.deleteNote(id);
      await loadNotes(folderId: folderId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

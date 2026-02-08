import '../../domain/entities/folder.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../database/database_helper.dart';

class NoteRepositoryImpl implements NoteRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Folders ---

  @override
  Future<List<Folder>> getFolders({int? parentId}) async {
    final result = await _dbHelper.getFolders(parentId: parentId);
    return result.map((map) => _folderFromMap(map)).toList();
  }

  @override
  Future<int> createFolder(Folder folder) async {
    return await _dbHelper.createFolder(_folderToMap(folder));
  }

  @override
  Future<int> updateFolder(Folder folder) async {
    return await _dbHelper.updateFolder(_folderToMap(folder));
  }

  @override
  Future<int> deleteFolder(int id) async {
    return await _dbHelper.deleteFolder(id);
  }

  // --- Notes ---

  @override
  Future<List<Note>> getNotes({int? folderId}) async {
    final result = await _dbHelper.getNotes(folderId: folderId);
    return result.map((map) => _noteFromMap(map)).toList();
  }

  @override
  Future<int> createNote(Note note) async {
    return await _dbHelper.createNote(_noteToMap(note));
  }

  @override
  Future<int> updateNote(Note note) async {
    return await _dbHelper.updateNote(_noteToMap(note));
  }

  @override
  Future<int> deleteNote(int id) async {
    return await _dbHelper.deleteNote(id);
  }

  // --- Mappers ---

  Folder _folderFromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int?,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> _folderToMap(Folder folder) {
    return {
      'id': folder.id,
      'name': folder.name,
      'parent_id': folder.parentId,
      'created_at': folder.createdAt.toIso8601String(),
    };
  }

  Note _noteFromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      folderId: map['folder_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> _noteToMap(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'folder_id': note.folderId,
      'created_at': note.createdAt.toIso8601String(),
      'updated_at': note.updatedAt.toIso8601String(),
    };
  }
}

import '../entities/folder.dart';
import '../entities/note.dart';

abstract class NoteRepository {
  // Folders
  Future<List<Folder>> getFolders({int? parentId});
  Future<int> createFolder(Folder folder);
  Future<int> updateFolder(Folder folder);
  Future<int> deleteFolder(int id);

  // Notes
  Future<List<Note>> getNotes({int? folderId});
  Future<int> createNote(Note note);
  Future<int> updateNote(Note note);
  Future<int> deleteNote(int id);
}

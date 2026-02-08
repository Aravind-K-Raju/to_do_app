import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/note_provider.dart';
import 'note_editor_screen.dart';
import '../../../domain/entities/folder.dart';
import '../../../domain/entities/note.dart';

class FolderListScreen extends StatefulWidget {
  final int? parentId;
  final String title;

  const FolderListScreen({
    super.key,
    this.parentId,
    this.title = 'Quick Notes',
  });

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<NoteProvider>(context, listen: false);
      provider.loadFolders(parentId: widget.parentId);
      provider.loadNotes(folderId: widget.parentId);
    });
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Provider.of<NoteProvider>(
                  context,
                  listen: false,
                ).createFolder(controller.text, parentId: widget.parentId);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _editFolder(Folder folder) {
    final controller = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final updatedFolder = Folder(
                  id: folder.id,
                  name: controller.text,
                  parentId: folder.parentId,
                  createdAt: folder.createdAt,
                );
                Provider.of<NoteProvider>(
                  context,
                  listen: false,
                ).updateFolder(updatedFolder);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteFolder(Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}" and all its contents?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<NoteProvider>(
                context,
                listen: false,
              ).deleteFolder(folder.id!, parentId: widget.parentId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteNote(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<NoteProvider>(
                context,
                listen: false,
              ).deleteNote(note.id!, folderId: widget.parentId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Consumer<NoteProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text('Error: ${provider.error}'));
          }

          final items = [
            ...provider.folders.map((f) => {'type': 'folder', 'data': f}),
            ...provider.notes.map((n) => {'type': 'note', 'data': n}),
          ];

          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No items yet.\nTap + to create a folder or note.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item['type'] == 'folder') {
                final folder = item['data'] as Folder;
                return ListTile(
                  leading: const Icon(Icons.folder, color: Colors.amber),
                  title: Text(folder.name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FolderListScreen(
                          parentId: folder.id,
                          title: folder.name,
                        ),
                      ),
                    ).then((_) {
                      // Refresh when coming back
                      if (!context.mounted) return;
                      final p = Provider.of<NoteProvider>(
                        context,
                        listen: false,
                      );
                      p.loadFolders(parentId: widget.parentId);
                      p.loadNotes(folderId: widget.parentId);
                    });
                  },
                  trailing: PopupMenuButton(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editFolder(folder);
                      } else if (value == 'delete') {
                        _deleteFolder(folder);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Rename')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                );
              } else {
                final note = item['data'] as Note;
                return ListTile(
                  leading: const Icon(
                    Icons.description,
                    color: Colors.blueAccent,
                  ),
                  title: Text(note.title),
                  subtitle: Text(
                    note.content.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteEditorScreen(note: note),
                      ),
                    ).then((_) {
                      if (!context.mounted) return;
                      final p = Provider.of<NoteProvider>(
                        context,
                        listen: false,
                      );
                      p.loadNotes(folderId: widget.parentId);
                    });
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteNote(note),
                  ),
                );
              }
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_folder',
            onPressed: _showCreateFolderDialog,
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add_note',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NoteEditorScreen(folderId: widget.parentId),
                ),
              ).then((_) {
                if (!context.mounted) return;
                final p = Provider.of<NoteProvider>(context, listen: false);
                p.loadNotes(folderId: widget.parentId);
              });
            },
            child: const Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }
}

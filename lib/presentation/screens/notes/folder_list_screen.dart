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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
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
        child: Consumer<NoteProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)));
            }

            if (provider.error != null) {
              return Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.redAccent)));
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
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final bool isFolder = item['type'] == 'folder';
                Widget tile;

                if (isFolder) {
                  final folder = item['data'] as Folder;
                  tile = ListTile(
                    leading: const Icon(Icons.folder, color: Colors.amber, size: 24),
                    title: Text(
                      folder.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                    ),
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
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editFolder(folder);
                        } else if (value == 'delete') {
                          _deleteFolder(folder);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Rename', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  final note = item['data'] as Note;
                  tile = ListTile(
                    leading: const Icon(
                      Icons.description,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                    title: Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                    ),
                    subtitle: Text(
                      note.content.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteNote(note),
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15151D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: tile,
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_folder',
            onPressed: _showCreateFolderDialog,
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
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
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            child: const Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class DynamicLinkSection<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Function(String url, String description) onAdd;

  const DynamicLinkSection({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onAdd,
  });

  void _showAddDialog(BuildContext context) {
    final urlController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                onAdd(
                  urlController.text,
                  descController.text.isEmpty ? 'Link' : descController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.tealAccent),
              onPressed: () => _showAddDialog(context),
            ),
          ],
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'No links added.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ...items.asMap().entries.map((entry) {
          return itemBuilder(context, entry.value, entry.key);
        }),
      ],
    );
  }
}

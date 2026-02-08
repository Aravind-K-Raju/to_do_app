import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DynamicTimelineSection<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Function(DateTime date, String description) onAdd;

  const DynamicTimelineSection({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onAdd,
  });

  void _showAddDialog(BuildContext context) {
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Add $title Item'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(DateFormat.yMMMd().format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
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
                  if (descController.text.isNotEmpty) {
                    onAdd(selectedDate, descController.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
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
              'No timeline events.',
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

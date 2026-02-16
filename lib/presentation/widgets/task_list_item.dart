import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/task.dart';

class TaskListItem extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TaskListItem({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: task.dueDate != null
            ? Text(
                DateFormat.yMMMd().add_jm().format(task.dueDate!),
                style: const TextStyle(fontSize: 12),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.grey),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/assignment.dart';

class AssignmentListItem extends StatelessWidget {
  final Assignment assignment;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const AssignmentListItem({
    super.key,
    required this.assignment,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        !assignment.isCompleted &&
        assignment.dueDate.isBefore(
          DateTime.now().subtract(const Duration(days: 1)),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Checkbox
              IconButton(
                icon: Icon(
                  assignment.isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: assignment.isCompleted
                      ? Colors.tealAccent
                      : (isOverdue ? Colors.redAccent : Colors.grey),
                ),
                onPressed: onToggle,
              ),
              const SizedBox(width: 8),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: assignment.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: assignment.isCompleted ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${assignment.subject ?? "General"} • ${assignment.type}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: isOverdue ? Colors.redAccent : Colors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.yMMMd().format(assignment.dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue ? Colors.redAccent : Colors.teal,
                            fontWeight: isOverdue ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

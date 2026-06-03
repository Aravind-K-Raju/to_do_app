import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/assignment.dart';

class AssignmentListItem extends StatefulWidget {
  final Assignment assignment;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const AssignmentListItem({
    super.key,
    required this.assignment,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<AssignmentListItem> createState() => _AssignmentListItemState();
}

class _AssignmentListItemState extends State<AssignmentListItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isOverdue = !widget.assignment.isCompleted &&
        widget.assignment.dueDate.isBefore(
          DateTime.now().subtract(const Duration(days: 1)),
        );

    Color getStatusColor() {
      if (widget.assignment.isCompleted) return Colors.greenAccent;
      if (isOverdue) return Colors.redAccent;
      return Colors.amberAccent;
    }

    String getStatusText() {
      if (widget.assignment.isCompleted) return 'COMPLETED';
      if (isOverdue) return 'OVERDUE';
      return 'PENDING';
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
        child: InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Completion Toggle checkbox
                    IconButton(
                      icon: Icon(
                        widget.assignment.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: getStatusColor(),
                        size: 22,
                      ),
                      onPressed: widget.onToggle,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.assignment.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.assignment.isCompleted ? Colors.grey : Colors.white,
                              decoration: widget.assignment.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.assignment.subject ?? "General"} • ${widget.assignment.type}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: getStatusColor(),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                getStatusText(),
                                style: TextStyle(
                                  color: getStatusColor(),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (value) {
                        if (value == 'edit') {
                          widget.onEdit();
                        } else if (value == 'delete') {
                          widget.onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Edit', style: TextStyle(color: Colors.white)),
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
                  ],
                ),
                if (_isExpanded) ...[
                  const Divider(color: Colors.white12, height: 24),
                  if (widget.assignment.description != null && widget.assignment.description!.isNotEmpty) ...[
                    Text(
                      widget.assignment.description!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildDetailRow('Due Date', DateFormat.yMMMd().add_jm().format(widget.assignment.dueDate)),
                  if (widget.assignment.submissionDate != null)
                    _buildDetailRow('Submitted On', DateFormat.yMMMd().add_jm().format(widget.assignment.submissionDate!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        ],
      ),
    );
  }
}

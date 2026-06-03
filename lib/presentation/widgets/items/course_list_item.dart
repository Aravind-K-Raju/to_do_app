import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/course.dart';

class CourseListItem extends StatefulWidget {
  final Course course;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CourseListItem({
    super.key,
    required this.course,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CourseListItem> createState() => _CourseListItemState();
}

class _CourseListItemState extends State<CourseListItem> {
  bool _isExpanded = false;

  Future<void> _launchUrl(String urlString) async {
    String formattedUrl = urlString.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final Uri url = Uri.parse(formattedUrl);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'planned':
        return Colors.amberAccent;
      case 'ongoing':
        return Colors.greenAccent;
      case 'completed':
        return const Color(0xFF8B5CF6); // purple
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.course.status);
    final subtitleText = [
      widget.course.platform,
      if (widget.course.channelName != null && widget.course.channelName!.isNotEmpty)
        widget.course.channelName,
    ].join(' • ');

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.course.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (subtitleText.isNotEmpty)
                            Text(
                              subtitleText,
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
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.course.status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
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
                  if (widget.course.description != null && widget.course.description!.isNotEmpty) ...[
                    Text(
                      widget.course.description!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildDetailRow('Start Date', DateFormat.yMMMd().format(widget.course.startDate)),
                  if (widget.course.completionDate != null)
                    _buildDetailRow('Completed', DateFormat.yMMMd().format(widget.course.completionDate!)),
                  if (widget.course.loginMail != null && widget.course.loginMail!.isNotEmpty)
                    _buildDetailRow('Login Email', widget.course.loginMail!),
                  if (widget.course.links.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Links:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    ...widget.course.links.map((link) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: InkWell(
                            onTap: () => _launchUrl(link.url),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 14, color: Colors.tealAccent),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${link.description}: ${link.url}',
                                      style: const TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.tealAccent,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                  ],
                  if (widget.course.timeline.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Timeline:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    ...widget.course.timeline.map((event) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMM d').format(event.date),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  event.description,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
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

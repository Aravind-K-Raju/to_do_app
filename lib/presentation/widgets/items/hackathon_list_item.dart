import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/hackathon.dart';

class HackathonListItem extends StatefulWidget {
  final Hackathon hackathon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HackathonListItem({
    super.key,
    required this.hackathon,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<HackathonListItem> createState() => _HackathonListItemState();
}

class _HackathonListItemState extends State<HackathonListItem> {
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = widget.hackathon.endDate != null
        ? widget.hackathon.endDate!.isBefore(now)
        : widget.hackathon.startDate.isBefore(now.subtract(const Duration(days: 1)));

    final statusColor = isPast ? Colors.grey : Colors.greenAccent;
    final statusText = isPast ? 'PAST EVENT' : 'UPCOMING EVENT';

    final subtitleText = [
      DateFormat.yMMMd().format(widget.hackathon.startDate),
      if (widget.hackathon.theme != null && widget.hackathon.theme!.isNotEmpty)
        widget.hackathon.theme,
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
                            widget.hackathon.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                statusText,
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
                  if (widget.hackathon.description != null && widget.hackathon.description!.isNotEmpty) ...[
                    Text(
                      widget.hackathon.description!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.hackathon.endDate != null)
                    _buildDetailRow('Ends On', DateFormat.yMMMd().format(widget.hackathon.endDate!)),
                  if (widget.hackathon.teamSize != null)
                    _buildDetailRow('Team Size', widget.hackathon.teamSize.toString()),
                  if (widget.hackathon.techStack != null && widget.hackathon.techStack!.isNotEmpty)
                    _buildDetailRow('Tech Stack', widget.hackathon.techStack!),
                  if (widget.hackathon.outcome != null && widget.hackathon.outcome!.isNotEmpty)
                    _buildDetailRow('Outcome', widget.hackathon.outcome!),
                  if (widget.hackathon.projectLink != null && widget.hackathon.projectLink!.isNotEmpty)
                    _buildDetailRow('Project Link', widget.hackathon.projectLink!, onTap: () => _launchUrl(widget.hackathon.projectLink!)),
                  if (widget.hackathon.loginMail != null && widget.hackathon.loginMail!.isNotEmpty)
                    _buildDetailRow('Login Email', widget.hackathon.loginMail!),
                  if (widget.hackathon.links.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Links:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    ...widget.hackathon.links.map((link) => Padding(
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
                  if (widget.hackathon.timeline.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Timeline:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    ...widget.hackathon.timeline.map((event) => Padding(
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

  Widget _buildDetailRow(String label, String value, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.tealAccent,
                      ),
                    ),
                  )
                : Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

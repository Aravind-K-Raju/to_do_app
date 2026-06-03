import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/notification_prefs_service.dart';
import '../../core/services/gemini_service.dart';
import '../widgets/glass/glass_container.dart';
import 'ai_chat_screen.dart';

class FullScheduleScreen extends StatefulWidget {
  const FullScheduleScreen({super.key});

  @override
  State<FullScheduleScreen> createState() => _FullScheduleScreenState();
}

class _FullScheduleScreenState extends State<FullScheduleScreen> {
  final NotificationPrefsService _prefsService = NotificationPrefsService();
  List<Map<String, dynamic>> _schedule = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final planJson = await _prefsService.getAiDayPlanJson();
      if (planJson != null && planJson.isNotEmpty) {
        final parsed = GeminiService.parseScheduleList(planJson);
        setState(() {
          _schedule = parsed;
          _isLoading = false;
        });
      } else {
        setState(() {
          _schedule = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load schedule: $e';
        _isLoading = false;
      });
    }
  }

  bool _isBlockOngoing(String timeRange) {
    final now = DateTime.now();
    final parts = timeRange.split('-');
    if (parts.length != 2) return false;

    DateTime? parseTime(String tStr) {
      try {
        tStr = tStr.trim().toUpperCase();
        final ampmParts = tStr.split(' ');
        final hmParts = ampmParts[0].split(':');
        int hour = int.parse(hmParts[0]);
        int minute = int.parse(hmParts[1]);
        if (ampmParts.length > 1) {
          final ampm = ampmParts[1];
          if (ampm == 'PM' && hour != 12) hour += 12;
          if (ampm == 'AM' && hour == 12) hour = 0;
        }
        return DateTime(now.year, now.month, now.day, hour, minute);
      } catch (_) {
        return null;
      }
    }

    final start = parseTime(parts[0]);
    final end = parseTime(parts[1]);

    if (start == null || end == null) return false;
    return now.isAfter(start) && now.isBefore(end);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Premium Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Schedule',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refine button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AIChatScreen(),
                          ),
                        ).then((_) => _loadSchedule());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFFC4B5FD), size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Timeline Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF7C3AED),
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _schedule.isEmpty
                            ? _buildEmptyState()
                            : _buildTimelineList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF15151D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 24),
            const Text(
              'No AI Plan for Today',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Go back to Insights and tap "Generate Plan Now" to build your dynamic, optimized routine!',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Insights', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _schedule.length,
      itemBuilder: (context, index) {
        final block = _schedule[index];
        final timeRange = block['time'] as String? ?? 'Time N/A';
        final work = block['work'] as String? ?? 'Activity';
        final isOngoing = _isBlockOngoing(timeRange);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical Track Line
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    // Top vertical line
                    Expanded(
                      child: Container(
                        width: 2,
                        color: index == 0
                            ? Colors.transparent
                            : (isOngoing ? const Color(0xFF10B981) : Colors.white10),
                      ),
                    ),
                    // Glowing Node indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isOngoing ? 18 : 12,
                      height: isOngoing ? 18 : 12,
                      decoration: BoxDecoration(
                        color: isOngoing ? const Color(0xFF10B981) : const Color(0xFF1E1E28),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOngoing ? const Color(0xFF10B981) : const Color(0xFF7C3AED).withValues(alpha: 0.4),
                          width: isOngoing ? 4 : 2,
                        ),
                        boxShadow: isOngoing
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                    // Bottom vertical line
                    Expanded(
                      child: Container(
                        width: 2,
                        color: index == _schedule.length - 1
                            ? Colors.transparent
                            : (_isBlockOngoing(_schedule[index + 1]['time'] as String? ?? '')
                                ? const Color(0xFF10B981)
                                : Colors.white10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Timeline Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      boxShadow: isOngoing
                          ? [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: GlassContainer(
                      opacity: isOngoing ? 0.15 : 0.04,
                      color: isOngoing ? const Color(0xFF10B981) : Colors.white,
                      border: Border.all(
                        color: isOngoing
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.05),
                        width: isOngoing ? 1.5 : 1.0,
                      ),
                      padding: const EdgeInsets.all(16.0),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isOngoing ? Icons.play_arrow : Icons.access_time,
                                size: 14,
                                color: isOngoing ? const Color(0xFF10B981) : const Color(0xFFC4B5FD),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  timeRange,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isOngoing ? const Color(0xFF10B981) : const Color(0xFFC4B5FD),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (isOngoing)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'ACTIVE NOW',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            work,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isOngoing ? FontWeight.bold : FontWeight.normal,
                              color: isOngoing ? Colors.white : Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/services/notification_prefs_service.dart';
import '../../core/services/gemini_service.dart';
import '../widgets/glass/glass_container.dart';
import 'full_schedule_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final NotificationPrefsService _prefsService = NotificationPrefsService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  String? _apiKey;
  String? _currentPlanJson;
  bool _scheduleUpdated = false;

  final List<String> _suggestions = [
    'Add a 2hr coding session at 3 PM',
    'Free up my evening from 6 PM',
    'Move breakfast to 8:30 AM',
    'Insert a rest break at 1 PM',
    'Shift all study blocks by 1 hour'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    _apiKey = await _prefsService.getGeminiApiKey();
    _currentPlanJson = await _prefsService.getAiDayPlanJson();

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': 'Hello! I am your AI Planner Assistant. How would you like to refine or adjust today\'s schedule? You can tell me to shift study hours, clear your evening, add breaks, or make any specific changes!'
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    if (_apiKey == null || _apiKey!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure your Gemini API Key in settings first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text
      });
      _isLoading = true;
      _scheduleUpdated = false;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      // If there is no current plan, let's load it dynamically in case it changed
      _currentPlanJson = await _prefsService.getAiDayPlanJson();
      if (_currentPlanJson == null || _currentPlanJson!.isEmpty) {
        // Fallback placeholder to not crash the AI
        _currentPlanJson = '[]';
      }

      // Convert local message list format into expected API format for chatHistory
      final history = _messages.sublist(0, _messages.length - 1).map((m) => {
        'role': m['role']!,
        'content': m['content']!
      }).toList();

      final result = await GeminiService.chatToModifyPlan(
        apiKey: _apiKey!,
        currentPlanJson: _currentPlanJson!,
        userMessage: text,
        chatHistory: history,
      );

      final responseText = result['response'] as String;
      final newSchedule = result['schedule'] as List<Map<String, dynamic>>;

      // Save the updated schedule to secure storage
      final newPlanJson = jsonEncode(newSchedule);
      await _prefsService.setAiDayPlanJson(newPlanJson);
      _currentPlanJson = newPlanJson;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': responseText
        });
        _isLoading = false;
        _scheduleUpdated = true;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Sorry, I encountered an error while trying to update your plan: $e. Please make sure your prompt is valid or try again.'
        });
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
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
            children: [
              // Premium Header
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
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFFC4B5FD), size: 18),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI Schedule Refiner',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Online & Ready',
                                    style: TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Reset cache helper
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
                      tooltip: 'Reset Conversation',
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _messages.add({
                            'role': 'assistant',
                            'content': 'Conversation history reset! How can I help adjust your daily schedule now?'
                          });
                          _scheduleUpdated = false;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Chat Message List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    return _buildChatBubble(msg['content'] ?? '', isUser);
                  },
                ),
              ),

              // Loading / Thinking indicator
              if (_isLoading) _buildThinkingIndicator(),

              // Success Notification Banner
              if (_scheduleUpdated) _buildSuccessBanner(),

              // Dynamic Suggestion Chips
              if (!_isLoading) _buildSuggestionsList(),

              // Chat Input Bar
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFC4B5FD)),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: GlassContainer(
                opacity: isUser ? 0.2 : 0.05,
                color: isUser ? const Color(0xFF7C3AED) : Colors.white,
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFC4B5FD)),
            ),
            const SizedBox(width: 8),
            GlassContainer(
              opacity: 0.05,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI is updating your timeline...',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GlassContainer(
        opacity: 0.15,
        color: const Color(0xFF10B981),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule Updated Successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The updated timeline has been saved successfully.',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FullScheduleScreen()),
                );
              },
              child: const Text(
                'View Schedule',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              backgroundColor: const Color(0xFF15151D),
              surfaceTintColor: Colors.transparent,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              label: Text(
                suggestion,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
              ),
              onPressed: () => _sendMessage(suggestion),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassContainer(
        opacity: 0.06,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ask AI to modify your timeline...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            GestureDetector(
              onTap: () => _sendMessage(_messageController.text),
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF7C3AED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

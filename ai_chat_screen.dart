import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _typingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final FocusNode _messageFocusNode = FocusNode();

  bool _isTyping = false;
  bool _isInitialized = false;
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic> userHealthData = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
  }

  Future<void> _initializeChat() async {
    try {
      await _loadUserHealthData();
      _addWelcomeMessage();

      if (mounted) {
        _animationController.forward();
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing chat: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _loadUserHealthData() async {
    if (user == null) return;

    try {
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);

      final List<DocumentSnapshot> futures = await Future.wait([
        userRef.collection('mood_logs').doc(dateString).get(),
        userRef.collection('sleep_logs').doc(dateString).get(),
        userRef.collection('water_logs').doc(dateString).get(),
        userRef.collection('activity_logs').doc(dateString).get(),
      ]);

      // Safely parse data with null checks
      Map<String, dynamic>? moodData;
      Map<String, dynamic>? sleepData;
      Map<String, dynamic>? waterData;
      Map<String, dynamic>? activityData;

      try {
        moodData = futures[0].exists ? (futures[0].data() as Map<String, dynamic>?) : null;
      } catch (e) {
        print('Error parsing mood data: $e');
      }

      try {
        sleepData = futures[1].exists ? (futures[1].data() as Map<String, dynamic>?) : null;
      } catch (e) {
        print('Error parsing sleep data: $e');
      }

      try {
        waterData = futures[2].exists ? (futures[2].data() as Map<String, dynamic>?) : null;
      } catch (e) {
        print('Error parsing water data: $e');
      }

      try {
        activityData = futures[3].exists ? (futures[3].data() as Map<String, dynamic>?) : null;
      } catch (e) {
        print('Error parsing activity data: $e');
      }

      // Safe water count parsing
      final glassesVal = waterData?['glasses'];
      final int waterCount = glassesVal is num
          ? (glassesVal).toInt()
          : int.tryParse(glassesVal?.toString() ?? '') ?? 0;

      final dynamic sleepValue = sleepData?['hours'];
      final dynamic moodValue = moodData?['mood'];

      userHealthData = {
        'mood': moodValue,
        'sleep': sleepValue,
        'water': waterCount,
        'activity': activityData,
        'completedToday': _getCompletedCategories(futures),
      };
    } catch (e) {
      print('Error loading health data: $e');
      // Initialize with empty data if there's an error
      userHealthData = {
        'mood': null,
        'sleep': null,
        'water': 0,
        'activity': null,
        'completedToday': <String>[],
      };
    }
  }

  List<String> _getCompletedCategories(List<DocumentSnapshot> futures) {
    final List<String> completed = [];

    try {
      if (futures[0].exists) completed.add('mood');
      if (futures[1].exists) completed.add('sleep');

      if (futures[2].exists) {
        try {
          final Map<String, dynamic>? data = futures[2].data() as Map<String, dynamic>?;
          final glassesVal = data?['glasses'];
          final int glassesCount = glassesVal is num
              ? (glassesVal).toInt()
              : int.tryParse(glassesVal?.toString() ?? '') ?? 0;
          if (glassesCount > 0) completed.add('water');
        } catch (e) {
          print('Error parsing water completion: $e');
        }
      }

      if (futures[3].exists) completed.add('activity');
    } catch (e) {
      print('Error getting completed categories: $e');
    }

    return completed;
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage(
      text: "Hi there! I'm your AI Health Coach. I can help you with wellness advice, answer health questions, and provide personalized recommendations based on your logged data. How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _messages.add(welcomeMessage);
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isTyping) return;

    final messageText = _messageController.text.trim();
    final userMessage = ChatMessage(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _messages.add(userMessage);
        _isTyping = true;
      });
    }

    _messageController.clear();
    _messageFocusNode.unfocus();

    // Improved scroll handling
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottomSmooth();
    });

    _typingController.repeat();

    try {
      // Simulate AI processing time
      await Future.delayed(const Duration(milliseconds: 1500));

      final aiResponse = _generateAIResponse(messageText);
      final aiMessage = ChatMessage(
        text: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
          _isTyping = false;
        });

        _typingController.stop();

        // Scroll to bottom after AI message is added
        Future.delayed(const Duration(milliseconds: 200), () {
          _scrollToBottomSmooth();
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _typingController.stop();
      }
    }
  }

  void _scrollToBottomSmooth() {
    if (_scrollController.hasClients && mounted) {
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } catch (e) {
        print('Error scrolling: $e');
      }
    }
  }

  String _generateAIResponse(String userInput) {
    try {
      final input = userInput.toLowerCase();
      final completedCategories = userHealthData['completedToday'] as List<String>? ?? [];
      final waterCount = userHealthData['water'] as int? ?? 0;
      final mood = userHealthData['mood'];
      final sleep = userHealthData['sleep'];
      final activity = userHealthData['activity'];

      // Greeting responses
      if (input.contains(RegExp(r'\b(hi|hello|hey|good morning|good afternoon|good evening)\b'))) {
        return "Hello! I'm here to help you on your wellness journey. Based on your data today, you've completed ${completedCategories.length}/4 health categories. What would you like to know about?";
      }

      // Water-related questions
      if (input.contains(RegExp(r'\b(water|hydration|drink|thirsty)\b'))) {
        if (waterCount >= 8) {
          return "Excellent! You've reached your daily water goal of 8 glasses. Keep up the great hydration! Did you know proper hydration helps with energy levels, skin health, and cognitive function?";
        } else if (waterCount >= 4) {
          return "Good progress on hydration! You've logged $waterCount glasses today. Try to reach 8 glasses for optimal hydration. I recommend drinking a glass of water every 2 hours during your waking hours.";
        } else {
          return "I notice you've only logged $waterCount glasses of water today. Staying hydrated is crucial for your health! Try setting hourly reminders or keeping a water bottle nearby. Aim for 8 glasses throughout the day.";
        }
      }

      // Sleep-related questions
      if (input.contains(RegExp(r'\b(sleep|tired|exhausted|insomnia|rest)\b'))) {
        if (sleep != null) {
          final num? sleepNum = sleep is num ? sleep as num : num.tryParse(sleep.toString());
          if (sleepNum != null && sleepNum >= 7 && sleepNum <= 9) {
            return "Great job! You logged ${sleepNum}h of sleep, which is in the optimal range of 7-9 hours. Good sleep is essential for physical recovery, mental clarity, and emotional well-being.";
          } else if (sleepNum != null && sleepNum < 7) {
            return "I see you only got ${sleepNum}h of sleep. Most adults need 7-9 hours for optimal health. Consider establishing a bedtime routine, limiting screen time before bed, and keeping your bedroom cool and dark.";
          } else {
            return "You logged ${sleep}h of sleep. While some people need more rest, consistently sleeping over 9 hours might indicate you need better sleep quality. Consider evaluating your sleep environment and habits.";
          }
        } else {
          return "I notice you haven't logged your sleep yet today. Quality sleep is fundamental to good health! Aim for 7-9 hours nightly. Would you like some tips for better sleep hygiene?";
        }
      }

      // Mood-related questions
      if (input.contains(RegExp(r'\b(mood|feeling|emotions|sad|happy|stressed|anxious)\b'))) {
        if (mood != null) {
          final int? moodInt = mood is num ? (mood as num).toInt() : int.tryParse(mood.toString());
          if (moodInt != null && moodInt >= 4) {
            return "I'm glad to see you're feeling positive today! Maintaining good mental health is just as important as physical health. Keep doing whatever is working for you!";
          } else if (moodInt == 3) {
            return "You're feeling okay today, which is normal. If you'd like to boost your mood, consider some light exercise, spending time in nature, or connecting with friends and family.";
          } else {
            return "I notice you're not feeling your best today. It's okay to have difficult days. Consider gentle activities like a short walk, deep breathing exercises, or talking to someone you trust. Your mental health matters.";
          }
        } else {
          return "I don't see a mood entry for today yet. Tracking your emotions can help you identify patterns and triggers. How are you feeling right now?";
        }
      }

      // Activity/exercise questions
      if (input.contains(RegExp(r'\b(exercise|activity|workout|fitness|walk|run|gym)\b'))) {
        if (activity != null && activity is Map<String, dynamic>) {
          final activityType = activity['activity']?.toString() ?? 'activity';
          final durationVal = activity['duration'];
          final int duration = durationVal is num ? durationVal.toInt() : int.tryParse(durationVal?.toString() ?? '') ?? 0;
          return "Awesome! I see you did $activityType for ${duration} minutes today. Regular physical activity boosts mood, improves cardiovascular health, and enhances sleep quality. Keep up the great work!";
        } else {
          return "I don't see any activity logged today yet. Even 15-30 minutes of movement can make a huge difference! Try a brisk walk, some stretching, or any activity you enjoy. What type of exercise interests you most?";
        }
      }

      // General health advice
      if (input.contains(RegExp(r'\b(health|healthy|wellness|advice|tips)\b'))) {
        return "Here are some key wellness tips: 1) Stay hydrated (8 glasses/day), 2) Get 7-9 hours of sleep, 3) Move your body daily, 4) Check in with your emotions, 5) Eat nutritious foods, 6) Practice stress management. You're already tracking these areas - great job!";
      }

      // Motivation and encouragement
      if (input.contains(RegExp(r'\b(motivation|encourage|help|support)\b'))) {
        final completionPercentage = (completedCategories.length / 4 * 100).toInt();
        return "You're doing great! You've completed $completionPercentage% of your health tracking today. Remember, small consistent actions lead to big results. Every step counts toward a healthier you. I believe in your journey!";
      }

      // Default responses for other inputs
      final defaultResponses = [
        "That's an interesting question! Based on your health data today, I'd recommend focusing on the areas you haven't logged yet. Consistent tracking helps me give you better advice.",
        "I'm here to help with health and wellness guidance. Could you tell me more specifically what you'd like to know about your health journey?",
        "As your AI health coach, I can provide advice on sleep, nutrition, exercise, mood, and general wellness. What aspect of your health would you like to discuss?",
      ];

      return defaultResponses[math.Random().nextInt(defaultResponses.length)];
    } catch (e) {
      print('Error generating AI response: $e');
      return "I'm here to help with your health journey! Could you tell me what you'd like to know about?";
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _typingController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: GestureDetector(
                onTap: () => _messageFocusNode.unfocus(),
                child: _buildChatArea(),
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Health Coach',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Always here to help',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints.expand(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        physics: const ClampingScrollPhysics(),
        itemCount: _messages.length + (_isTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _messages.length && _isTyping) {
            return _buildTypingIndicator();
          }

          if (index < _messages.length) {
            return _buildMessageBubble(_messages[index]);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? const Color(0xFF6366F1) : Colors.white,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : const Color(0xFF374151),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  (user?.displayName?.isNotEmpty == true
                      ? user!.displayName![0]
                      : user?.email?.isNotEmpty == true
                      ? user!.email![0]
                      : 'U').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: const Radius.circular(4)
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        final animationValue = (_typingController.value + (index * 0.2)) % 1.0;
        return Transform.translate(
          offset: Offset(0, -4 * math.sin(animationValue * 2 * math.pi)),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF6366F1),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  maxLines: null,
                  maxLength: 500, // Prevent extremely long messages
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  enabled: !_isTyping,
                  decoration: const InputDecoration(
                    hintText: 'Ask me anything about your health...',
                    border: InputBorder.none,
                    counterText: '', // Hide character counter
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isTyping ? null : _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isTyping
                        ? [Colors.grey.shade400, Colors.grey.shade500]
                        : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: _isTyping ? [] : [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isTyping ? Icons.hourglass_empty : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
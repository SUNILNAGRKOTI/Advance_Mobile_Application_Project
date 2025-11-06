import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../services/auth_service.dart';
import 'health_logging/mood_tracker_screen.dart';
import 'health_logging/sleep_tracker_screen.dart';
import 'health_logging/water_tracker_screen.dart';
import 'health_logging/Activity_tracker_screen.dart';
import 'health_logging/profile_screen.dart';
import 'health_logging/ai_chat_screen.dart';
import 'health_logging/insights_screen.dart';
import 'auth_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _breathingController;
  late AnimationController _cardAnimationController;
  late AnimationController _bounceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _cardStaggerAnimation;
  late List<Animation<double>> _bounceAnimations;

  final AuthService _authService = AuthService();
  User? user;
  Map<String, dynamic>? userProfile;
  int _currentIndex = 0;

  Stream<DocumentSnapshot>? _userProfileStream;

  Map<String, dynamic> todaysHealth = {
    'mood': null,
    'sleep': null,
    'water': 0,
    'activity': null,
    'streak': 0,
    'completedToday': <String>[],
  };

  List<Map<String, dynamic>> recentActivities = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeFastApp();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this
    );

    _breathingController = AnimationController(
        duration: const Duration(milliseconds: 3000),
        vsync: this
    );

    _cardAnimationController = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this
    );

    _bounceController = AnimationController(
        duration: const Duration(milliseconds: 2000),
        vsync: this
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart)
    );

    _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)
    );

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
        CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut)
    );

    _cardStaggerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardAnimationController, curve: Curves.easeOutCubic)
    );

    // Create staggered bounce animations for 4 quick action items
    _bounceAnimations = List.generate(4, (index) {
      final start = 0.2 + (index * 0.15);
      final end = start + 0.3;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _bounceController,
          curve: Interval(start, end, curve: Curves.elasticOut),
        ),
      );
    });
  }

  Future<void> _initializeFastApp() async {
    user = _authService.currentUser;

    if (mounted) {
      _animationController.forward();
      _breathingController.repeat(reverse: true);
      _cardAnimationController.forward();
      _bounceController.forward();
    }

    if (user != null) {
      _userProfileStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots();
    }

    _loadDataInBackground();
  }

  Future<void> _loadDataInBackground() async {
    if (user == null) return;

    try {
      userProfile = await _authService.getUserProfile();
      if (mounted) setState(() {});

      await _loadHealthDataSilently();

      await Future.wait([
        _calculateStreak(),
        _loadRecentActivities(),
      ]);

      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading background data: $e');
    }
  }

  Future<void> _loadHealthDataSilently() async {
    if (user == null) return;

    try {
      final today = DateTime.now();
      final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);

      final futures = await Future.wait([
        userRef.collection('mood_logs').doc(dateString).get(),
        userRef.collection('sleep_logs').doc(dateString).get(),
        userRef.collection('water_logs').doc(dateString).get(),
        userRef.collection('activity_logs').doc(dateString).get(),
      ]);

      List<String> completedToday = [];

      if (futures[0].exists) {
        todaysHealth['mood'] = futures[0].data()?['mood'];
        completedToday.add('mood');
      }

      if (futures[1].exists) {
        todaysHealth['sleep'] = futures[1].data()?['hours'];
        completedToday.add('sleep');
      }

      if (futures[2].exists) {
        final waterData = futures[2].data();
        final glassesVal = waterData?['glasses'];
        todaysHealth['water'] = glassesVal is num
            ? glassesVal.toInt()
            : int.tryParse(glassesVal?.toString() ?? '') ?? 0;
        if (todaysHealth['water'] > 0) completedToday.add('water');
      }

      if (futures[3].exists) {
        final activityData = futures[3].data()!;
        todaysHealth['activity'] = {
          'type': activityData['activity'] ?? 'Unknown',
          'duration': activityData['duration'] ?? 0,
          'steps': activityData['steps'] ?? 0
        };
        completedToday.add('activity');
      }

      todaysHealth['completedToday'] = completedToday;

    } catch (e) {
      print('Error loading health data: $e');
    }
  }

  Future<void> _calculateStreak() async {
    if (user == null) return;

    try {
      int streak = 0;
      final now = DateTime.now();
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);

      for (int i = 0; i < 30; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final dateString = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';

        final futures = await Future.wait([
          userRef.collection('mood_logs').doc(dateString).get(),
          userRef.collection('sleep_logs').doc(dateString).get(),
          userRef.collection('water_logs').doc(dateString).get(),
          userRef.collection('activity_logs').doc(dateString).get(),
        ]);

        int dayActivities = futures.where((doc) => doc.exists).length;
        if (dayActivities >= 2) {
          streak++;
        } else {
          break;
        }
      }
      todaysHealth['streak'] = streak;
    } catch (e) {
      todaysHealth['streak'] = 0;
    }
  }

  Future<void> _loadRecentActivities() async {
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final now = DateTime.now();
      List<Map<String, dynamic>> activities = [];

      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final collections = ['mood_logs', 'sleep_logs', 'water_logs', 'activity_logs'];
        final collectionNames = ['mood', 'sleep', 'water', 'activity'];

        for (int j = 0; j < collections.length; j++) {
          try {
            final doc = await userRef.collection(collections[j]).doc(dateString).get();
            if (doc.exists) {
              final data = doc.data()!;
              activities.add({
                'type': collectionNames[j],
                'data': data,
                'timestamp': data['timestamp'] ?? Timestamp.fromDate(date)
              });
            }
          } catch (e) {
            print('Error loading ${collections[j]}: $e');
          }
        }
      }

      activities.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
      recentActivities = activities.take(5).toList();
    } catch (e) {
      print('Error loading recent activities: $e');
    }
  }

  String _getDisplayName() {
    if (userProfile != null && userProfile!['name'] != null && userProfile!['name'].toString().isNotEmpty) {
      return userProfile!['name'].toString();
    }
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user!.displayName!;
    }
    return 'User';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _breathingController.dispose();
    _cardAnimationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getMoodEmoji(int? mood) {
    if (mood == null) return '😐';
    switch (mood) {
      case 1: return '😟';
      case 2: return '😐';
      case 3: return '🙂';
      case 4: return '😊';
      case 5: return '😄';
      default: return '😐';
    }
  }

  String _getActivityEmoji(String type) {
    switch (type) {
      case 'mood': return '😊';
      case 'sleep': return '😴';
      case 'water': return '💧';
      case 'activity': return '🏃‍♂️';
      default: return '📝';
    }
  }

  String _getActivityTitle(String type, Map<String, dynamic> data) {
    try {
      switch (type) {
        case 'mood':
          return 'Updated mood to ${_getMoodEmoji(data['mood'])}';
        case 'sleep':
          return 'Logged ${data['hours'] ?? 0}h of sleep';
        case 'water':
          return 'Drank ${data['glasses'] ?? 0} glasses of water';
        case 'activity':
          final duration = data['duration'] ?? 0;
          final activity = data['activity'] ?? 'activity';
          return 'Completed ${activity.toString().toLowerCase()} (${duration is num ? duration.toInt() : duration}min)';
        default:
          return 'Logged health data';
      }
    } catch (e) {
      return 'Logged health data';
    }
  }

  String _formatTimeAgo(Timestamp timestamp) {
    try {
      final now = DateTime.now();
      final time = timestamp.toDate();
      final diff = now.difference(time);
      if (diff.inMinutes < 60) return '${diff.inMinutes}min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return 'Recently';
    }
  }

  double _getCompletionPercentage() {
    final completed = todaysHealth['completedToday'] as List<String>? ?? <String>[];
    return completed.length / 4.0;
  }

  String _generateAISuggestion() {
    final completed = todaysHealth['completedToday'] as List<String>? ?? <String>[];
    final waterCount = (todaysHealth['water'] as int?) ?? 0;

    if (completed.length == 4) {
      return "Amazing! You've completed all your health tracking today. Keep up this fantastic routine!";
    } else if (waterCount < 4) {
      return "You're doing great! Try to drink ${8 - waterCount} more glasses of water today to stay hydrated.";
    } else if (!completed.contains('sleep')) {
      return "Don't forget to log your sleep hours! Good sleep tracking helps identify patterns for better rest.";
    } else if (!completed.contains('mood')) {
      return "Take a moment to check in with yourself - how are you feeling today? Mood tracking builds self-awareness.";
    } else if (!completed.contains('activity')) {
      return "A short 15-minute walk can boost your energy and mood. Your body will thank you!";
    }
    return "You're making excellent progress on your health journey. Every small step counts!";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildChatTab(),
          _buildInsightsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadDataInBackground();
        if (mounted) setState(() {});
      },
      color: const Color(0xFF667eea),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 10),
                _buildStreakCard(),
                const SizedBox(height: 20),
                _buildProgressCard(),
                const SizedBox(height: 20),
                _buildHealthSummaryCards(),
                const SizedBox(height: 24),
                _buildAISuggestionCard(),
                const SizedBox(height: 24),
                _buildQuickActionsSection(),
                const SizedBox(height: 24),
                _buildRecentActivityCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      pinned: true,
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_userProfileStream != null && user != null)
                              StreamBuilder<DocumentSnapshot>(
                                stream: _userProfileStream,
                                builder: (context, snapshot) {
                                  String displayName = _getDisplayName();

                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                                    if (data != null && data['name'] != null && data['name'].toString().isNotEmpty) {
                                      displayName = data['name'].toString();
                                    }
                                  }

                                  return Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  );
                                },
                              )
                            else
                              Text(
                                _getDisplayName(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _currentIndex = 3);
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)]
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: user?.photoURL != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              user!.photoURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, color: Colors.white, size: 24),
                            ),
                          )
                              : const Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    final streakCount = (todaysHealth['streak'] as int?) ?? 0;
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: AnimatedBuilder(
              animation: _breathingAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _breathingAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: streakCount > 0
                            ? [const Color(0xFFFFD700), const Color(0xFFFF8C00), const Color(0xFFB8860B)]
                            : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (streakCount > 0 ? const Color(0xFFFFD700) : const Color(0xFF667eea)).withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            streakCount > 0 ? Icons.local_fire_department : Icons.stars,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$streakCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'DAY${streakCount != 1 ? 'S' : ''}\nSTREAK',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                streakCount == 0
                                    ? 'Start your wellness journey today!'
                                    : 'You\'re building an amazing healthy habit!',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressCard() {
    final percentage = _getCompletionPercentage();
    final completedCount = (todaysHealth['completedToday'] as List<String>? ?? <String>[]).length;

    return AnimatedBuilder(
      animation: _cardStaggerAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(_cardStaggerAnimation),
          child: FadeTransition(
            opacity: _cardStaggerAnimation,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: percentage == 1.0
                      ? [const Color(0xFF00D4AA), const Color(0xFF00B894)]
                      : [const Color(0xFF6C5CE7), const Color(0xFDA085)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (percentage == 1.0 ? const Color(0xFF00D4AA) : const Color(0xFF6C5CE7)).withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Progress',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${(percentage * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                value: percentage,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 4,
                              ),
                            ),
                            Text(
                              '$completedCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    percentage == 1.0
                        ? 'Perfect! All categories completed!'
                        : '${4 - completedCount} ${4 - completedCount == 1 ? 'category' : 'categories'} remaining',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthSummaryCards() {
    return AnimatedBuilder(
      animation: _cardStaggerAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(_cardStaggerAnimation),
          child: FadeTransition(
            opacity: _cardStaggerAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Health Summary',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildHealthCard(
                        'Mood',
                        _getMoodEmoji(todaysHealth['mood']),
                        todaysHealth['mood'] != null ? 'Logged' : 'Not logged',
                        const Color(0xFFFFD93D),
                        todaysHealth['mood'] != null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildHealthCard(
                        'Sleep',
                        '😴',
                        todaysHealth['sleep'] != null
                            ? '${todaysHealth['sleep']}h'
                            : 'Not logged',
                        const Color(0xFF667eea),
                        todaysHealth['sleep'] != null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildHealthCard(
                        'Water',
                        '💧',
                        '${todaysHealth['water']}/8',
                        const Color(0xFF4ECDC4),
                        todaysHealth['water'] > 0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildHealthCard(
                        'Activity',
                        '👟',
                        todaysHealth['activity'] != null
                            ? '${todaysHealth['activity']['type']}'
                            : 'Not logged',
                        const Color(0xFF6BCF7F),
                        todaysHealth['activity'] != null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthCard(String title, String emoji, String value, Color color, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? color.withOpacity(0.4) : color.withOpacity(0.1),
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted ? color.withOpacity(0.15) : Colors.black.withOpacity(0.06),
            blurRadius: isCompleted ? 15 : 10,
            offset: Offset(0, isCompleted ? 6 : 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              Icon(
                isCompleted ? Icons.check_circle : Icons.add_circle_outline,
                color: color,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isCompleted ? color : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestionCard() {
    return AnimatedBuilder(
      animation: _cardStaggerAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(_cardStaggerAnimation),
          child: FadeTransition(
            opacity: _cardStaggerAnimation,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.psychology_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'AI Health Coach',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'SMART',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _generateAISuggestion(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      {
        'icon': Icons.mood,
        'label': 'Mood',
        'color': const Color(0xFFFFD93D),
        'completed': (todaysHealth['completedToday'] as List<String>? ?? <String>[]).contains('mood'),
        'screen': const MoodTrackerScreen(),
      },
      {
        'icon': Icons.bedtime,
        'label': 'Sleep',
        'color': const Color(0xFF667eea),
        'completed': (todaysHealth['completedToday'] as List<String>? ?? <String>[]).contains('sleep'),
        'screen': const SleepTrackerScreen(),
      },
      {
        'icon': Icons.local_drink,
        'label': 'Water',
        'color': const Color(0xFF4ECDC4),
        'completed': (todaysHealth['completedToday'] as List<String>? ?? <String>[]).contains('water'),
        'screen': const WaterTrackerScreen(),
      },
      {
        'icon': Icons.directions_walk,
        'label': 'Activity',
        'color': const Color(0xFF6BCF7F),
        'completed': (todaysHealth['completedToday'] as List<String>? ?? <String>[]).contains('activity'),
        'screen': const ActivityTrackerScreen(),
      },
    ];

    return AnimatedBuilder(
      animation: _cardStaggerAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(_cardStaggerAnimation),
          child: FadeTransition(
            opacity: _cardStaggerAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: actions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final action = entry.value;
                    final isCompleted = action['completed'] as bool;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index < actions.length - 1 ? 12 : 0,
                        ),
                        child: AnimatedBuilder(
                          animation: _bounceAnimations[index],
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.8 + (_bounceAnimations[index].value * 0.2),
                              child: GestureDetector(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  final result = await Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, _) => action['screen'] as Widget,
                                      transitionDuration: const Duration(milliseconds: 300),
                                      transitionsBuilder: (context, animation, _, child) {
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(1.0, 0.0),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          ),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                  if (result == true) {
                                    await _loadDataInBackground();
                                    if (mounted) setState(() {});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isCompleted
                                          ? (action['color'] as Color).withOpacity(0.4)
                                          : (action['color'] as Color).withOpacity(0.1),
                                      width: isCompleted ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isCompleted
                                            ? (action['color'] as Color).withOpacity(0.2)
                                            : Colors.black.withOpacity(0.06),
                                        blurRadius: isCompleted ? 15 : 8,
                                        offset: Offset(0, isCompleted ? 6 : 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: (action['color'] as Color).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              action['icon'] as IconData,
                                              color: action['color'] as Color,
                                              size: 24,
                                            ),
                                          ),
                                          if (isCompleted)
                                            Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: action['color'] as Color,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.white, width: 2),
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        action['label'] as String,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isCompleted
                                              ? action['color'] as Color
                                              : const Color(0xFF64748B),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityCard() {
    return AnimatedBuilder(
      animation: _cardStaggerAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).animate(_cardStaggerAnimation),
          child: FadeTransition(
            opacity: _cardStaggerAnimation,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (recentActivities.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${recentActivities.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667eea),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (recentActivities.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.timeline, color: Colors.grey.shade400, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'No recent activities',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start logging your health data to see your activity timeline',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: recentActivities.map((activity) => Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  _getActivityEmoji(activity['type']),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getActivityTitle(activity['type'], activity['data']),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeAgo(activity['timestamp']),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF6366F1).withOpacity(0.05), Colors.white],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Your personal wellness companion',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1).withOpacity(0.1),
                            const Color(0xFF8B5CF6).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Start a Conversation',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        'Get personalized health advice, ask questions about wellness, and receive smart recommendations based on your data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                            const AIChatScreen(),
                            transitionDuration: const Duration(milliseconds: 400),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Start Chatting',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    return const InsightsScreen();
  }

  Widget _buildProfileTab() {
    return const ProfileScreen();
  }

  Widget _buildBottomNav() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 25,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Home', 0),
                  _buildNavItem(Icons.chat_bubble_outline, 'Chat', 1),
                  _buildNavItem(Icons.analytics_rounded, 'Insights', 2),
                  _buildNavItem(Icons.person_rounded, 'Profile', 3),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF667eea).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF667eea) : Colors.grey.shade500,
              size: isActive ? 26 : 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF667eea) : Colors.grey.shade500,
                fontSize: isActive ? 13 : 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
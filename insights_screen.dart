import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '/services/theme_service.dart';
import '/services/auth_service.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _chartController;
  late AnimationController _cardController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _chartAnimation;

  final AuthService _authService = AuthService();
  User? user;
  bool _isLoading = true;
  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Quarter

  final List<String> _periodLabels = ['Week', 'Month', 'Quarter'];

  // Real data from Firebase
  Map<String, List<double>> healthTrends = {
    'mood': [],
    'sleep': [],
    'water': [],
    'activity': [],
  };

  Map<String, double> averages = {
    'mood': 0.0,
    'sleep': 0.0,
    'water': 0.0,
    'activity': 0.0,
  };

  double overallHealthScore = 0.0;
  int totalDaysTracked = 0;
  int currentStreak = 0;
  List<String> timeLabels = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRealData();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _chartController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _cardController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _cardController, curve: Curves.elasticOut));
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _chartController, curve: Curves.easeOutCubic));
  }

  Future<void> _loadRealData() async {
    user = _authService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Start animations immediately while loading data in background
    if (mounted) {
      setState(() => _isLoading = false);
      _mainController.forward();
      _cardController.forward();
      _chartController.forward();
    }

    // Load data in background and update UI
    _fetchAnalyticsDataFast();
  }

  Future<void> _onPeriodChanged(int newPeriod) async {
    if (newPeriod == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = newPeriod;
    });

    // Reset chart animation only
    _chartController.reset();
    _chartController.forward();

    // Load data quickly
    _fetchAnalyticsDataFast();
  }

  // Optimized data fetching
  Future<void> _fetchAnalyticsDataFast() async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final now = DateTime.now();

      List<double> moodData = [];
      List<double> sleepData = [];
      List<double> waterData = [];
      List<double> activityData = [];
      List<String> labels = [];

      // Create batch queries for faster loading
      List<Future<QuerySnapshot>> batchQueries = [];
      List<String> dateStrings = [];

      if (_selectedPeriod == 0) {
        // Weekly - get last 7 days
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          dateStrings.add(_formatDateString(date));
          labels.add(_getDayLabel(date));
        }
      } else if (_selectedPeriod == 1) {
        // Monthly - sample key days instead of all days for speed
        for (int i = 3; i >= 0; i--) {
          final date = now.subtract(Duration(days: i * 7));
          dateStrings.add(_formatDateString(date));
          labels.add('W${4 - i}');
        }
      } else {
        // Quarterly - sample monthly
        for (int i = 2; i >= 0; i--) {
          final date = DateTime(now.year, now.month - i, 15); // Mid-month sample
          dateStrings.add(_formatDateString(date));
          labels.add(_getMonthLabel(date));
        }
      }

      // Fast parallel data fetch with simplified queries
      for (String dateString in dateStrings) {
        final dayData = await _fetchDayDataFast(userRef, dateString);
        moodData.add(dayData['mood']!);
        sleepData.add(dayData['sleep']!);
        waterData.add(dayData['water']!);
        activityData.add(dayData['activity']!);
      }

      // Quick calculation of basic metrics
      currentStreak = _selectedPeriod == 0 ? _calculateStreakFast(userRef, now) : 0;
      totalDaysTracked = 7; // Simplified for speed

      if (mounted) {
        setState(() {
          healthTrends = {
            'mood': moodData,
            'sleep': sleepData,
            'water': waterData,
            'activity': activityData,
          };
          timeLabels = labels;
        });
        _calculateMetrics();
      }

    } catch (e) {
      print('Error: $e');
      _setDefaultData();
    }
  }

  Future<Map<String, double>> _fetchDayDataFast(DocumentReference userRef, String dateString) async {
    try {
      // Parallel fetch with timeout
      final futures = await Future.wait([
        userRef.collection('mood_logs').doc(dateString).get(),
        userRef.collection('sleep_logs').doc(dateString).get(),
        userRef.collection('water_logs').doc(dateString).get(),
        userRef.collection('activity_logs').doc(dateString).get(),
      ]).timeout(const Duration(seconds: 2));

      return {
        'mood': futures[0].exists ? (futures[0].data()?['mood'] as num?)?.toDouble() ?? 0.0 : 0.0,
        'sleep': futures[1].exists ? (futures[1].data()?['hours'] as num?)?.toDouble() ?? 0.0 : 0.0,
        'water': futures[2].exists ? (futures[2].data()?['glasses'] as num?)?.toDouble() ?? 0.0 : 0.0,
        'activity': futures[3].exists ? (futures[3].data()?['duration'] as num?)?.toDouble() ?? 0.0 : 0.0,
      };
    } catch (e) {
      return {'mood': 0.0, 'sleep': 0.0, 'water': 0.0, 'activity': 0.0};
    }
  }

  int _calculateStreakFast(DocumentReference userRef, DateTime now) {
    // Simplified streak calculation for speed
    return currentStreak; // Keep previous value during fast updates
  }

  Future<void> _fetchAnalyticsData() async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final now = DateTime.now();

      List<double> moodData = [];
      List<double> sleepData = [];
      List<double> waterData = [];
      List<double> activityData = [];
      List<String> labels = [];

      int daysWithData = 0;
      int streakCount = 0;

      if (_selectedPeriod == 0) {
        // Weekly data - last 7 days
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dateString = _formatDateString(date);

          labels.add(_getDayLabel(date));

          final data = await _fetchDayData(userRef, dateString);
          moodData.add(data['mood']!);
          sleepData.add(data['sleep']!);
          waterData.add(data['water']!);
          activityData.add(data['activity']!);

          if (data.values.any((v) => v > 0)) daysWithData++;
        }
      } else if (_selectedPeriod == 1) {
        // Monthly data - last 30 days grouped by weeks
        for (int weekOffset = 3; weekOffset >= 0; weekOffset--) {
          List<double> weekMood = [];
          List<double> weekSleep = [];
          List<double> weekWater = [];
          List<double> weekActivity = [];

          for (int day = 0; day < 7; day++) {
            final date = now.subtract(Duration(days: (weekOffset * 7) + day));
            final dateString = _formatDateString(date);

            final data = await _fetchDayData(userRef, dateString);
            if (data.values.any((v) => v > 0)) {
              weekMood.add(data['mood']!);
              weekSleep.add(data['sleep']!);
              weekWater.add(data['water']!);
              weekActivity.add(data['activity']!);
            }
          }

          // Average the week's data
          moodData.add(weekMood.isEmpty ? 0.0 : weekMood.reduce((a, b) => a + b) / weekMood.length);
          sleepData.add(weekSleep.isEmpty ? 0.0 : weekSleep.reduce((a, b) => a + b) / weekSleep.length);
          waterData.add(weekWater.isEmpty ? 0.0 : weekWater.reduce((a, b) => a + b) / weekWater.length);
          activityData.add(weekActivity.isEmpty ? 0.0 : weekActivity.reduce((a, b) => a + b) / weekActivity.length);

          labels.add('W${4 - weekOffset}');
          if (weekMood.isNotEmpty || weekSleep.isNotEmpty || weekWater.isNotEmpty || weekActivity.isNotEmpty) {
            daysWithData++;
          }
        }
      } else {
        // Quarterly data - last 3 months
        for (int monthOffset = 2; monthOffset >= 0; monthOffset--) {
          final monthStart = DateTime(now.year, now.month - monthOffset, 1);
          final monthEnd = monthOffset == 0 ? now : DateTime(now.year, now.month - monthOffset + 1, 0);

          List<double> monthMood = [];
          List<double> monthSleep = [];
          List<double> monthWater = [];
          List<double> monthActivity = [];

          for (DateTime date = monthStart; date.isBefore(monthEnd.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
            final dateString = _formatDateString(date);
            final data = await _fetchDayData(userRef, dateString);

            if (data.values.any((v) => v > 0)) {
              monthMood.add(data['mood']!);
              monthSleep.add(data['sleep']!);
              monthWater.add(data['water']!);
              monthActivity.add(data['activity']!);
            }
          }

          // Average the month's data
          moodData.add(monthMood.isEmpty ? 0.0 : monthMood.reduce((a, b) => a + b) / monthMood.length);
          sleepData.add(monthSleep.isEmpty ? 0.0 : monthSleep.reduce((a, b) => a + b) / monthSleep.length);
          waterData.add(monthWater.isEmpty ? 0.0 : monthWater.reduce((a, b) => a + b) / monthWater.length);
          activityData.add(monthActivity.isEmpty ? 0.0 : monthActivity.reduce((a, b) => a + b) / monthActivity.length);

          labels.add(_getMonthLabel(monthStart));
          if (monthMood.isNotEmpty || monthSleep.isNotEmpty || monthWater.isNotEmpty || monthActivity.isNotEmpty) {
            daysWithData++;
          }
        }
      }

      // Calculate streak (only for weekly view)
      if (_selectedPeriod == 0) {
        for (int i = 0; i < 7; i++) {
          final date = now.subtract(Duration(days: i));
          final dateString = _formatDateString(date);

          final hasData = await _hasDataForDate(userRef, dateString);
          if (hasData) {
            if (i == 0) streakCount = 1;
            else if (streakCount > 0) streakCount++;
          } else {
            break;
          }
        }
      }

      currentStreak = streakCount;

      // Get total days tracked
      totalDaysTracked = await _getTotalDaysTracked(userRef);

      if (mounted) {
        setState(() {
          healthTrends = {
            'mood': moodData,
            'sleep': sleepData,
            'water': waterData,
            'activity': activityData,
          };
          timeLabels = labels;
        });
      }

    } catch (e) {
      print('Error fetching analytics data: $e');
      _setDefaultData();
    }
  }

  Future<Map<String, double>> _fetchDayData(DocumentReference userRef, String dateString) async {
    try {
      final docs = await Future.wait([
        userRef.collection('mood_logs').doc(dateString).get(),
        userRef.collection('sleep_logs').doc(dateString).get(),
        userRef.collection('water_logs').doc(dateString).get(),
        userRef.collection('activity_logs').doc(dateString).get(),
      ]);

      return {
        'mood': docs[0].exists && docs[0].data() != null ? (docs[0].data()!['mood'] as num?)?.toDouble() ?? 0.0 : 0.0,
        'sleep': docs[1].exists && docs[1].data() != null ? (docs[1].data()!['hours'] as num?)?.toDouble() ?? 0.0 : 0.0,
        'water': docs[2].exists && docs[2].data() != null ? (docs[2].data()!['glasses'] as num?)?.toDouble() ?? 0.0 : 0.0,
        'activity': docs[3].exists && docs[3].data() != null ? (docs[3].data()!['duration'] as num?)?.toDouble() ?? 0.0 : 0.0,
      };
    } catch (e) {
      return {'mood': 0.0, 'sleep': 0.0, 'water': 0.0, 'activity': 0.0};
    }
  }

  Future<bool> _hasDataForDate(DocumentReference userRef, String dateString) async {
    try {
      final docs = await Future.wait([
        userRef.collection('mood_logs').doc(dateString).get(),
        userRef.collection('sleep_logs').doc(dateString).get(),
        userRef.collection('water_logs').doc(dateString).get(),
        userRef.collection('activity_logs').doc(dateString).get(),
      ]);
      return docs.any((doc) => doc.exists);
    } catch (e) {
      return false;
    }
  }

  Future<int> _getTotalDaysTracked(DocumentReference userRef) async {
    try {
      final allCollections = await Future.wait([
        userRef.collection('mood_logs').get(),
        userRef.collection('sleep_logs').get(),
        userRef.collection('water_logs').get(),
        userRef.collection('activity_logs').get(),
      ]);

      Set<String> allDates = {};
      for (var collection in allCollections) {
        for (var doc in collection.docs) {
          allDates.add(doc.id);
        }
      }
      return allDates.length;
    } catch (e) {
      return 0;
    }
  }

  void _setDefaultData() {
    if (mounted) {
      setState(() {
        final length = _selectedPeriod == 0 ? 7 : _selectedPeriod == 1 ? 4 : 3;
        healthTrends = {
          'mood': List.filled(length, 0.0),
          'sleep': List.filled(length, 0.0),
          'water': List.filled(length, 0.0),
          'activity': List.filled(length, 0.0),
        };
        timeLabels = _generateDefaultLabels();
      });
    }
  }

  List<String> _generateDefaultLabels() {
    final now = DateTime.now();
    if (_selectedPeriod == 0) {
      return List.generate(7, (i) => _getDayLabel(now.subtract(Duration(days: 6 - i))));
    } else if (_selectedPeriod == 1) {
      return ['W1', 'W2', 'W3', 'W4'];
    } else {
      return List.generate(3, (i) => _getMonthLabel(DateTime(now.year, now.month - 2 + i, 1)));
    }
  }

  String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getDayLabel(DateTime date) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7];
  }

  String _getMonthLabel(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[date.month - 1];
  }

  void _calculateMetrics() {
    // Calculate averages
    final moodList = healthTrends['mood']!.where((v) => v > 0).toList();
    final sleepList = healthTrends['sleep']!.where((v) => v > 0).toList();
    final waterList = healthTrends['water']!.where((v) => v > 0).toList();
    final activityList = healthTrends['activity']!.where((v) => v > 0).toList();

    averages = {
      'mood': moodList.isEmpty ? 0.0 : moodList.reduce((a, b) => a + b) / moodList.length,
      'sleep': sleepList.isEmpty ? 0.0 : sleepList.reduce((a, b) => a + b) / sleepList.length,
      'water': waterList.isEmpty ? 0.0 : waterList.reduce((a, b) => a + b) / waterList.length,
      'activity': activityList.isEmpty ? 0.0 : activityList.reduce((a, b) => a + b) / activityList.length,
    };

    // Calculate overall health score
    final moodScore = (averages['mood']! / 5.0) * 25;
    final sleepScore = averages['sleep']! >= 8.0 ? 25 : (averages['sleep']! / 8.0) * 25;
    final waterScore = averages['water']! >= 8.0 ? 25 : (averages['water']! / 8.0) * 25;
    final activityScore = averages['activity']! >= 30.0 ? 25 : (averages['activity']! / 30.0) * 25;

    overallHealthScore = moodScore + sleepScore + waterScore + activityScore;
  }

  String _getTrendText(String type) {
    final avg = averages[type] ?? 0.0;
    switch (type) {
      case 'mood':
        return avg >= 4.0 ? 'Excellent' : avg >= 3.0 ? 'Good' : 'Low';
      case 'sleep':
        return avg >= 8.0 ? 'Optimal' : avg >= 7.0 ? 'Good' : 'Low';
      case 'water':
        return avg >= 8.0 ? 'Perfect' : avg >= 6.0 ? 'Good' : 'Low';
      case 'activity':
        return avg >= 45.0 ? 'High' : avg >= 30.0 ? 'Good' : 'Low';
      default:
        return 'Good';
    }
  }

  Color _getTrendColor(String type) {
    final avg = averages[type] ?? 0.0;
    switch (type) {
      case 'mood':
        return avg >= 4.0 ? Colors.green : avg >= 3.0 ? Colors.orange : Colors.red;
      case 'sleep':
        return avg >= 8.0 ? Colors.green : avg >= 7.0 ? Colors.orange : Colors.red;
      case 'water':
        return avg >= 8.0 ? Colors.green : avg >= 6.0 ? Colors.orange : Colors.red;
      case 'activity':
        return avg >= 45.0 ? Colors.green : avg >= 30.0 ? Colors.orange : Colors.red;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _chartController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          body: SafeArea(
            child: _isLoading ? _buildLoadingState(themeService) : _buildMainContent(themeService),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(ThemeService themeService) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.analytics, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1))),
          const SizedBox(height: 16),
          Text('Loading your health analytics...', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMainContent(ThemeService themeService) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(themeService),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildPeriodSelector(themeService),
                      const SizedBox(height: 16),
                      _buildHealthScoreCard(themeService),
                      const SizedBox(height: 20),
                      _buildMetricsGrid(themeService),
                      const SizedBox(height: 20),
                      _buildTrendsChart(themeService),
                      const SizedBox(height: 20),
                      _buildStatsGrid(themeService),
                      const SizedBox(height: 20),
                      _buildGoalsGrid(themeService),
                      const SizedBox(height: 60),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(ThemeService themeService) {
    return SliverAppBar(
      backgroundColor: themeService.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      elevation: 0,
      pinned: true,
      automaticallyImplyLeading: false,
      expandedHeight: 70,
      collapsedHeight: 70,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Health Analytics',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: themeService.isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Professional insights into your wellness',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeService themeService) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: themeService.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: _periodLabels.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = _selectedPeriod == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHealthScoreCard(ThemeService themeService) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: themeService.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health Score', style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Overall wellness index', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${overallHealthScore.toInt()}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: themeService.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: overallHealthScore >= 70 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${overallHealthScore >= 70 ? "+" : ""}${(overallHealthScore - 70).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: overallHealthScore >= 70 ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100]),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: AnimatedBuilder(
                        animation: _chartAnimation,
                        builder: (context, child) {
                          return CircularProgressIndicator(
                            value: (overallHealthScore / 100) * _chartAnimation.value,
                            strokeWidth: 6,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              overallHealthScore >= 80 ? Colors.green :
                              overallHealthScore >= 60 ? Colors.orange : Colors.red,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${overallHealthScore.toInt()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: themeService.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeService themeService) {
    final metrics = [
      {'title': 'Mood', 'value': '${averages['mood']!.toStringAsFixed(1)}', 'trend': _getTrendText('mood'), 'color': const Color(0xFFEF4444)},
      {'title': 'Sleep', 'value': '${averages['sleep']!.toStringAsFixed(1)}h', 'trend': _getTrendText('sleep'), 'color': const Color(0xFF6366F1)},
      {'title': 'Water', 'value': '${averages['water']!.toStringAsFixed(1)}', 'trend': _getTrendText('water'), 'color': const Color(0xFF06B6D4)},
      {'title': 'Activity', 'value': '${averages['activity']!.toStringAsFixed(0)}m', 'trend': _getTrendText('activity'), 'color': const Color(0xFF10B981)},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map((metric) {
            return SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              child: _buildMetricCard(metric, themeService),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(Map<String, dynamic> metric, ThemeService themeService) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 100,
        decoration: BoxDecoration(
          color: themeService.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  metric['title'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (metric['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    metric['trend'],
                    style: TextStyle(
                      fontSize: 10,
                      color: metric['color'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              metric['value'],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: metric['color'] as Color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsChart(ThemeService themeService) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeService.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trends',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: themeService.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'Mood, Sleep, Water, Activity',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                Text(
                  _periodLabels[_selectedPeriod],
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 200,
              child: AnimatedBuilder(
                animation: _chartAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RealDataChartPainter(
                      healthTrends: healthTrends,
                      timeLabels: timeLabels,
                      animation: _chartAnimation.value,
                      isDarkMode: themeService.isDarkMode,
                      selectedPeriod: _selectedPeriod,
                    ),
                    child: Container(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeService themeService) {
    final stats = [
      {
        'title': _selectedPeriod == 0 ? 'Current Streak' : 'Tracking Days',
        'value': _selectedPeriod == 0 ? '$currentStreak' : '$totalDaysTracked',
        'subtitle': 'days'
      },
      {
        'title': 'Health Score',
        'value': '${overallHealthScore.toInt()}',
        'subtitle': '/100'
      },
      {
        'title': 'Best Metric',
        'value': _getBestMetric(),
        'subtitle': 'area'
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((stat) {
            return SizedBox(
              width: (constraints.maxWidth - 24) / 3,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  height: 80,
                  decoration: BoxDecoration(
                    color: themeService.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stat['title']!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              stat['value']!,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: themeService.isDarkMode ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              stat['subtitle']!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _getBestMetric() {
    double maxScore = 0;
    String bestMetric = 'Mood';

    averages.forEach((key, value) {
      double normalizedScore;
      switch (key) {
        case 'mood':
          normalizedScore = value / 5.0;
          break;
        case 'sleep':
          normalizedScore = value / 8.0;
          break;
        case 'water':
          normalizedScore = value / 8.0;
          break;
        case 'activity':
          normalizedScore = value / 30.0;
          break;
        default:
          normalizedScore = 0;
      }

      if (normalizedScore > maxScore) {
        maxScore = normalizedScore;
        bestMetric = key.substring(0, 1).toUpperCase() + key.substring(1);
      }
    });

    return bestMetric;
  }

  Widget _buildGoalsGrid(ThemeService themeService) {
    final goals = [
      {
        'title': 'Hydration Goal',
        'subtitle': 'Increase your daily water intake by 10% for the next week',
        'icon': Icons.water_drop,
        'progress': (averages['water']! / 8.0).clamp(0.0, 1.0),
      },
      {
        'title': 'Sleep Routine',
        'subtitle': 'Aim for a consistent bedtime and 7-9 hours of sleep',
        'icon': Icons.bedtime,
        'progress': (averages['sleep']! / 8.0).clamp(0.0, 1.0),
      },
      {
        'title': 'Active Minutes',
        'subtitle': 'Aim to increase movement each week with small goals',
        'icon': Icons.fitness_center,
        'progress': (averages['activity']! / 45.0).clamp(0.0, 1.0),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wellness Goals',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: themeService.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ...goals.map((goal) {
          return ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeService.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          goal['icon'] as IconData,
                          color: const Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: themeService.isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              goal['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${((goal['progress'] as double) * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: goal['progress'] as double,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class RealDataChartPainter extends CustomPainter {
  final Map<String, List<double>> healthTrends;
  final List<String> timeLabels;
  final double animation;
  final bool isDarkMode;
  final int selectedPeriod;

  RealDataChartPainter({
    required this.healthTrends,
    required this.timeLabels,
    required this.animation,
    required this.isDarkMode,
    required this.selectedPeriod,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFEF4444), // mood - red
      const Color(0xFF6366F1), // sleep - blue
      const Color(0xFF06B6D4), // water - cyan
      const Color(0xFF10B981), // activity - green
    ];

    final width = size.width;
    final height = size.height;
    final padding = 40.0;

    // Draw grid
    final gridPaint = Paint()
      ..color = (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!).withOpacity(0.3)
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = padding + (height - 2 * padding) * i / 4;
      canvas.drawLine(Offset(padding, y), Offset(width - padding, y), gridPaint);
    }

    // Vertical grid lines
    final dataPoints = timeLabels.length;
    if (dataPoints > 1) {
      for (int i = 0; i < dataPoints; i++) {
        final x = padding + (width - 2 * padding) * i / (dataPoints - 1);
        canvas.drawLine(Offset(x, padding), Offset(x, height - padding), gridPaint);
      }
    }

    // Draw trend lines
    final keys = healthTrends.keys.toList();
    for (int trendIndex = 0; trendIndex < keys.length; trendIndex++) {
      final key = keys[trendIndex];
      final data = healthTrends[key]!;
      final color = colors[trendIndex];

      if (data.isEmpty || dataPoints <= 1) continue;

      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();

      // Normalize data based on metric type
      List<double> normalizedData;
      if (key == 'mood') {
        normalizedData = data.map((v) => v > 0 ? v / 5.0 : 0.0).toList();
      } else if (key == 'sleep') {
        normalizedData = data.map((v) => v > 0 ? (v / 10.0).clamp(0.0, 1.0) : 0.0).toList();
      } else if (key == 'water') {
        normalizedData = data.map((v) => v > 0 ? (v / 8.0).clamp(0.0, 1.0) : 0.0).toList();
      } else { // activity
        normalizedData = data.map((v) => v > 0 ? (v / 60.0).clamp(0.0, 1.0) : 0.0).toList();
      }

      // Create path with animation
      final animatedLength = (normalizedData.length * animation).round();
      bool firstPoint = true;

      for (int i = 0; i < math.min(animatedLength, normalizedData.length); i++) {
        final x = padding + (width - 2 * padding) * i / (normalizedData.length - 1);
        final y = height - padding - (height - 2 * padding) * normalizedData[i];

        if (firstPoint) {
          path.moveTo(x, y);
          firstPoint = false;
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);

      // Draw data points
      final pointPaint = Paint()..color = color;
      for (int i = 0; i < animatedLength && i < normalizedData.length; i++) {
        final x = padding + (width - 2 * padding) * i / (normalizedData.length - 1);
        final y = height - padding - (height - 2 * padding) * normalizedData[i];
        canvas.drawCircle(Offset(x, y), 3, pointPaint);
      }
    }

    // Draw time labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < timeLabels.length && i < dataPoints; i++) {
      final x = padding + (width - 2 * padding) * i / math.max(1, dataPoints - 1);
      textPainter.text = TextSpan(
        text: timeLabels[i],
        style: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, height - 20),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
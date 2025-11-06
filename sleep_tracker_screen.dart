import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/auth_service.dart';

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({Key? key}) : super(key: key);

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _sleepAnimationController;
  late AnimationController _moonController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _sleepAnimation;
  late Animation<double> _moonAnimation;

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _noteController = TextEditingController();

  bool isLoading = false;

  // Sleep data
  TimeOfDay? bedTime;
  TimeOfDay? wakeUpTime;
  int sleepQuality = 3; // 1-5 scale
  double sleepDuration = 8.0; // hours

  final List<String> sleepFactors = [
    'Caffeine', 'Screen Time', 'Stress', 'Exercise', 'Room Temperature',
    'Noise', 'Comfort', 'Alcohol', 'Late Meal', 'Medication'
  ];

  List<String> selectedFactors = [];

  final List<Map<String, dynamic>> sleepQualities = [
    {'value': 1, 'emoji': '😴', 'label': 'Very Poor', 'color': Color(0xFFFF6B6B)},
    {'value': 2, 'emoji': '😪', 'label': 'Poor', 'color': Color(0xFFFFB347)},
    {'value': 3, 'emoji': '😐', 'label': 'Okay', 'color': Color(0xFFFFD93D)},
    {'value': 4, 'emoji': '😊', 'label': 'Good', 'color': Color(0xFF4ECDC4)},
    {'value': 5, 'emoji': '😄', 'label': 'Excellent', 'color': Color(0xFF6BCF7F)},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setDefaultTimes();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _sleepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _moonController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _sleepAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _sleepAnimationController, curve: Curves.elasticOut));

    _moonAnimation = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _moonController, curve: Curves.easeInOut));

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
        _sleepAnimationController.forward();
      }
    });
  }

  void _setDefaultTimes() {
    final now = DateTime.now();
    bedTime = TimeOfDay(hour: 22, minute: 30); // Default 10:30 PM
    wakeUpTime = TimeOfDay(hour: 6, minute: 30); // Default 6:30 AM
    _calculateSleepDuration();
  }

  void _calculateSleepDuration() {
    if (bedTime == null || wakeUpTime == null) return;

    // Convert to minutes since midnight
    final bedMinutes = bedTime!.hour * 60 + bedTime!.minute;
    final wakeMinutes = wakeUpTime!.hour * 60 + wakeUpTime!.minute;

    // Calculate duration (handle next day wake up)
    final durationMinutes = wakeMinutes >= bedMinutes
        ? wakeMinutes - bedMinutes
        : (24 * 60 - bedMinutes) + wakeMinutes;

    setState(() {
      sleepDuration = durationMinutes / 60.0;
    });
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  Future<void> _selectTime(BuildContext context, bool isBedTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isBedTime ? bedTime! : wakeUpTime!,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: const Color(0xFF667eea),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isBedTime) {
          bedTime = picked;
        } else {
          wakeUpTime = picked;
        }
      });
      _calculateSleepDuration();
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _sleepAnimationController.dispose();
    _moonController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveSleepData() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      print('🔍 DEBUG: Current user: ${user?.uid}');

      if (user == null) {
        _showMessage('Please log in to save your sleep data', isError: true);
        return;
      }

      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final sleepData = {
        'bedTime': _formatTime(bedTime!),
        'wakeUpTime': _formatTime(wakeUpTime!),
        'sleepDuration': sleepDuration,
        'sleepQuality': sleepQuality,
        'qualityLabel': sleepQualities.firstWhere((q) => q['value'] == sleepQuality)['label'],
        'qualityEmoji': sleepQualities.firstWhere((q) => q['value'] == sleepQuality)['emoji'],
        'note': _noteController.text.trim(),
        'factors': selectedFactors,
        'timestamp': FieldValue.serverTimestamp(),
        'date': dateStr,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      // Save to sleep_logs collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sleep_logs')
          .doc(dateStr)
          .set(sleepData);

      // Update daily_summary
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_summary')
          .doc(dateStr)
          .set({
        'sleep': {
          'duration': sleepDuration,
          'quality': sleepQuality,
          'bedTime': _formatTime(bedTime!),
          'wakeUpTime': _formatTime(wakeUpTime!),
        },
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      HapticFeedback.heavyImpact();
      _showMessage('Sleep data logged successfully! 🌙');

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    } catch (e) {
      print('❌ ERROR: Failed to save sleep data: $e');
      _showMessage('Failed to save sleep data: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF667eea),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B3A), // Dark night theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
        ),
        title: const Text(
          'Sleep Tracker',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_fadeController, _slideController]),
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildSleepVisualization(),
                    const SizedBox(height: 30),
                    _buildTimeSelectors(),
                    const SizedBox(height: 30),
                    _buildSleepQuality(),
                    const SizedBox(height: 30),
                    _buildSleepFactors(),
                    const SizedBox(height: 30),
                    _buildNoteSection(),
                    const SizedBox(height: 30),
                    _buildSaveButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSleepVisualization() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D3561),
            const Color(0xFF1A1B3A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated moon and stars
          AnimatedBuilder(
            animation: _moonAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _moonAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFF8DC),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFF8DC).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bedtime,
                    color: Color(0xFF2D3561),
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          Text(
            'Sleep Duration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            _formatDuration(sleepDuration),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          // Sleep quality indicator
          AnimatedBuilder(
            animation: _sleepAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _sleepAnimation.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      sleepQualities.firstWhere((q) => q['value'] == sleepQuality)['emoji'],
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      sleepQualities.firstWhere((q) => q['value'] == sleepQuality)['label'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: sleepQualities.firstWhere((q) => q['value'] == sleepQuality)['color'],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelectors() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep Schedule',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _buildTimeSelector(
                  'Bedtime',
                  bedTime!,
                  Icons.bedtime,
                  const Color(0xFF667eea),
                      () => _selectTime(context, true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeSelector(
                  'Wake Up',
                  wakeUpTime!,
                  Icons.wb_sunny,
                  const Color(0xFFFFB347),
                      () => _selectTime(context, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(String title, TimeOfDay time, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(time),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepQuality() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How was your sleep quality?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: sleepQualities.map((quality) {
              final isSelected = quality['value'] == sleepQuality;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    sleepQuality = quality['value'];
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 60 : 50,
                  height: isSelected ? 60 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? quality['color'].withOpacity(0.2)
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected
                          ? quality['color']
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      quality['emoji'],
                      style: TextStyle(
                        fontSize: isSelected ? 28 : 24,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepFactors() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What affected your sleep?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply (optional)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sleepFactors.map((factor) {
              final isSelected = selectedFactors.contains(factor);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      selectedFactors.remove(factor);
                    } else {
                      selectedFactors.add(factor);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF667eea).withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF667eea)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    factor,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF667eea)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep Notes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Any dreams, observations, or notes? (optional)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'I had a good night\'s sleep...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : _saveSleepData,
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.bedtime, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Log Sleep Data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
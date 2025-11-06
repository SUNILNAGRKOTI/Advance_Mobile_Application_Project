import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/auth_service.dart';

class MoodTrackerScreen extends StatefulWidget {
  const MoodTrackerScreen({Key? key}) : super(key: key);

  @override
  State<MoodTrackerScreen> createState() => _MoodTrackerScreenState();
}

class _MoodTrackerScreenState extends State<MoodTrackerScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _fadeController;

  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _noteController = TextEditingController();

  int selectedMood = 3; // Default to neutral (1-5 scale)
  bool isLoading = false;
  String selectedMoodLabel = 'Okay';
  String selectedEmoji = '😐';

  final List<Map<String, dynamic>> moods = [
    {'value': 1, 'emoji': '😢', 'label': 'Very Sad', 'color': Color(0xFFFF6B6B)},
    {'value': 2, 'emoji': '😟', 'label': 'Sad', 'color': Color(0xFFFFB347)},
    {'value': 3, 'emoji': '😐', 'label': 'Okay', 'color': Color(0xFFFFD93D)},
    {'value': 4, 'emoji': '😊', 'label': 'Good', 'color': Color(0xFF4ECDC4)},
    {'value': 5, 'emoji': '😄', 'label': 'Excellent', 'color': Color(0xFF6BCF7F)},
  ];

  final List<String> moodFactors = [
    'Work/Study', 'Relationships', 'Health', 'Weather', 'Sleep',
    'Exercise', 'Social', 'Family', 'Finances', 'Personal Growth'
  ];

  List<String> selectedFactors = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _updateMoodData();
  }

  void _initializeAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  void _updateMoodData() {
    final mood = moods.firstWhere((m) => m['value'] == selectedMood);
    setState(() {
      selectedMoodLabel = mood['label'];
      selectedEmoji = mood['emoji'];
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveMoodData() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      print('🔍 DEBUG: Current user: ${user?.uid}');
      print('🔍 DEBUG: User email: ${user?.email}');

      if (user == null) {
        print('❌ ERROR: User is null');
        _showMessage('Please log in to save your mood', isError: true);
        return;
      }

      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      print('🔍 DEBUG: Date string: $dateStr');

      // Prepare mood data
      final moodData = {
        'mood': selectedMood,
        'emoji': selectedEmoji,
        'label': selectedMoodLabel,
        'note': _noteController.text.trim(),
        'factors': selectedFactors,
        'timestamp': FieldValue.serverTimestamp(),
        'date': dateStr,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      print('🔍 DEBUG: Mood data to save: $moodData');

      // Save to mood_logs collection
      print('📝 Attempting to save to mood_logs...');
      final moodLogRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('mood_logs')
          .doc(dateStr);

      await moodLogRef.set(moodData);
      print('✅ SUCCESS: Mood log saved!');

      // Save to daily_summary collection
      print('📝 Attempting to save to daily_summary...');
      final dailySummaryRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_summary')
          .doc(dateStr);

      await dailySummaryRef.set({
        'mood': {
          'value': selectedMood,
          'emoji': selectedEmoji,
          'label': selectedMoodLabel,
        },
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ SUCCESS: Daily summary saved!');

      // Provide haptic feedback and show success message
      HapticFeedback.heavyImpact();
      _showMessage('Mood logged successfully! 🎉');

      // Navigate back after delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to save mood data');
      print('❌ Error details: $e');
      print('❌ Stack trace: $stackTrace');
      _showMessage('Failed to save mood: ${e.toString()}', isError: true);
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
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF64748B)),
        ),
        title: const Text(
          'Mood Tracker',
          style: TextStyle(
            color: Color(0xFF1E293B),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMoodSelector(),
                    const SizedBox(height: 30),
                    _buildMoodFactors(),
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

  Widget _buildMoodSelector() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'How are you feeling today?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 30),

          // Selected mood display
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: moods.firstWhere((m) => m['value'] == selectedMood)['color'].withOpacity(0.1),
                        border: Border.all(
                          color: moods.firstWhere((m) => m['value'] == selectedMood)['color'],
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          selectedEmoji,
                          style: const TextStyle(fontSize: 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selectedMoodLabel,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: moods.firstWhere((m) => m['value'] == selectedMood)['color'],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Mood selection row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: moods.map((mood) {
              final isSelected = mood['value'] == selectedMood;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    selectedMood = mood['value'];
                  });
                  _updateMoodData();
                  _scaleController.reset();
                  _scaleController.forward();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 60 : 50,
                  height: isSelected ? 60 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? mood['color'].withOpacity(0.2)
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected
                          ? mood['color']
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      mood['emoji'],
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

  Widget _buildMoodFactors() {
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
            'What\'s influencing your mood?',
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
            children: moodFactors.map((factor) {
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
            'Add a note',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Describe what happened or how you feel (optional)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Share your thoughts...',
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
            moods.firstWhere((m) => m['value'] == selectedMood)['color'],
            moods.firstWhere((m) => m['value'] == selectedMood)['color'].withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: moods.firstWhere((m) => m['value'] == selectedMood)['color'].withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : _saveMoodData,
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
                Icon(Icons.save_alt, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Save Mood Entry',
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
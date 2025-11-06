import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/auth_service.dart';

class WaterTrackerScreen extends StatefulWidget {
  const WaterTrackerScreen({Key? key}) : super(key: key);

  @override
  State<WaterTrackerScreen> createState() => _WaterTrackerScreenState();
}

class _WaterTrackerScreenState extends State<WaterTrackerScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _rippleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _rippleAnimation;

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _noteController = TextEditingController();

  bool isLoading = false;

  // Water data
  int currentIntake = 0;
  int dailyGoal = 8;

  final List<Map<String, dynamic>> waterSources = [
    {'name': 'Water', 'emoji': '💧', 'ml': 250, 'color': Color(0xFF4ECDC4)},
    {'name': 'Coffee', 'emoji': '☕', 'ml': 200, 'color': Color(0xFF8B4513)},
    {'name': 'Tea', 'emoji': '🍵', 'ml': 200, 'color': Color(0xFF90EE90)},
    {'name': 'Juice', 'emoji': '🧃', 'ml': 250, 'color': Color(0xFFFF8C00)},
    {'name': 'Milk', 'emoji': '🥛', 'ml': 250, 'color': Color(0xFFE8E8E8)},
    {'name': 'Smoothie', 'emoji': '🥤', 'ml': 300, 'color': Color(0xFFFF69B4)},
  ];

  List<Map<String, dynamic>> todaysLog = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTodaysData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _rippleController, curve: Curves.easeOut));

    _fadeController.forward();
  }

  void _loadTodaysData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('water_logs')
          .doc(dateStr)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            currentIntake = data['totalGlasses'] ?? 0;
            dailyGoal = data['dailyGoal'] ?? 8;
            todaysLog = List<Map<String, dynamic>>.from(data['drinks'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Error loading water data: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rippleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addWater(Map<String, dynamic> source) {
    if (!mounted) return;

    setState(() {
      currentIntake++;
      todaysLog.add({
        'name': source['name'],
        'emoji': source['emoji'],
        'ml': source['ml'],
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    });

    _rippleController.forward().then((_) {
      if (mounted) {
        _rippleController.reset();
      }
    });

    HapticFeedback.heavyImpact();
    _showMessage('Added ${source['name']}');
  }

  void _removeLastEntry() {
    if (todaysLog.isEmpty || !mounted) return;

    setState(() {
      currentIntake--;
      todaysLog.removeLast();
    });

    HapticFeedback.lightImpact();
    _showMessage('Removed last entry');
  }

  double get progressPercentage {
    return (currentIntake / dailyGoal).clamp(0.0, 1.0);
  }

  int get totalMl {
    return todaysLog.fold(0, (sum, drink) => sum + (drink['ml'] as int));
  }

  Future<void> _saveWaterData() async {
    if (isLoading || !mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        _showMessage('Please log in to save data');
        return;
      }

      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final waterData = {
        'totalGlasses': currentIntake,
        'totalMl': totalMl,
        'dailyGoal': dailyGoal,
        'progressPercentage': progressPercentage,
        'drinks': todaysLog,
        'note': _noteController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'date': dateStr,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('water_logs')
          .doc(dateStr)
          .set(waterData);

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('daily_summary')
          .doc(dateStr)
          .set({
        'water': {
          'totalGlasses': currentIntake,
          'totalMl': totalMl,
          'goalAchieved': currentIntake >= dailyGoal,
          'progressPercentage': progressPercentage,
        },
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      HapticFeedback.heavyImpact();
      _showMessage('Saved successfully!');

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    } catch (e) {
      _showMessage('Save failed');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4ECDC4),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      // This prevents the keyboard from resizing the UI
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Compact App Bar - Fixed Height
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF4ECDC4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                    padding: const EdgeInsets.all(8),
                  ),
                  const Expanded(
                    child: Text(
                      'Water Tracker',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _removeLastEntry,
                    icon: const Icon(Icons.undo, color: Colors.white, size: 18),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ),

            // Flexible Content Area
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 12,
                    bottom: 80, // Space for save button
                  ),
                  child: Column(
                    children: [
                      _buildCompactProgressCard(),
                      const SizedBox(height: 12),
                      _buildQuickButtons(),
                      const SizedBox(height: 12),
                      _buildCompactSourceGrid(),
                      const SizedBox(height: 12),
                      _buildCompactLogCard(),
                      const SizedBox(height: 12),
                      _buildCompactNoteSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Floating Save Button
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width - 40,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        child: FloatingActionButton.extended(
          onPressed: isLoading ? null : _saveWaterData,
          backgroundColor: const Color(0xFF4ECDC4),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          label: isLoading
              ? const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Saving...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
              : const Text(
            'Save Water Log',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCompactProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF4ECDC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Compact water drop
          AnimatedBuilder(
            animation: _rippleAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (_rippleAnimation.value > 0)
                    Container(
                      width: 60 + (_rippleAnimation.value * 20),
                      height: 60 + (_rippleAnimation.value * 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2 - (_rippleAnimation.value * 0.2)),
                      ),
                    ),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.water_drop,
                      color: Color(0xFF0EA5E9),
                      size: 24,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          Text(
            '$currentIntake / $dailyGoal glasses',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            '${totalMl}ml today',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),

          const SizedBox(height: 16),

          // Compact progress bar
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercentage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '${(progressPercentage * 100).toInt()}% complete',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _addWater({'name': 'Water', 'emoji': '💧', 'ml': 250}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4).withOpacity(0.1),
                foregroundColor: const Color(0xFF4ECDC4),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: const Color(0xFF4ECDC4).withOpacity(0.3)),
                ),
              ),
              child: const Text(
                '+1 Glass',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                _addWater({'name': 'Water', 'emoji': '💧', 'ml': 250});
                Future.delayed(const Duration(milliseconds: 200), () {
                  _addWater({'name': 'Water', 'emoji': '💧', 'ml': 250});
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                foregroundColor: const Color(0xFF0EA5E9),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                ),
              ),
              child: const Text(
                '+2 Glasses',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSourceGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Drink Types',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.1,
            children: waterSources.map((source) {
              return InkWell(
                onTap: () => _addWater(source),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (source['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (source['color'] as Color).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        source['emoji'],
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        source['name'],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        '${source['ml']}ml',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLogCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Today\'s Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (todaysLog.isNotEmpty)
                Text(
                  '${todaysLog.length} entries',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4ECDC4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (todaysLog.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    size: 24,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No drinks logged',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: todaysLog.length,
                itemBuilder: (context, index) {
                  final drink = todaysLog[index];
                  final time = DateTime.fromMillisecondsSinceEpoch(drink['time']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(drink['emoji'], style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${drink['name']} (${drink['ml']}ml)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Notes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'How do you feel today?',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF4ECDC4)),
              ),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: const TextStyle(fontSize: 10),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import '../../services/auth_service.dart';
import '../auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();
  User? user;
  Map<String, dynamic>? userProfile;
  bool _isLoading = true;
  bool _isEditing = false;

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  String? _selectedGender;
  bool _notificationsEnabled = true;
  bool _remindersEnabled = true;

  // Real-time health stats
  int currentStreak = 0;
  double healthScore = 0.0;

  // Today's data
  int todayWaterGlasses = 0;
  double todaySleepHours = 0.0;
  int todaySteps = 0;
  double waterProgress = 0.0;
  double sleepProgress = 0.0;
  double stepsProgress = 0.0;

  // Stream subscriptions for real-time updates
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    _setupRealTimeListeners();
    if (mounted) {
      _animationController.forward();
    }
  }

  void _setupRealTimeListeners() {
    if (user == null) return;

    final String today = _getTodayDateString();
    final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);

    // Listen to water logs
    _subscriptions.add(
        userRef.collection('water_logs').doc(today).snapshots().listen((doc) {
          if (mounted && doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            setState(() {
              todayWaterGlasses = data['glasses'] ?? 0;
              waterProgress = (todayWaterGlasses / 8.0).clamp(0.0, 1.0);
            });
          }
        })
    );

    // Listen to sleep logs
    _subscriptions.add(
        userRef.collection('sleep_logs').doc(today).snapshots().listen((doc) {
          if (mounted && doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            setState(() {
              todaySleepHours = (data['hours'] ?? 0.0).toDouble();
              sleepProgress = (todaySleepHours / 8.0).clamp(0.0, 1.0);
            });
          }
        })
    );

    // Listen to activity logs
    _subscriptions.add(
        userRef.collection('activity_logs').doc(today).snapshots().listen((doc) {
          if (mounted && doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            setState(() {
              todaySteps = data['steps'] ?? 0;
              stepsProgress = (todaySteps / 10000.0).clamp(0.0, 1.0);
            });
          }
        })
    );
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadUserData() async {
    try {
      user = _authService.currentUser;
      if (user != null) {
        userProfile = await _authService.getUserProfile();
        await _calculateHealthStats();

        if (userProfile != null && mounted) {
          // Priority: Firestore name -> Firebase Auth displayName -> empty
          _nameController.text = userProfile!['name']?.toString().trim() ??
              user!.displayName?.toString().trim() ?? '';

          final healthProfile = userProfile!['healthProfile'] as Map<String, dynamic>?;
          if (healthProfile != null) {
            _ageController.text = healthProfile['age']?.toString() ?? '';
            _heightController.text = healthProfile['height']?.toString() ?? '';
            _weightController.text = healthProfile['weight']?.toString() ?? '';
            _selectedGender = healthProfile['gender'];
          }

          final appSettings = userProfile!['appSettings'] as Map<String, dynamic>?;
          if (appSettings != null) {
            _notificationsEnabled = appSettings['notifications'] ?? true;
            _remindersEnabled = appSettings['reminders'] ?? true;
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateHealthStats() async {
    if (user == null) return;

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final now = DateTime.now();
      int streak = 0;
      double totalScore = 0.0;

      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final futures = await Future.wait([
          userRef.collection('water_logs').doc(dateString).get(),
          userRef.collection('sleep_logs').doc(dateString).get(),
          userRef.collection('activity_logs').doc(dateString).get(),
        ]);

        int dayActivities = futures.where((doc) => doc.exists).length;

        if (dayActivities >= 2) {
          if (i == streak) streak++;
          totalScore += dayActivities * 30.0;
        } else if (streak == i) {
          break;
        }
      }

      if (mounted) {
        setState(() {
          currentStreak = streak;
          healthScore = (totalScore / (7 * 3 * 30) * 100).clamp(0, 100);
        });
      }
    } catch (e) {
      print('Error calculating health stats: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_isEditing) return;

    try {
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Update Firebase Auth display name first
      if (_nameController.text.trim().isNotEmpty) {
        await user!.updateDisplayName(_nameController.text.trim());
      }

      final healthProfile = {
        'age': int.tryParse(_ageController.text.trim()),
        'gender': _selectedGender,
        'height': double.tryParse(_heightController.text.trim()),
        'weight': double.tryParse(_weightController.text.trim()),
      };

      final appSettings = {
        'notifications': _notificationsEnabled,
        'reminders': _remindersEnabled,
        'theme': Provider.of<ThemeService>(context, listen: false).isDarkMode ? 'dark' : 'light',
      };

      final userData = {
        'uid': user!.uid,
        'email': user!.email,
        'name': _nameController.text.trim(),
        'healthProfile': healthProfile,
        'appSettings': appSettings,
        'profileCompleted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Use set with merge to create document if it doesn't exist, or update if it does
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set(userData, SetOptions(merge: true));

      if (mounted) {
        // Update local userProfile data immediately
        setState(() {
          userProfile = userData;
          _isEditing = false; // Exit edit mode immediately
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Optional: Refresh data in background to ensure consistency
        _loadUserData();
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
          appBar: _buildAppBar(themeService),
          body: _isLoading ? _buildLoadingState() : _buildMainContent(themeService),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeService themeService) {
    return AppBar(
      backgroundColor: themeService.isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'SwasthyaAI Profile',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: themeService.isDarkMode ? Colors.white : const Color(0xFF111827),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            themeService.toggleTheme();
            HapticFeedback.lightImpact();
          },
          icon: Icon(
            themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode_outlined,
            color: themeService.isDarkMode ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildMainContent(ThemeService themeService) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(themeService),
            const SizedBox(height: 24),
            _buildHealthInsightsRow(themeService),
            const SizedBox(height: 24),
            _buildHealthMetrics(themeService),
            const SizedBox(height: 24),
            _buildSettingsSection(themeService),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ThemeService themeService) {
    final bool isDark = themeService.isDarkMode;

    // Safe method to get display name - prioritize current controller text during editing
    String getDisplayName() {
      if (_isEditing && _nameController.text.isNotEmpty) {
        return _nameController.text;
      }
      if (!_isEditing && _nameController.text.isNotEmpty) {
        return _nameController.text;
      }
      if (userProfile != null && userProfile!['name'] != null && userProfile!['name'].toString().isNotEmpty) {
        return userProfile!['name'].toString();
      }
      if (user?.displayName != null && user!.displayName!.isNotEmpty) {
        return user!.displayName!;
      }
      return 'User';
    }

    // Safe method to get first character
    String getAvatarLetter() {
      final displayName = getDisplayName();
      return displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    }

    // Get age from controller or profile
    String getAge() {
      if (_ageController.text.isNotEmpty) {
        return _ageController.text;
      }
      final healthProfile = userProfile?['healthProfile'] as Map<String, dynamic>?;
      if (healthProfile != null && healthProfile['age'] != null) {
        return healthProfile['age'].toString();
      }
      return '25'; // Default age
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Avatar and Name
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null
                    ? Text(
                  getAvatarLetter(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                )
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Name Section
          if (_isEditing) ...[
            TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              decoration: InputDecoration(
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF6366F1)),
                ),
                hintText: 'Enter your name',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
            ),
          ] else ...[
            Text(
              getDisplayName(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 8),
          if (user?.email != null && !_isEditing)
            Text(
              '@${user!.email!.split('@')[0]}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),

          const SizedBox(height: 20),

          // Stats Row - Show Age field when editing
          if (_isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Age',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
                      ),
                    ),
                    items: ['Male', 'Female', 'Other'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Height (cm)',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Age', getAge(), isDark),
                _buildStatDivider(isDark),
                _buildStatItem('Streak', '${currentStreak}d', isDark),
                _buildStatDivider(isDark),
                _buildStatItem('Health', '${healthScore.toInt()}%', isDark),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Edit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() {
                    _isEditing = true;
                    // Initialize controllers with current data
                    if (_nameController.text.isEmpty) {
                      _nameController.text = getDisplayName();
                    }
                    if (_ageController.text.isEmpty) {
                      _ageController.text = getAge();
                    }
                  });
                }
                HapticFeedback.lightImpact();
              },
              icon: Icon(
                _isEditing ? Icons.save : Icons.edit,
                size: 18,
              ),
              label: Text(
                _isEditing ? 'Save Changes' : 'Edit Profile',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
    );
  }

  Widget _buildHealthInsightsRow(ThemeService themeService) {
    final bool isDark = themeService.isDarkMode;

    return Row(
      children: [
        Expanded(child: _buildInsightCard('Water', '$todayWaterGlasses/8', 'glasses', const Color(0xFF06B6D4), Icons.water_drop, waterProgress, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildInsightCard('Sleep', todaySleepHours.toStringAsFixed(1), 'hours', const Color(0xFF8B5CF6), Icons.bedtime, sleepProgress, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildInsightCard('Steps', todaySteps.toString(), 'steps', const Color(0xFF10B981), Icons.directions_walk, stepsProgress, isDark)),
      ],
    );
  }

  Widget _buildInsightCard(String title, String value, String unit, Color color, IconData icon, double progress, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: Icon(icon, color: color, size: 24),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics(ThemeService themeService) {
    final bool isDark = themeService.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _buildHealthMetricRow('Sleep Quality', _getSleepQualityStatus(), isDark),
          const SizedBox(height: 12),
          _buildHealthMetricRow('Activity Level', _getActivityStatus(), isDark),
          const SizedBox(height: 12),
          _buildHealthMetricRow('Hydration', _getHydrationStatus(), isDark),
        ],
      ),
    );
  }

  String _getSleepQualityStatus() {
    if (todaySleepHours >= 8) return 'Excellent';
    if (todaySleepHours >= 7) return 'Good';
    if (todaySleepHours >= 6) return 'Fair';
    return 'Needs Attention';
  }

  String _getActivityStatus() {
    if (todaySteps >= 10000) return 'Very Active';
    if (todaySteps >= 7500) return 'Active';
    if (todaySteps >= 5000) return 'Moderate';
    return 'Low Activity';
  }

  String _getHydrationStatus() {
    if (todayWaterGlasses >= 8) return 'Well Hydrated';
    if (todayWaterGlasses >= 6) return 'Good';
    if (todayWaterGlasses >= 4) return 'Fair';
    return 'Needs Attention';
  }

  Widget _buildHealthMetricRow(String title, String status, bool isDark) {
    Color statusColor = Colors.green;
    if (status.contains('Needs') || status.contains('Low')) {
      statusColor = Colors.red;
    } else if (status.contains('Fair') || status.contains('Moderate')) {
      statusColor = Colors.orange;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(ThemeService themeService) {
    final bool isDark = themeService.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
          _buildSettingsItem('Dark Mode', Icons.dark_mode, isDark, isSwitch: true, value: isDark, onChanged: (v) => themeService.toggleTheme()),
          _buildSettingsItem('Notifications', Icons.notifications, isDark, isSwitch: true, value: _notificationsEnabled, onChanged: (v) => setState(() => _notificationsEnabled = v!)),
          _buildSettingsItem('Reminders', Icons.schedule, isDark, isSwitch: true, value: _remindersEnabled, onChanged: (v) => setState(() => _remindersEnabled = v!)),
          _buildSettingsItem('Account Settings', Icons.person, isDark, showArrow: true, onTap: () => _showAccountSettings()),
          _buildSettingsItem('Privacy & Security', Icons.security, isDark, showArrow: true, onTap: () => _showPrivacySettings()),
          _buildSettingsItem('Help & Support', Icons.help, isDark, showArrow: true, onTap: () => _showHelpSupport()),
          _buildSettingsItem('Sign Out', Icons.logout, isDark, isDestructive: true, onTap: _signOut),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
      String title,
      IconData icon,
      bool isDark, {
        bool isSwitch = false,
        bool? value,
        Function(bool?)? onChanged,
        bool showArrow = false,
        bool isDestructive = false,
        VoidCallback? onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : (isDark ? Colors.white : const Color(0xFF111827)),
                ),
              ),
            ),
            if (isSwitch)
              Switch(
                value: value ?? false,
                onChanged: onChanged,
                activeColor: const Color(0xFF6366F1),
              ),
            if (showArrow)
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showAccountSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isEditing = true;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Change Email'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Change Password'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacySettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy & Security',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('Data Visibility'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Security Settings'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Delete Account'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSupport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help & Support',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('FAQ'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.contact_support),
                title: const Text('Contact Support'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About SwasthyaAI'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
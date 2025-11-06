import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'auth_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _dotController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _navigateToNextScreen();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 20000),
      vsync: this,
    );

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  void _startAnimations() {
    _mainController.forward();
    _floatController.repeat(reverse: true);
    _rotateController.repeat();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _dotController.repeat();
    });
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 4500));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, _) =>
        user != null ? const DashboardScreen() : const AuthScreen(),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF5B6FEC),
              Color(0xFF7C5CE3),
              Color(0xFF8B4FD9),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated rotating circles in background
            AnimatedBuilder(
              animation: _rotateController,
              builder: (context, child) {
                return Stack(
                  children: List.generate(4, (index) {
                    final angle = _rotateAnimation.value + (index * math.pi / 2);
                    final distance = 150.0 + (index * 30);
                    return Positioned(
                      left: MediaQuery.of(context).size.width / 2 + math.cos(angle) * distance - 50,
                      top: MediaQuery.of(context).size.height / 2 + math.sin(angle) * distance - 50,
                      child: Opacity(
                        opacity: 0.05,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),

            // Main content
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeAnimation, _floatAnimation]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, -_floatAnimation.value),
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo card
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(45),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 50,
                                    offset: const Offset(0, 25),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF7C5CE3).withOpacity(0.5),
                                    blurRadius: 70,
                                    spreadRadius: -10,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(45),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.95),
                                          Colors.white.withOpacity(0.88),
                                        ],
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Gradient shine effect
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: RadialGradient(
                                                center: Alignment.topLeft,
                                                radius: 1.2,
                                                colors: [
                                                  Colors.white.withOpacity(0.4),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Heart icon
                                        Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 95,
                                                height: 95,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      const Color(0xFF5B6FEC).withOpacity(0.15),
                                                      const Color(0xFF8B4FD9).withOpacity(0.1),
                                                    ],
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.favorite_rounded,
                                                  size: 52,
                                                  color: Color(0xFF6B5CE3),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // AI Badge separated
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF5B6FEC),
                                    Color(0xFF8B4FD9),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6B5CE3).withOpacity(0.5),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),

                            const SizedBox(height: 45),

                            // App title
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Color(0xFFF0F0F0)],
                              ).createShader(bounds),
                              child: const Text(
                                'SwasthyaAI',
                                style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Subtitle
                            Text(
                              'Your Health Companion',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.95),
                                letterSpacing: 0.8,
                              ),
                            ),

                            const SizedBox(height: 90),

                            // Animated dots
                            AnimatedBuilder(
                              animation: _dotController,
                              builder: (context, child) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (index) {
                                    final delay = index * 0.3;
                                    final value = (_dotController.value - delay).clamp(0.0, 1.0);
                                    final scale = math.sin(value * math.pi);

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Transform.scale(
                                        scale: 0.5 + (scale * 0.8),
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withOpacity(0.5 + (scale * 0.5)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withOpacity(0.4),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Find Government Jobs',
      subtitle: 'All latest sarkari naukri in one place — Railway, Police, Banking, SSC and more across India!',
      icon: Icons.work_rounded,
      color1: const Color(0xFF1565C0),
      color2: const Color(0xFF1976D2),
      features: [
        '10,000+ jobs updated daily',
        'All India + State jobs covered',
        'Filter by qualification & age',
      ],
    ),
    OnboardingData(
      title: 'Know Your Selection Process',
      subtitle: 'Don\'t just find jobs — know exactly which tests to pass, what syllabus to study and how to get selected!',
      icon: Icons.fact_check_rounded,
      color1: const Color(0xFF1B5E20),
      color2: const Color(0xFF2E7D32),
      features: [
        'Stage-wise test guide',
        'Physical test standards',
        'Complete syllabus breakdown',
      ],
    ),
    OnboardingData(
      title: 'Never Miss a Deadline',
      subtitle: 'Get smart reminders for application deadlines, exam dates, admit cards and results — all tracked for you!',
      icon: Icons.notifications_active_rounded,
      color1: const Color(0xFF880E4F),
      color2: const Color(0xFFAD1457),
      features: [
        'Deadline reminders',
        'Admit card alerts',
        'Result notifications',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/signup');
    }
  }

  void _skip() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),

          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 20,
            child: _currentPage < _pages.length - 1
                ? TextButton(
              onPressed: _skip,
              child: const Text('Skip',
                  style: TextStyle(
                      color: Colors.white, fontSize: 16)),
            )
                : const SizedBox(),
          ),

          // Bottom buttons
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SmoothPageIndicator(
                  controller: _pageController,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    dotColor: Colors.white.withOpacity(0.4),
                    activeDotColor: Colors.white,
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _nextPage,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Next →'
                            : '🚀 Get Started!',
                        style: TextStyle(
                          color: _pages[_currentPage].color1,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [data.color1, data.color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 160),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(data.icon,
                      size: 65, color: Colors.white),
                ),
                const SizedBox(height: 40),
                Text(data.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(data.subtitle,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 15, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: data.features.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check,
                                  size: 14, color: data.color1),
                            ),
                            const SizedBox(width: 12),
                            Text(feature,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
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

class OnboardingData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color1;
  final Color color2;
  final List<String> features;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color1,
    required this.color2,
    required this.features,
  });
}


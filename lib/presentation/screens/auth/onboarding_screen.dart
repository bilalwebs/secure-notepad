import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardData> _slides = const [
    _OnboardData(
      icon: Icons.shield_outlined,
      title: 'End-to-End Encryption',
      subtitle: 'Aapke notes sirf aapke hain.\nYour notes are encrypted and private.',
    ),
    _OnboardData(
      icon: Icons.lock_person_outlined,
      title: 'Biometric & PIN Lock',
      subtitle: 'Fingerprint ya PIN se secure karein.\nProtect with biometrics or PIN.',
    ),
    _OnboardData(
      icon: Icons.cloud_done_outlined,
      title: 'Cloud Backup',
      subtitle: 'Kahin se bhi access karein.\nSync your notes across all devices.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/register');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => context.go('/register'),
                child: Text(
                  'Skip',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            // ── PageView ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide.icon,
                            size: 56,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sora(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppTheme.textLight
                                : AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            height: 1.5,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Dot indicators ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppTheme.primary
                        : (isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Bottom button ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _slides.length - 1
                        ? 'Get Started'
                        : 'Next',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    // Give the splash at least 2 seconds to show.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final user = ref.read(authRepositoryProvider).currentUser;

    if (user == null) {
      // Not logged in → onboarding
      context.go('/onboarding');
    } else if (!user.emailVerified) {
      // Logged in but not verified → verify email
      context.go('/verify-email');
    } else {
      // Logged in and verified → home
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Logo / Icon ──
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 52,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // ── App Name ──
              Text(
                'Secure Notepad',
                style: GoogleFonts.sora(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your notes, your privacy.',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 48),

              // ── Loading indicator ──
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

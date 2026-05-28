import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/auth_provider.dart';

class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  Timer? _pollTimer;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await ref.read(authProvider.notifier).reloadUser();
      if (!mounted) return;

      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null && user.emailVerified) {
        _pollTimer?.cancel();
        context.go('/home');
      }
    });
  }

  Future<void> _resendEmail() async {
    setState(() => _sending = true);
    try {
      await ref.read(authProvider.notifier).resendVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Check your inbox.'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) timer.cancel();
      });
    });
  }

  Future<void> _logout() async {
    _pollTimer?.cancel();
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authRepositoryProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: _logout,
            child: Text(
              'Sign Out',
              style: GoogleFonts.dmSans(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),

              // ── Mail icon ──
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 44,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Verify Your Email',
                style: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Humne ek verification email bheja hai.\n'
                'We sent a verification link to:',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                user?.email ?? '',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Email verify hone par automatically home page par jaayen ge.\n'
                'You\'ll be redirected automatically once verified.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color:
                      isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                ),
              ),

              const Spacer(),

              // ── Resend button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: (_resendSeconds == 0 && !_sending)
                      ? _resendEmail
                      : null,
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.primary,
                          ),
                        )
                      : Text(
                          _resendSeconds > 0
                              ? 'Resend in ${_resendSeconds}s'
                              : 'Resend Verification Email',
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Loading hint ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Checking verification status...',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

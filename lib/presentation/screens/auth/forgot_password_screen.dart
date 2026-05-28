import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:email_validator/email_validator.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _sent = false;

  // 60-second resend timer
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final success = await ref
        .read(authProvider.notifier)
        .sendPasswordReset(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      setState(() => _sent = true);
      _startTimer();
    } else {
      final error = ref.read(authProvider).errorMessage;
      if (error != null) {
        _showError(error);
        ref.read(authProvider.notifier).clearError();
      }
    }
  }

  void _startTimer() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    await ref
        .read(authProvider.notifier)
        .sendPasswordReset(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    _startTimer();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _sent ? _buildSuccess(isDark) : _buildForm(isDark),
        ),
      ),
    );
  }

  // ── Email input form ──

  Widget _buildForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Icon ──
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 32,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Forgot Password?',
            style: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Apna email darj karein. Hum aapko reset link bhej dein ge.\n'
            'Enter your email and we\'ll send a reset link.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendReset(),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email required';
              if (!EmailValidator.validate(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendReset,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Reset Link'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success state ──

  Widget _buildSuccess(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 60),

        // ── Success icon ──
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 28),

        Text(
          'Check Your Email',
          style: GoogleFonts.sora(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isDark ? AppTheme.textLight : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'Humne ek password reset link bheja hai:\n'
          'We sent a password reset link to:',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          _emailCtrl.text.trim(),
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 32),

        // ── Resend button with timer ──
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: (_secondsLeft == 0 && !_loading) ? _resend : null,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primary,
                    ),
                  )
                : Text(
                    _secondsLeft > 0
                        ? 'Resend in ${_secondsLeft}s'
                        : 'Resend Email',
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Back to login ──
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(
            'Back to Sign In',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

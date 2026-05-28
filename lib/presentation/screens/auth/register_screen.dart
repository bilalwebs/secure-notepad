import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:email_validator/email_validator.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _loading = false;

  // Username debounce + availability
  Timer? _usernameDebounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable; // null = not checked, true/false = result

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  // ── Username availability check with debounce ──

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    setState(() => _usernameAvailable = null);

    final trimmed = value.trim().toLowerCase();
    if (trimmed.length < 3) return;

    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _checkingUsername = true);
      try {
        final available = await ref
            .read(authProvider.notifier)
            .checkUsernameAvailable(trimmed);
        if (mounted) {
          setState(() {
            _usernameAvailable = available;
            _checkingUsername = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _checkingUsername = false);
      }
    });
  }

  // ── Password strength ──

  double _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.2;
    return strength.clamp(0, 1);
  }

  String _strengthLabel(double s) {
    if (s < 0.3) return 'Weak';
    if (s < 0.6) return 'Fair';
    if (s < 0.8) return 'Good';
    return 'Strong';
  }

  Color _strengthColor(double s) {
    if (s < 0.3) return Colors.red;
    if (s < 0.6) return Colors.orange;
    if (s < 0.8) return Colors.yellow.shade700;
    return AppTheme.primary;
  }

  // ── Register action ──

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please agree to Terms & Conditions.');
      return;
    }
    if (_usernameAvailable == false) {
      _showError('Username already taken. Choose another.');
      return;
    }

    setState(() => _loading = true);

    final success = await ref.read(authProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _fullNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!success) {
      final error = ref.read(authProvider).errorMessage;
      if (error != null) {
        _showError(error);
        ref.read(authProvider.notifier).clearError();
      }
    }
    // On success the router redirect handles /verify-email.
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

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strength = _passwordStrength(_passwordCtrl.text);

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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Header ──
                Text(
                  'Create Account',
                  style: GoogleFonts.sora(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start your secure journey today.',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Full Name ──
                TextFormField(
                  controller: _fullNameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name required';
                    if (v.trim().length < 2) return 'Enter your full name';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Username ──
                TextFormField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.next,
                  onChanged: _onUsernameChanged,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.alternate_email),
                    suffixIcon: _checkingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameAvailable == null
                            ? null
                            : Icon(
                                _usernameAvailable!
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _usernameAvailable!
                                    ? AppTheme.primary
                                    : AppTheme.error,
                              ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Username required';
                    if (v.trim().length < 3) return 'Min 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                      return 'Letters, numbers, _ only';
                    }
                    if (_usernameAvailable == false) return 'Username taken';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Email ──
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 16),

                // ── Password ──
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}), // rebuild strength bar
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password required';
                    if (v.length < 8) return 'Min 8 characters';
                    return null;
                  },
                ),

                // ── Password strength meter ──
                if (_passwordCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: strength,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                                _strengthColor(strength)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _strengthLabel(strength),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _strengthColor(strength),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // ── Confirm Password ──
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Terms checkbox ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (v) =>
                            setState(() => _agreedToTerms = v ?? false),
                        activeColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Register button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Login link ──
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

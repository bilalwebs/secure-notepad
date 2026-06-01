import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';

class EncryptSheet extends StatefulWidget {
  final String mode;
  final Future<void> Function(String key) onConfirm;

  const EncryptSheet({
    super.key,
    required this.mode,
    required this.onConfirm,
  });

  @override
  State<EncryptSheet> createState() => _EncryptSheetState();
}

class _EncryptSheetState extends State<EncryptSheet> {
  final _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _isLoading = false;

  bool get _isEncrypt => widget.mode == 'encrypt';
  bool get _isKeyEmpty => _keyController.text.isEmpty;

  int get _strength {
    final len = _keyController.text.length;
    if (len == 0) return 0;
    if (len < 4)  return 1;
    if (len < 8)  return 2;
    return 3;
  }

  Color get _strengthColor {
    switch (_strength) {
      case 1: return Colors.red;
      case 2: return Colors.amber;
      case 3: return const Color(0xFF2EC4A9);
      default: return Colors.grey;
    }
  }

  double get _strengthWidth {
    switch (_strength) {
      case 1: return 0.2;
      case 2: return 0.6;
      case 3: return 1.0;
      default: return 0;
    }
  }

  String get _strengthLabel {
    switch (_strength) {
      case 1: return 'Too short';
      case 2: return 'Weak';
      case 3: return 'Strong';
      default: return '';
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    if (_isKeyEmpty) return;
    if (_isEncrypt && _keyController.text.length < 4) return;

    setState(() => _isLoading = true);
    try {
      await widget.onConfirm(_keyController.text);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _isEncrypt ? 'Encrypt Note' : 'Decrypt Note',
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isEncrypt
                ? 'Lock this note with a master key'
                : 'Enter your master key to unlock',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Master Key',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: () =>
                    setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),

          if (_isEncrypt) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _strengthWidth,
                minHeight: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_strengthColor),
              ),
            ),
            if (_keyController.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _strengthLabel,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: _strengthColor,
                ),
              ),
            ],
          ],

          if (_isEncrypt &&
              _keyController.text.isNotEmpty &&
              _keyController.text.length < 4) ...[
            const SizedBox(height: 8),
            Text(
              'Key must be at least 4 characters',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your key is never stored anywhere. If lost, the note cannot be recovered.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isKeyEmpty || _isLoading
                      ? null
                      : _handleConfirm,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEncrypt ? 'Encrypt' : 'Decrypt'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

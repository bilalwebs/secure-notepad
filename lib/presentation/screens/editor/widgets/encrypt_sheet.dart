import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/core/encryption/maze_card_cipher.dart';

class EncryptSheet extends StatefulWidget {
  final String plaintext;
  final bool isCurrentlyEncrypted;
  final String? currentCipherText;
  final void Function(String encrypted, String masterKey) onEncrypt;
  final void Function(String decrypted) onDecrypt;

  const EncryptSheet({
    super.key,
    required this.plaintext,
    required this.isCurrentlyEncrypted,
    this.currentCipherText,
    required this.onEncrypt,
    required this.onDecrypt,
  });

  @override
  State<EncryptSheet> createState() => _EncryptSheetState();
}

class _EncryptSheetState extends State<EncryptSheet> {
  final _keyController = TextEditingController();
  final _confirmKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _showConfirm = false;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    _confirmKeyController.dispose();
    super.dispose();
  }

  bool get _isKeyEmpty => _keyController.text.isEmpty;

  void _handleAction() {
    setState(() => _errorMessage = null);

    if (_isKeyEmpty) return;

    if (widget.isCurrentlyEncrypted) {
      _decrypt();
    } else {
      if (!_showConfirm) {
        setState(() => _showConfirm = true);
        return;
      }
      _encrypt();
    }
  }

  void _encrypt() {
    if (_keyController.text != _confirmKeyController.text) {
      setState(() => _errorMessage = 'Keys don\'t match');
      return;
    }

    try {
      final encrypted =
          MazeCardCipher.encrypt(widget.plaintext, _keyController.text);
      widget.onEncrypt(encrypted, _keyController.text);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note encrypted successfully'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Encryption failed: $e');
    }
  }

  void _decrypt() {
    final cipherText = widget.currentCipherText ?? widget.plaintext;
    try {
      final decrypted =
          MazeCardCipher.decrypt(cipherText, _keyController.text);
      widget.onDecrypt(decrypted);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note decrypted'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Incorrect master key. Try again.');
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
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ──
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
          const SizedBox(height: 16),

          // ── Header ──
          Row(
            children: [
              Icon(
                widget.isCurrentlyEncrypted
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                color: AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                widget.isCurrentlyEncrypted
                    ? 'Decrypt Note'
                    : 'Encrypt Note',
                style: GoogleFonts.sora(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.isCurrentlyEncrypted
                ? 'Enter your master key to decrypt this note.'
                : 'Protect your note with a master key.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // ── Master Key Input ──
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Master Key',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              errorText: _errorMessage,
            ),
          ),

          // ── Confirm Key (encrypt flow only) ──
          if (!widget.isCurrentlyEncrypted && _showConfirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmKeyController,
              obscureText: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm Master Key',
                prefixIcon: const Icon(Icons.key_rounded),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Info ──
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
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your key is never stored. You\'ll need it to decrypt.',
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

          // ── Buttons ──
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
                child: ElevatedButton.icon(
                  onPressed: _isKeyEmpty ? null : _handleAction,
                  icon: Icon(
                    widget.isCurrentlyEncrypted
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    size: 18,
                  ),
                  label: Text(
                    widget.isCurrentlyEncrypted
                        ? 'Decrypt'
                        : (_showConfirm ? 'Encrypt' : 'Continue'),
                  ),
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

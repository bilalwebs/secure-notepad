import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Maze-Card Cipher — hex encoding + multi-round deterministic
/// permutation cipher.
///
/// SRS Section 7, 8.2, 10.3 compliant.
/// Master Key is NEVER persisted — lives only in RAM.
///
/// Encoding: each Unicode char → 4-digit hex → each hex digit
/// → a playing-card token (rank+suit). Space-delimited output.
class MazeCardCipher {
  static const _hexDigits = '0123456789abcdef';
  static const _ranks = [
    'A', '2', '3', '4', '5', '6', '7', '8', '9', 'T',
    'J', 'Q', 'K', 'X', 'Y', 'Z',
  ];
  static const _suits = ['\u2660', '\u2665', '\u2666', '\u2663'];

  // Forward map: hex digit → card token (e.g. 'a' → 'Q♥')
  static final Map<String, String> _enc = _buildEncMap();
  // Reverse map: card token → hex digit
  static final Map<String, String> _dec = _enc.map((k, v) => MapEntry(v, k));

  static Map<String, String> _buildEncMap() {
    final map = <String, String>{};
    for (int i = 0; i < 16; i++) {
      final hex = _hexDigits[i];
      final rank = _ranks[i % _ranks.length];
      final suit = _suits[i % _suits.length];
      map[hex] = '$rank$suit';
    }
    return map;
  }

  // ── Key derivation (SRS §8.2) ─────────────────────────────

  static ({int seed, int rounds}) _params(String key) {
    final sum = key.codeUnits.fold(0, (int a, int b) => a + b);
    final seed = sum % 99991;
    final rounds = 2 + (sum % 3); // 2, 3, or 4
    return (seed: seed, rounds: rounds);
  }

  // ── Deterministic Fisher-Yates shuffle ─────────────────────

  static List<String> _shuffle(List<String> list, int seed) {
    final rand = Random(seed);
    final out = List<String>.from(list);
    for (int i = out.length - 1; i > 0; i--) {
      final j = rand.nextInt(i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  /// Exact mathematical inverse of [_shuffle].
  static List<String> _unshuffle(List<String> list, int seed) {
    final rand = Random(seed);
    final swaps = <(int, int)>[];
    for (int i = list.length - 1; i > 0; i--) {
      swaps.add((i, rand.nextInt(i + 1)));
    }
    final out = List<String>.from(list);
    for (final (i, j) in swaps.reversed) {
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  // ── Public API ─────────────────────────────────────────────

  /// Encrypt [plaintext] with [masterKey].
  /// Returns space-delimited card tokens.
  static String encrypt(String plaintext, String masterKey) {
    if (plaintext.isEmpty) return '';
    final p = _params(masterKey);

    // Step 1: convert each char to 4-digit hex, then to card tokens
    final tokens = <String>[];
    for (final codeUnit in plaintext.codeUnits) {
      final hex = codeUnit.toRadixString(16).padLeft(4, '0');
      for (int i = 0; i < 4; i++) {
        tokens.add(_enc[hex[i]]!);
      }
    }

    // Step 2: N rounds of deterministic permutation
    var result = tokens;
    for (int r = 0; r < p.rounds; r++) {
      result = _shuffle(result, p.seed + r);
    }

    return result.join(' ');
  }

  /// Decrypt [ciphertext] (space-delimited card tokens) with [masterKey].
  static String decrypt(String ciphertext, String masterKey) {
    if (ciphertext.isEmpty) return '';
    final p = _params(masterKey);

    // Step 1: reverse N rounds of permutation
    var tokens = ciphertext.split(' ');
    for (int r = p.rounds - 1; r >= 0; r--) {
      tokens = _unshuffle(tokens, p.seed + r);
    }

    // Step 2: card tokens → hex digits → original chars
    final buffer = StringBuffer();
    for (int i = 0; i < tokens.length; i += 4) {
      if (i + 3 >= tokens.length) break;
      final hex = StringBuffer();
      for (int j = 0; j < 4; j++) {
        hex.write(_dec[tokens[i + j]] ?? '0');
      }
      final codeUnit = int.parse(hex.toString(), radix: 16);
      buffer.writeCharCode(codeUnit);
    }

    return buffer.toString();
  }

  /// Validate that [result] looks like real content.
  /// Checks for Delta JSON format first, then falls back to
  /// printable-text heuristic for legacy plain-text notes.
  static bool isValidDecryption(String result) {
    if (result.trim().isEmpty) return false;
    // Check if it's valid Delta JSON (starts with '[{')
    try {
      final parsed = jsonDecode(result);
      if (parsed is List && parsed.isNotEmpty) return true;
    } catch (_) {}
    // Fallback: check if mostly printable text
    final printable =
        result.codeUnits.where((c) => c >= 32 && c <= 126).length;
    return result.isNotEmpty && (printable / result.length) >= 0.75;
  }

  /// Self-test to verify encrypt/decrypt round-trip works correctly.
  static bool selfTest() {
    const testText = 'Hello World 123!';
    const testKey = 'testpassword';
    try {
      final cipher = encrypt(testText, testKey);
      final result = decrypt(cipher, testKey);
      final passed = result == testText;
      debugPrint(passed
          ? 'MazeCardCipher selfTest PASSED'
          : 'MazeCardCipher selfTest FAILED got: $result');
      return passed;
    } catch (e) {
      debugPrint('MazeCardCipher selfTest ERROR: $e');
      return false;
    }
  }
}

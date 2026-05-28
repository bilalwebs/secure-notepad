import 'dart:math';

/// Maze-Card Hybrid Cipher
///
/// A custom bijective substitution cipher that maps all 95 printable ASCII
/// characters (32–126) to card symbols. Key derivation uses ASCII sum of the
/// master key to seed a deterministic PRNG for Fisher-Yates shuffle.
class MazeCardCipher {
  // 95 printable ASCII chars (space through tilde)
  static const String _printableAscii =
      ' !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~';

  // Card symbol pool (4 suits × 13 ranks + 2 jokers = 54 symbols)
  // We use 95 symbols by combining card representations
  static const List<String> _suits = ['♠', '♥', '♦', '♣'];
  static const List<String> _ranks = [
    'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
  ];

  /// Generates the full 95-element card symbol pool.
  static List<String> _buildSymbolPool() {
    final pool = <String>[];
    // 4 suits × 13 ranks = 52 card symbols
    for (final suit in _suits) {
      for (final rank in _ranks) {
        pool.add('$rank$suit');
      }
    }
    // Add jokers and special symbols to reach 95
    pool.add('🃏');
    pool.add('🂠');
    // Additional symbols using colored variants to reach 95
    for (final suit in _suits) {
      pool.add('[$suit]');
    }
    // Pad with bracketed rank combos
    for (final rank in _ranks) {
      if (pool.length >= 95) break;
      pool.add('{$rank}');
    }
    // Final padding
    while (pool.length < 95) {
      pool.add('※${pool.length}');
    }
    return pool.sublist(0, 95);
  }

  /// Derives seed and rounds from the master key.
  /// ASCII sum → seed, rounds = (sum % 3) + 2 (gives 2–4).
  static (int seed, int rounds) _deriveKey(String masterKey) {
    int sum = 0;
    for (int i = 0; i < masterKey.length; i++) {
      sum += masterKey.codeUnitAt(i);
    }
    final seed = sum;
    final rounds = (sum % 3) + 2; // 2, 3, or 4 rounds
    return (seed, rounds);
  }

  /// Seeded Fisher-Yates shuffle.
  static List<String> _shuffle(List<String> list, int seed) {
    final result = List<String>.from(list);
    final rng = Random(seed);
    for (int i = result.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  /// Builds the encryption mapping for a given round.
  static Map<String, String> _buildMapping(int seed, int round) {
    final symbols = _buildSymbolPool();
    final shuffled = _shuffle(symbols, seed + round * 1000);

    final mapping = <String, String>{};
    for (int i = 0; i < _printableAscii.length; i++) {
      mapping[_printableAscii[i]] = shuffled[i];
    }
    return mapping;
  }

  /// Builds the reverse (decryption) mapping.
  static Map<String, String> _buildReverseMapping(int seed, int round) {
    final symbols = _buildSymbolPool();
    final shuffled = _shuffle(symbols, seed + round * 1000);

    final mapping = <String, String>{};
    for (int i = 0; i < _printableAscii.length; i++) {
      mapping[shuffled[i]] = _printableAscii[i];
    }
    return mapping;
  }

  /// Encrypts plaintext using the Maze-Card cipher.
  ///
  /// Applies multiple rounds of substitution. Each round uses a different
  /// mapping derived from the same master key but with round-specific seed.
  static String encrypt(String plaintext, String masterKey) {
    if (masterKey.isEmpty) throw ArgumentError('Master key cannot be empty');
    if (plaintext.isEmpty) return '';

    final (seed, rounds) = _deriveKey(masterKey);

    String result = plaintext;
    for (int round = 0; round < rounds; round++) {
      final mapping = _buildMapping(seed, round);
      final buffer = StringBuffer();
      for (int i = 0; i < result.length; i++) {
        final char = result[i];
        if (mapping.containsKey(char)) {
          buffer.write(mapping[char]);
        } else {
          // Non-printable chars pass through unchanged
          buffer.write(char);
        }
      }
      result = buffer.toString();
    }

    return result;
  }

  /// Decrypts ciphertext using the Maze-Card cipher.
  ///
  /// Reverses multiple rounds of substitution in reverse order.
  static String decrypt(String ciphertext, String masterKey) {
    if (masterKey.isEmpty) throw ArgumentError('Master key cannot be empty');
    if (ciphertext.isEmpty) return '';

    final (seed, rounds) = _deriveKey(masterKey);

    String result = ciphertext;
    for (int round = rounds - 1; round >= 0; round--) {
      final mapping = _buildReverseMapping(seed, round);
      final buffer = StringBuffer();
      // Each card symbol is multi-char; we need to parse them
      int i = 0;
      while (i < result.length) {
        bool matched = false;
        // Try matching longest symbols first (bracketed ones are longer)
        for (int len = 5; len >= 1; len--) {
          if (i + len <= result.length) {
            final substr = result.substring(i, i + len);
            if (mapping.containsKey(substr)) {
              buffer.write(mapping[substr]);
              i += len;
              matched = true;
              break;
            }
          }
        }
        if (!matched) {
          buffer.write(result[i]);
          i++;
        }
      }
      result = buffer.toString();
    }

    return result;
  }

  /// Returns a preview of what encrypted text looks like (first 50 chars).
  static String preview(String plaintext, String masterKey) {
    final encrypted = encrypt(plaintext, masterKey);
    if (encrypted.length <= 50) return encrypted;
    return '${encrypted.substring(0, 50)}...';
  }
}

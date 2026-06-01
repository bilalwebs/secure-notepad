import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:secure_notepad/core/encryption/maze_card_cipher.dart';
import 'package:secure_notepad/core/services/voice_service.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/ai_provider.dart';
import 'package:secure_notepad/presentation/providers/notes_provider.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  final String? folderId;

  const NoteEditorScreen({super.key, this.noteId, this.folderId});

  @override
  ConsumerState<NoteEditorScreen> createState() =>
      _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  // ── Controllers ─────────────────────────────────────────────
  late QuillController _quill;
  final _titleCtrl = TextEditingController();
  final _editorNode = FocusNode();
  final _scrollCtrl = ScrollController();
  final _keyController = TextEditingController();

  // ── Note state ──────────────────────────────────────────────
  String? _noteId;
  String? _folderId;
  bool _isPinned = false;
  bool _isEncrypted = false;

  // ── Encryption state ────────────────────────────────────────
  String? _masterKey;
  bool _isDecrypted = false;
  String _storedCipherText = '';
  bool _isLoadingNote = true;
  String? _keyError;
  bool _obscureKey = true;

  // ── Save tracking ───────────────────────────────────────────
  bool _isSaving = false;
  bool _saveError = false;
  bool _showSavedTick = false;
  DateTime? _lastSaved;

  Timer? _autoSaveTimer;

  // ── Voice state ─────────────────────────────────────────────
  bool _isListening = false;

  // ── AI Panel state ──────────────────────────────────────────
  bool _showAIPanel = false;
  String? _activeAIAction;
  String? _aiResult;
  bool _aiLoading = false;
  String _aiStreamBuffer = '';

  // ── Lifecycle ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _folderId = widget.folderId;
    _quill = QuillController.basic();

    if (_noteId != null) {
      _loadExistingNote().then((_) {
        if (_isEncrypted && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showUnlockDialog();
          });
        }
      });
    } else {
      _isLoadingNote = false;
      _isDecrypted = true;
    }

    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _saveNote(),
    );
  }

  @override
  void dispose() {
    VoiceService.stopListening();
    _masterKey = null;
    _autoSaveTimer?.cancel();
    _quill.dispose();
    _titleCtrl.dispose();
    _keyController.dispose();
    _editorNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Load existing note ──────────────────────────────────────

  Future<void> _loadExistingNote() async {
    try {
      final repo = ref.read(notesRepositoryProvider);
      final snap = await repo.getNote(_noteId!);

      if (!snap.exists || !mounted) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final data = snap.data() as Map<String, dynamic>;

      _titleCtrl.text = data['title'] ?? '';
      _isPinned = data['isPinned'] ?? false;
      _folderId = data['folderId'];
      _isEncrypted = data['isEncrypted'] ?? false;
      _storedCipherText = data['cipherText'] ?? '';

      if (_isEncrypted && _storedCipherText.isNotEmpty) {
        setState(() => _isLoadingNote = false);
      } else {
        _isDecrypted = true;
        final raw = data['content'] ?? '';
        if (raw.isNotEmpty) {
          try {
            _quill = QuillController(
              document: Document.fromJson(jsonDecode(raw) as List),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (_) {
            _quill = QuillController(
              document: Document()..insert(0, raw),
              selection: const TextSelection.collapsed(offset: 0),
            );
          }
        }
        setState(() => _isLoadingNote = false);
      }
    } catch (e) {
      debugPrint('Load note error: $e');
      if (mounted) {
        setState(() => _isLoadingNote = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load note: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  // ── Unlock dialog (for existing encrypted notes) ────────────

  void _showUnlockDialog() {
    _keyController.clear();
    _keyError = null;
    _obscureKey = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.lock, color: Color(0xFF2EC4A9)),
            const SizedBox(width: 8),
            const Text('Enter Master Key',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This note is encrypted.\nEnter your master key to view it.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyController,
                obscureText: _obscureKey,
                autofocus: true,
                onChanged: (_) =>
                    setDialogState(() => _keyError = null),
                onSubmitted: (_) => _attemptDecrypt(setDialogState),
                decoration: InputDecoration(
                  hintText: 'Master Key',
                  prefixIcon: const Icon(Icons.key,
                      color: Color(0xFF2EC4A9)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setDialogState(
                        () => _obscureKey = !_obscureKey),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF2EC4A9), width: 2),
                  ),
                ),
              ),
              if (_keyError != null) ...[
                const SizedBox(height: 8),
                Text(_keyError!,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _keyController,
              builder: (_, val, __) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: val.text.isEmpty
                      ? Colors.grey
                      : const Color(0xFF2EC4A9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: val.text.isEmpty
                    ? null
                    : () => _attemptDecrypt(setDialogState),
                child: const Text('Unlock',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _attemptDecrypt(StateSetter setDialogState) {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    try {
      if (_storedCipherText.isEmpty) {
        setDialogState(() {
          _keyError = 'No encrypted content found.';
        });
        return;
      }

      final decrypted = MazeCardCipher.decrypt(_storedCipherText, key);

      String contentToLoad = decrypted;
      bool isValidJson = false;
      try {
        final parsed = jsonDecode(decrypted);
        if (parsed is List && parsed.isNotEmpty) {
          isValidJson = true;
        }
      } catch (_) {
        isValidJson = false;
      }

      if (!MazeCardCipher.isValidDecryption(decrypted)) {
        setDialogState(() {
          _keyError = 'Incorrect master key. Try again.';
        });
        _keyController.clear();
        return;
      }

      _masterKey = key;
      Navigator.of(context).pop();

      _quill.removeListener(_onChanged);
      _quill.dispose();

      try {
        if (isValidJson) {
          _quill = QuillController(
            document:
                Document.fromJson(jsonDecode(contentToLoad) as List),
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: false,
          );
        } else {
          _quill = QuillController(
            document: Document()..insert(0, contentToLoad),
            selection: const TextSelection.collapsed(offset: 0),
            readOnly: false,
          );
        }
      } catch (_) {
        _quill = QuillController(
          document: Document()..insert(0, contentToLoad),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: false,
        );
      }
      _quill.addListener(_onChanged);

      setState(() {
        _isDecrypted = true;
        _keyError = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note decrypted successfully'),
            backgroundColor: Color(0xFF2EC4A9),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setDialogState(() {
        _keyError = 'Incorrect master key. Try again.';
      });
      _keyController.clear();
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  // ── Set Master Key dialog (for new notes) ───────────────────

  void _showSetKeyDialog() {
    final keyCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Set Master Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: keyCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Master Key',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm Master Key',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: keyCtrl.text.trim().isEmpty ||
                      confirmCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      if (keyCtrl.text != confirmCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Keys do not match'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _masterKey = keyCtrl.text;
                        _isEncrypted = true;
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Master Key set. Future saves will be encrypted.'),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Set Key'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Remove encryption dialog ────────────────────────────────

  void _showRemoveEncryptionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Encryption?'),
        content: const Text(
          'This note will be saved as plain text. '
          'The Master Key will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _masterKey = null;
                _isEncrypted = false;
              });
              Navigator.pop(ctx);
              _saveNote();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Encryption removed'),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ── Voice to text ───────────────────────────────────────────

  Future<void> _toggleVoice() async {
    if (_isListening) {
      await VoiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final available = await VoiceService.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice recognition not available on this device/browser.\n'
              'Use Chrome or Edge browser for best support.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text('Listening... speak now'),
          ]),
          duration: const Duration(seconds: 30),
          backgroundColor: const Color(0xFF1B1B2F),
        ),
      );
    }

    await VoiceService.startListening(
      onResult: (text) {
        if (text.isNotEmpty && mounted) {
          final index = _quill.selection.baseOffset;
          final safeIndex = index < 0 ? 0 : index;
          _quill.document.insert(safeIndex, '$text ');
          _quill.updateSelection(
            TextSelection.collapsed(
                offset: safeIndex + text.length + 1),
            ChangeSource.local,
          );
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() => _isListening = false);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  String _plainText() => _quill.document.toPlainText().trim();

  String _getPlainText() => _plainText();

  int get _wordCount {
    final t = _plainText();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String get _readTime {
    final m = (_wordCount / 200).ceil();
    return m < 1 ? '< 1 min' : '$m min read';
  }

  // ── Save ────────────────────────────────────────────────────

  Future<void> _saveNote() async {
    if (_isSaving) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final plainText = _quill.document.toPlainText().trim();
    if (plainText.isEmpty && _titleCtrl.text.trim().isEmpty) return;

    if (mounted) setState(() { _isSaving = true; _saveError = false; });

    try {
      Map<String, dynamic> data;

      if (_masterKey != null &&
          _masterKey!.isNotEmpty &&
          plainText.isNotEmpty) {
        final deltaJson =
            jsonEncode(_quill.document.toDelta().toJson());
        final cipher =
            MazeCardCipher.encrypt(deltaJson, _masterKey!);
        data = {
          'title': _titleCtrl.text.trim().isEmpty
              ? 'Untitled'
              : _titleCtrl.text.trim(),
          'cipherText': cipher,
          'isEncrypted': true,
          'content': '',
          'plainPreview':
              plainText.substring(0, min(80, plainText.length)),
          'updatedAt': FieldValue.serverTimestamp(),
          'isPinned': _isPinned,
          'folderId': _folderId,
          'tags': <String>[],
        };
      } else {
        final deltaJson =
            jsonEncode(_quill.document.toDelta().toJson());
        data = {
          'title': _titleCtrl.text.trim().isEmpty
              ? 'Untitled'
              : _titleCtrl.text.trim(),
          'content': deltaJson,
          'isEncrypted': false,
          'cipherText': null,
          'plainPreview':
              plainText.substring(0, min(60, plainText.length)),
          'updatedAt': FieldValue.serverTimestamp(),
          'isPinned': _isPinned,
          'folderId': _folderId,
          'tags': <String>[],
        };
      }

      if (_noteId == null || _noteId!.isEmpty) {
        final refDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notes')
            .add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
        });
        _noteId = refDoc.id;
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notes')
            .doc(_noteId)
            .update(data);
      }

      _lastSaved = DateTime.now();
      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSavedTick = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() { _showSavedTick = false; });
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() { _isSaving = false; _saveError = true; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _saveNote),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSaving = false; _saveError = true; });
      }
    }
  }

  // ── Pin toggle ──────────────────────────────────────────────

  void _togglePin() {
    setState(() => _isPinned = !_isPinned);
    if (_noteId != null) {
      ref.read(notesRepositoryProvider).togglePinNote(_noteId!, _isPinned);
    }
  }

  // ── Delete ──────────────────────────────────────────────────

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'This note will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _noteId != null && mounted) {
      try {
        await ref.read(notesRepositoryProvider).deleteNote(_noteId!);
        if (mounted) context.go('/home');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  // ── Back ────────────────────────────────────────────────────

  Future<void> _onBack() async {
    await _saveNote();
    if (mounted) context.go('/home');
  }

  // ── Lock icon logic ─────────────────────────────────────────

  Widget _buildLockIcon() {
    if (!_isEncrypted && _masterKey == null) {
      return IconButton(
        icon: const Icon(Icons.lock_open, size: 22),
        color: Colors.grey,
        tooltip: 'Set Master Key',
        onPressed: _showSetKeyDialog,
      );
    }
    if (!_isEncrypted && _masterKey != null) {
      return IconButton(
        icon: const Icon(Icons.lock, size: 22),
        color: AppTheme.primary,
        tooltip: 'Change Master Key',
        onPressed: _showSetKeyDialog,
      );
    }
    if (_isEncrypted && _isDecrypted) {
      return IconButton(
        icon: const Icon(Icons.lock_open, size: 22),
        color: AppTheme.primary,
        tooltip: 'Remove encryption',
        onPressed: _showRemoveEncryptionDialog,
      );
    }
    return IconButton(
      icon: const Icon(Icons.lock, size: 22),
      color: Colors.grey,
      onPressed: null,
    );
  }

  // ── AI Panel ────────────────────────────────────────────────

  Future<void> _runAIAction(String action) async {
    if (_isEncrypted && !_isDecrypted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Decrypt note first to use AI'),
          backgroundColor: Colors.orange));
      return;
    }

    final plain = _getPlainText();
    if (plain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first')));
      return;
    }

    final ai = ref.read(aiServiceProvider);
    if (!ai.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI not configured. Add API key to .env'),
          backgroundColor: Colors.orange));
      return;
    }

    setState(() {
      _activeAIAction = action;
      _aiLoading = true;
      _aiResult = null;
      _aiStreamBuffer = '';
    });

    try {
      String result = '';
      await for (final chunk in ai.chatStream([], _buildPrompt(action, plain))) {
        result += chunk;
        if (mounted) {
          setState(() => _aiStreamBuffer = result);
        }
      }
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiResult = result.trim();
          _aiStreamBuffer = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiResult = 'Error: $e';
        });
      }
    }
  }

  String _buildPrompt(String action, String text) {
    switch (action) {
      case 'summarize':
        return 'Summarize in 2-3 sentences. Return ONLY summary:\n\n$text';
      case 'grammar':
        return 'Fix grammar and spelling. Return ONLY corrected text:\n\n$text';
      case 'expand':
        return 'Expand this into a detailed paragraph:\n\n$text';
      case 'shorten':
        return 'Shorten keeping all key points:\n\n$text';
      case 'tags':
        return 'Generate 5 tags. Return ONLY comma-separated list:\n\n$text';
      default:
        return text;
    }
  }

  void _applyAIResult(String result) {
    if (result.isEmpty) return;
    if (_activeAIAction == 'grammar' ||
        _activeAIAction == 'shorten') {
      final newCtrl = QuillController(
        document: Document()..insert(0, result),
        selection: const TextSelection.collapsed(offset: 0),
      );
      newCtrl.addListener(_onChanged);
      setState(() {
        _quill.removeListener(_onChanged);
        _quill.dispose();
        _quill = newCtrl;
        _showAIPanel = false;
        _aiResult = null;
      });
    } else {
      final len = _quill.document.length;
      _quill.document.insert(len - 1, '\n\n$result');
      setState(() {
        _showAIPanel = false;
        _aiResult = null;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Applied to note'),
        backgroundColor: Color(0xFF2EC4A9),
        duration: Duration(seconds: 1)));
  }

  Widget _buildAIPanelHeader() {
    final ai = ref.read(aiServiceProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              color: Color(0xFF2EC4A9), size: 18),
          const SizedBox(width: 8),
          Text('AI Assistant',
              style: GoogleFonts.sora(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('· ${ai.providerName}',
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: Colors.grey[500])),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.open_in_full, size: 14),
            label: Text('Full Chat',
                style: GoogleFonts.dmSans(fontSize: 12)),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2EC4A9)),
            onPressed: () {
              final plain = _getPlainText();
              context.push('/ai-chat', extra: {'noteContent': plain});
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: () => setState(() => _showAIPanel = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _AIActionChip(
            icon: '📝',
            label: 'Summarize',
            onTap: () => _runAIAction('summarize'),
            isActive: _activeAIAction == 'summarize',
          ),
          _AIActionChip(
            icon: '✏️',
            label: 'Fix Grammar',
            onTap: () => _runAIAction('grammar'),
            isActive: _activeAIAction == 'grammar',
          ),
          _AIActionChip(
            icon: '💡',
            label: 'Expand',
            onTap: () => _runAIAction('expand'),
            isActive: _activeAIAction == 'expand',
          ),
          _AIActionChip(
            icon: '✂️',
            label: 'Shorten',
            onTap: () => _runAIAction('shorten'),
            isActive: _activeAIAction == 'shorten',
          ),
          _AIActionChip(
            icon: '🏷️',
            label: 'Tags',
            onTap: () => _runAIAction('tags'),
            isActive: _activeAIAction == 'tags',
          ),
        ],
      ),
    );
  }

  Widget _buildAIResult() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_aiLoading) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBar(width: double.infinity),
            const SizedBox(height: 8),
            _ShimmerBar(width: 250),
            const SizedBox(height: 8),
            _ShimmerBar(width: 200),
            if (_aiStreamBuffer.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _aiStreamBuffer,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_aiResult == null) {
      return Center(
        child: Text(
          'Select an action above to get AI help',
          style: GoogleFonts.dmSans(
            fontSize: 13, color: Colors.grey[500]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2EC4A9).withValues(alpha: 0.06),
              border: const Border(
                left: BorderSide(
                  color: Color(0xFF2EC4A9), width: 3)),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: SelectableText(
              _aiResult!,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Apply to note',
                    style: GoogleFonts.dmSans(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2EC4A9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () => _applyAIResult(_aiResult!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text('Retry',
                    style: GoogleFonts.dmSans(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2EC4A9),
                    side: const BorderSide(
                      color: Color(0xFF2EC4A9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  ),
                  onPressed: () => _runAIAction(_activeAIAction!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Format relative time ────────────────────────────────────

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textLight : AppTheme.textDark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    if (_isLoadingNote) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_isEncrypted && !_isDecrypted) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor:
              isDark ? const Color(0xFF1A1A1A) : Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Note is encrypted',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your Master Key to view and edit',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showUnlockDialog,
                icon: const Icon(Icons.vpn_key_rounded),
                label: const Text('Enter Master Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1A1A1A) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _onBack,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: _isPinned ? AppTheme.primary : Colors.grey,
              size: 22,
            ),
            onPressed: _togglePin,
            tooltip: _isPinned ? 'Unpin' : 'Pin',
          ),
          _buildLockIcon(),
          if (_noteId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              color: AppTheme.error,
              onPressed: _deleteNote,
              tooltip: 'Delete note',
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded, size: 24),
            color: AppTheme.primary,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              await _saveNote();
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Note saved'),
                  backgroundColor: AppTheme.primary,
                  duration: Duration(seconds: 1),
                ),
              );
              await Future.delayed(const Duration(milliseconds: 800));
              if (mounted) router.go('/home');
            },
            tooltip: 'Save and go back',
          ),
        ],
      ),
      body: Column(
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.next,
            ),
          ),

          // Quill toolbar
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: QuillSimpleToolbar(
                    controller: _quill,
                    config: QuillSimpleToolbarConfig(
                      toolbarSize: 44,
                      showDividers: true,
                      showFontFamily: false,
                      showFontSize: false,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showStrikeThrough: false,
                      showListNumbers: true,
                      showListBullets: true,
                      showListCheck: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: false,
                      showLink: true,
                      showUndo: true,
                      showRedo: true,
                      showSearchButton: false,
                      showClearFormat: true,
                      multiRowsDisplay: false,
                    ),
                  ),
                ),
                // Mic button
                IconButton(
                  iconSize: 22,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isListening
                        ? const Icon(Icons.mic,
                            key: ValueKey('on'),
                            color: Color(0xFF2EC4A9))
                        : Icon(Icons.mic_none,
                            key: ValueKey('off'),
                            color: Colors.grey[600]),
                  ),
                  onPressed: _toggleVoice,
                  tooltip:
                      _isListening ? 'Stop recording' : 'Voice to text',
                ),
                // AI sparkle button
                IconButton(
                  iconSize: 20,
                  icon: Icon(
                    Icons.auto_awesome,
                    color: _showAIPanel
                        ? const Color(0xFF2EC4A9)
                        : Colors.grey[600],
                  ),
                  onPressed: () =>
                      setState(() => _showAIPanel = !_showAIPanel),
                  tooltip: 'AI Assistant',
                ),
              ],
            ),
          ),

          // Editor
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  FocusScope.of(context).requestFocus(_editorNode),
              child: QuillEditor(
                controller: _quill,
                focusNode: _editorNode,
                scrollController: _scrollCtrl,
                config: QuillEditorConfig(
                  placeholder: 'Start writing...',
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  scrollable: true,
                  autoFocus: false,
                  expands: false,
                  enableInteractiveSelection: true,
                ),
              ),
            ),
          ),

          // AI Panel — fixed height AnimatedContainer
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _showAIPanel ? 300 : 0,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF2EC4A9).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: _showAIPanel
                ? SizedBox(
                    height: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAIPanelHeader(),
                        _buildActionChips(),
                        const SizedBox(height: 6),
                        Expanded(child: _buildAIResult()),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Status bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A1A)
                  : AppTheme.surfaceLight,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_wordCount words  ·  $_readTime',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: Colors.grey[500]),
                ),
                if (_isSaving)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('Saving...',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: Colors.grey[400])),
                    ],
                  )
                else if (_saveError)
                  GestureDetector(
                    onTap: _saveNote,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 13, color: AppTheme.error),
                        const SizedBox(width: 4),
                        Text('Save failed - Retry',
                            style: GoogleFonts.dmSans(
                                fontSize: 12, color: AppTheme.error)),
                      ],
                    ),
                  )
                else if (_showSavedTick)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check,
                          size: 13, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text('Saved',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: AppTheme.primary)),
                    ],
                  )
                else if (_lastSaved != null)
                  Text(
                    'Saved ${_ago(_lastSaved!)}',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: Colors.grey[400]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────

class _AIActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _AIActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2EC4A9)
                : const Color(0xFF2EC4A9).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF2EC4A9),
              width: isActive ? 0 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? Colors.white
                      : const Color(0xFF2EC4A9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  const _ShimmerBar({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

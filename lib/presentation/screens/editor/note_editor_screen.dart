import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:secure_notepad/core/encryption/maze_card_cipher.dart';
import 'package:secure_notepad/presentation/screens/editor/widgets/ai_assist_sheet.dart';
import 'package:secure_notepad/presentation/screens/editor/widgets/encrypt_sheet.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final String? noteId;
  const NoteEditorScreen({super.key, this.noteId});

  @override
  ConsumerState<NoteEditorScreen> createState() =>
      _NoteEditorScreenState();
}

class _NoteEditorScreenState
    extends ConsumerState<NoteEditorScreen> {

  late QuillController _quill;
  final _titleCtrl  = TextEditingController();
  final _editorNode = FocusNode();
  final _scrollCtrl = ScrollController();

  String? _noteId;
  bool   _isEncrypted = false;
  String? _cipherText;
  bool   _isPinned    = false;
  String? _folderId;

  bool      _isSaving       = false;
  bool      _saveError      = false;
  bool      _showSavedTick  = false;
  String?   _lastContent;
  String?   _lastTitle;
  DateTime? _lastSaved;

  bool _isListening = false;

  Timer? _autoSaveTimer;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _noteId = widget.noteId;
    _quill  = QuillController.basic();

    if (_noteId != null) {
      _loadNote();
    }

    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 4), (_) => _saveNote());

    _quill.addListener(_onChanged);
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () { if (mounted) setState(() {}); },
    );
  }

  Future<void> _loadNote() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(_noteId)
          .get();

      if (!snap.exists || !mounted) return;
      final d = snap.data()!;

      _titleCtrl.text = d['title'] ?? '';
      _isEncrypted    = d['isEncrypted'] ?? false;
      _cipherText     = d['cipherText'];
      _isPinned       = d['isPinned']    ?? false;
      _folderId       = d['folderId'];

      QuillController ctrl;
      if (_isEncrypted && _cipherText != null) {
        ctrl = QuillController(
          document: Document()..insert(0, _cipherText!),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } else {
        final raw = d['content'] ?? '';
        if (raw.isNotEmpty) {
          try {
            ctrl = QuillController(
              document: Document.fromJson(jsonDecode(raw)),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } catch (_) {
            ctrl = QuillController(
              document: Document()..insert(0, raw),
              selection: const TextSelection.collapsed(offset: 0),
            );
          }
        } else {
          ctrl = QuillController.basic();
        }
      }

      _quill.removeListener(_onChanged);
      _quill.dispose();
      _quill = ctrl;
      _quill.addListener(_onChanged);

      _lastContent = _contentJson();
      _lastTitle   = _titleCtrl.text;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Load note error: $e');
    }
  }

  String _contentJson() =>
      jsonEncode(_quill.document.toDelta().toJson());

  String _plainText() =>
      _quill.document.toPlainText().trim();

  int get _wordCount {
    final t = _plainText();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String get _readTime {
    final m = (_wordCount / 200).ceil();
    return m < 1 ? '< 1' : '$m';
  }

  Future<void> _saveNote() async {
    if (_isSaving)    return;
    if (_isEncrypted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final curContent = _contentJson();
    final curTitle   = _titleCtrl.text.trim();

    if (curContent == _lastContent && curTitle == _lastTitle) {
      if (_lastSaved != null && mounted) {
        setState(() { _showSavedTick = true; });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() { _showSavedTick = false; });
        });
      }
      return;
    }

    if (mounted) setState(() { _isSaving = true; _saveError = false; });

    try {
      final plain = _plainText();
      final data  = <String, dynamic>{
        'title':        curTitle.isEmpty ? 'Untitled' : curTitle,
        'content':      curContent,
        'plainPreview': plain.substring(0, min(80, plain.length)),
        'updatedAt':    FieldValue.serverTimestamp(),
        'isPinned':     _isPinned,
        'folderId':     _folderId,
        'isEncrypted':  false,
        'cipherText':   null,
      };

      if (_noteId == null || _noteId!.isEmpty) {
        final ref = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('notes')
            .add({
              ...data,
              'createdAt': FieldValue.serverTimestamp(),
              'tags':      <String>[],
            });
        _noteId = ref.id;
      } else {
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('notes').doc(_noteId)
            .update(data);
      }

      _lastContent = curContent;
      _lastTitle   = curTitle;
      _lastSaved   = DateTime.now();

      if (mounted) {
        setState(() { _isSaving = false; _showSavedTick = true; });
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
            onPressed: _saveNote,
          ),
        ));
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        setState(() { _isSaving = false; _saveError = true; });
      }
    }
  }

  void _onLockTap() {
    if (_isEncrypted) {
      _showDecryptSheet();
    } else {
      _showEncryptSheet();
    }
  }

  void _showEncryptSheet() {
    final plain = _plainText();
    if (plain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EncryptSheet(
        mode: 'encrypt',
        onConfirm: (key) async {
          Navigator.pop(context);
          await _doEncrypt(plain, key);
        },
      ),
    );
  }

  void _showDecryptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EncryptSheet(
        mode: 'decrypt',
        onConfirm: (key) async {
          Navigator.pop(context);
          await _doDecrypt(key);
        },
      ),
    );
  }

  Future<void> _doEncrypt(String plain, String key) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || _noteId == null) return;

      final cipher = MazeCardCipher.encrypt(plain, key);

      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('notes').doc(_noteId)
          .update({
        'cipherText':   cipher,
        'isEncrypted':  true,
        'plainPreview': plain.substring(0, min(80, plain.length)),
        'content':      '',
        'updatedAt':    FieldValue.serverTimestamp(),
      });

      final newCtrl = QuillController(
        document: Document()..insert(0, cipher),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      _quill.removeListener(_onChanged);
      _quill.dispose();
      _quill = newCtrl;

      setState(() {
        _isEncrypted = true;
        _cipherText  = cipher;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note encrypted successfully'),
            backgroundColor: Color(0xFF2EC4A9),
          ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encryption failed: $e')));
      }
    }
  }

  Future<void> _doDecrypt(String key) async {
    if (_cipherText == null || _cipherText!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No encrypted content found'),
          backgroundColor: Colors.orange,
        ));
      return;
    }
    try {
      final plain = MazeCardCipher.decrypt(_cipherText!, key);

      if (!MazeCardCipher.isValidDecryption(plain)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect master key. Try again.'),
            backgroundColor: Colors.red,
          ));
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || _noteId == null) return;

      final deltaJson = jsonEncode(
          (Document()..insert(0, plain)).toDelta().toJson());

      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('notes').doc(_noteId)
          .update({
        'cipherText':  null,
        'isEncrypted': false,
        'content':     deltaJson,
        'updatedAt':   FieldValue.serverTimestamp(),
      });

      final newCtrl = QuillController(
        document: Document()..insert(0, plain),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: false,
      );
      newCtrl.addListener(_onChanged);
      _quill.removeListener(_onChanged);
      _quill.dispose();
      _quill = newCtrl;

      _lastContent = _contentJson();

      setState(() {
        _isEncrypted = false;
        _cipherText  = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note decrypted successfully'),
            backgroundColor: Color(0xFF2EC4A9),
          ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect master key. Try again.'),
            backgroundColor: Colors.red,
          ));
      }
    }
  }

  void _showAIAssist() {
    if (_isEncrypted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Decrypt note first to use AI'),
          backgroundColor: Colors.orange,
        ));
      return;
    }
    final plain = _plainText();
    if (plain.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AIAssistSheet(
        noteContent: plain,
        onApply: (result) {
          final len = _quill.document.length;
          _quill.document.insert(len - 1, '\n\n$result');
        },
      ),
    );
  }

  Future<void> _deleteNote() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && _noteId != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('notes').doc(_noteId).delete();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _duplicateNote() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notes')
        .add({
      'title':       '${_titleCtrl.text} (Copy)',
      'content':     _contentJson(),
      'isEncrypted': false,
      'cipherText':  null,
      'isPinned':    false,
      'folderId':    _folderId,
      'tags':        <String>[],
      'createdAt':   FieldValue.serverTimestamp(),
      'updatedAt':   FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note duplicated'),
          backgroundColor: Color(0xFF2EC4A9),
        ));
    }
  }

  String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60)  return 'just now';
    if (d.inMinutes < 60)  return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? Colors.white70 : const Color(0xFF1B1B2F);
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _saveNote();
            if (mounted) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              color: _isPinned
                  ? const Color(0xFF2EC4A9) : Colors.grey,
              size: 22,
            ),
            onPressed: () {
              setState(() { _isPinned = !_isPinned; });
              _saveNote();
            },
            tooltip: _isPinned ? 'Unpin' : 'Pin',
          ),
          IconButton(
            icon: Icon(
              _isEncrypted ? Icons.lock : Icons.lock_open,
              color: _isEncrypted
                  ? const Color(0xFF2EC4A9) : Colors.grey,
              size: 22,
            ),
            onPressed: _onLockTap,
            tooltip: _isEncrypted
                ? 'Decrypt note' : 'Encrypt note',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete')    _deleteNote();
              if (v == 'duplicate') _duplicateNote();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.copy),
                  title: Text('Duplicate'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.delete_outline, color: Colors.red),
                  title: Text('Delete',
                    style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isEncrypted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 8, horizontal: 16),
              color: const Color(0xFF2EC4A9).withValues(alpha: 0.12),
              child: const Row(
                children: [
                  Icon(Icons.lock,
                      size: 15, color: Color(0xFF2EC4A9)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note is encrypted - tap lock to decrypt',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF085041),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
            child: TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
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
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(seconds: 2), _saveNote);
              },
            ),
          ),

          if (!_isEncrypted)
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.12)),
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
                  IconButton(
                    iconSize: 20,
                    icon: Icon(
                      _isListening
                          ? Icons.mic
                          : Icons.mic_none,
                      color: _isListening
                          ? const Color(0xFF2EC4A9)
                          : Colors.grey[600],
                    ),
                    onPressed: () {
                      setState(() {
                        _isListening = !_isListening;
                      });
                    },
                    tooltip: 'Voice to text',
                  ),
                  IconButton(
                    iconSize: 20,
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF2EC4A9),
                    ),
                    onPressed: _showAIAssist,
                    tooltip: 'AI Assist',
                  ),
                ],
              ),
            ),

          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context)
                  .requestFocus(_editorNode),
              child: QuillEditor(
                controller: _quill,
                focusNode: _editorNode,
                scrollController: _scrollCtrl,
                config: QuillEditorConfig(
                  placeholder: _isEncrypted
                      ? 'Encrypted - tap lock to decrypt'
                      : 'Start writing...',
                  padding: const EdgeInsets.fromLTRB(
                      20, 12, 20, 100),
                  scrollable: true,
                  autoFocus: false,
                  expands: false,
                  enableInteractiveSelection: true,
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF8F9FB),
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_wordCount words  |  $_readTime min read',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                if (_isSaving)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('Saving...',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400])),
                  ])
                else if (_saveError)
                  GestureDetector(
                    onTap: _saveNote,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      const Icon(Icons.error_outline,
                          size: 13, color: Colors.red),
                      const SizedBox(width: 4),
                      const Text('Save failed - Retry',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red)),
                    ]),
                  )
                else if (_showSavedTick)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check,
                        size: 13,
                        color: Color(0xFF2EC4A9)),
                    const SizedBox(width: 4),
                    const Text('Saved',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2EC4A9))),
                  ])
                else if (_lastSaved != null)
                  Text(
                    'Saved ${_ago(_lastSaved!)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _debounce?.cancel();
    _quill.removeListener(_onChanged);
    _quill.dispose();
    _titleCtrl.dispose();
    _editorNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

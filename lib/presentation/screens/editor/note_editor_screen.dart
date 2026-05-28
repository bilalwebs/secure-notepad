import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/core/encryption/maze_card_cipher.dart';
import 'package:secure_notepad/data/models/note_model.dart';
import 'package:secure_notepad/presentation/providers/notes_provider.dart';
import 'package:secure_notepad/presentation/screens/editor/widgets/ai_assist_sheet.dart';
import 'package:secure_notepad/presentation/screens/editor/widgets/encrypt_sheet.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteModel? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  final _bodyFocusNode = FocusNode();
  Timer? _autoSaveTimer;
  String? _noteId;
  bool _isEncrypted = false;
  String? _masterKey;
  String _originalPlainText = ''; // Stores the original plaintext when encrypted
  bool _isVoice = false;
  String? _folderId;
  List<String> _tags = [];
  bool _isPinned = false;
  String? _audioUrl;
  DateTime? _reminderAt;
  bool _hasChanges = false;
  int _wordCount = 0;

  // Toolbar active states
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;

  // Voice
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // Upload
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _noteId = widget.note?.id;
    _isEncrypted = widget.note?.isEncrypted ?? false;
    _isVoice = widget.note?.isVoice ?? false;
    _folderId = widget.note?.folderId;
    _tags = List.from(widget.note?.tags ?? []);
    _isPinned = widget.note?.isPinned ?? false;
    _audioUrl = widget.note?.audioUrl;
    _reminderAt = widget.note?.reminderAt;

    // FIX 4: If encrypted, show ciphertext in body (user must decrypt to read)
    if (_isEncrypted && widget.note != null) {
      _bodyController =
          TextEditingController(text: widget.note!.cipherText);
      _originalPlainText = widget.note!.plainPreview;
    } else {
      _bodyController =
          TextEditingController(text: widget.note?.plainPreview ?? '');
      _originalPlainText = widget.note?.plainPreview ?? '';
    }

    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
    _updateWordCount();

    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _autoSave(),
    );
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.removeListener(_onTextChanged);
    _bodyController.removeListener(_onTextChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _hasChanges = true;
    _updateWordCount();
  }

  void _updateWordCount() {
    final text = _bodyController.text.trim();
    _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    if (mounted) setState(() {});
  }

  int get _readTime => _wordCount == 0 ? 0 : (_wordCount / 200).ceil();

  // ── Auto-save ──
  Future<void> _autoSave() async {
    if (!_hasChanges) return;
    if (_titleController.text.isEmpty && _bodyController.text.isEmpty) return;

    final now = DateTime.now();
    final currentBody = _bodyController.text;

    // Determine what to save
    String cipherTextToSave;
    String plainPreviewToSave;

    if (_isEncrypted && _masterKey != null) {
      // User is editing plaintext with encryption enabled → encrypt for storage
      cipherTextToSave =
          MazeCardCipher.encrypt(currentBody, _masterKey!);
      plainPreviewToSave = currentBody; // Store plaintext as preview
    } else if (_isEncrypted) {
      // Body shows ciphertext, user hasn't decrypted yet
      cipherTextToSave = currentBody;
      plainPreviewToSave = _originalPlainText;
    } else {
      // Not encrypted, store plaintext
      cipherTextToSave = currentBody;
      plainPreviewToSave = currentBody;
    }

    final note = NoteModel(
      id: _noteId ?? '',
      title: _titleController.text.trim(),
      cipherText: cipherTextToSave,
      plainPreview: plainPreviewToSave,
      isEncrypted: _isEncrypted,
      isVoice: _isVoice,
      audioUrl: _audioUrl,
      folderId: _folderId,
      tags: _tags,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      reminderAt: _reminderAt,
      isPinned: _isPinned,
    );

    try {
      if (_noteId == null) {
        _noteId = await ref.read(notesProvider.notifier).createNote(note);
      } else {
        await ref.read(notesProvider.notifier).updateNote(note);
      }
      _hasChanges = false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  // ── FIX 4: Encrypt/Decrypt ──
  void _showEncryptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EncryptSheet(
        plaintext: _isEncrypted ? _originalPlainText : _bodyController.text,
        isCurrentlyEncrypted: _isEncrypted,
        currentCipherText: _isEncrypted ? _bodyController.text : null,
        onEncrypt: (encrypted, masterKey) {
          setState(() {
            _masterKey = masterKey;
            _isEncrypted = true;
            _originalPlainText = _bodyController.text;
            // Keep plaintext visible in editor for readability
            _hasChanges = true;
          });
        },
        onDecrypt: (decrypted) {
          setState(() {
            _bodyController.text = decrypted;
            _isEncrypted = false;
            _masterKey = null;
            _originalPlainText = decrypted;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  // ── AI Assist ──
  void _showAiAssistSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiAssistSheet(
        noteContent: _bodyController.text,
        onResult: (result) {
          setState(() {
            _bodyController.text = result;
            _hasChanges = true;
          });
        },
      ),
    );
  }

  // ── FIX 3: Toolbar Actions ──
  void _toggleBold() {
    setState(() => _isBold = !_isBold);
    _wrapSelection('**', '**');
  }

  void _toggleItalic() {
    setState(() => _isItalic = !_isItalic);
    _wrapSelection('_', '_');
  }

  void _toggleUnderline() {
    setState(() => _isUnderline = !_isUnderline);
    _wrapSelection('<u>', '</u>');
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (!selection.isValid) {
      _insertAtCursor(prefix + suffix);
      return;
    }

    final selected = text.substring(selection.start, selection.end);
    if (selected.isEmpty) {
      final cursorPos = selection.start;
      final newText = text.substring(0, cursorPos) +
          prefix +
          suffix +
          text.substring(cursorPos);
      _bodyController.text = newText;
      _bodyController.selection =
          TextSelection.collapsed(offset: cursorPos + prefix.length);
    } else {
      final newText = text.substring(0, selection.start) +
          prefix +
          selected +
          suffix +
          text.substring(selection.end);
      _bodyController.text = newText;
      _bodyController.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.end + prefix.length,
      );
    }
    _hasChanges = true;
  }

  void _insertBulletList() {
    _insertAtLineStart('• ');
  }

  void _insertNumberedList() {
    // Find the current line number
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    int lineStart = selection.isValid ? selection.start : text.length;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // Count previous numbered lines
    final beforeLines = text.substring(0, lineStart).split('\n');
    int num = 1;
    for (int i = beforeLines.length - 1; i >= 0; i--) {
      if (RegExp(r'^\d+\. ').hasMatch(beforeLines[i])) {
        final match = RegExp(r'^(\d+)\. ').firstMatch(beforeLines[i]);
        if (match != null) {
          num = int.parse(match.group(1)!) + 1;
          break;
        }
      } else if (beforeLines[i].trim().isNotEmpty) {
        break;
      }
    }

    _insertAtLineStart('$num. ');
  }

  void _insertAtLineStart(String prefix) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (!selection.isValid) {
      _insertAtCursor(prefix);
      return;
    }

    int lineStart = selection.start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    _bodyController.text = newText;
    _bodyController.selection =
        TextSelection.collapsed(offset: selection.start + prefix.length);
    _hasChanges = true;
  }

  void _insertLink() {
    final urlController = TextEditingController();
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Insert Link',
            style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Display Text',
                prefixIcon: Icon(Icons.text_fields_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                prefixIcon: Icon(Icons.link_rounded),
                hintText: 'https://example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final display = textController.text.trim();
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                _insertAtCursor('[$display]($url)');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndInsertImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final ref = FirebaseStorage.instance
          .ref()
          .child('notes_images')
          .child(user.uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final bytes = await image.readAsBytes();
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      _insertAtCursor('\n![image]($url)\n');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech error: ${error.errorMsg}')),
          );
        }
      },
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      return;
    }

    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _insertAtCursor(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
    );
  }

  void _insertAtCursor(String text) {
    final current = _bodyController.text;
    final selection = _bodyController.selection;
    final offset = selection.isValid ? selection.start : current.length;
    final newText =
        current.substring(0, offset) + text + current.substring(offset);
    _bodyController.text = newText;
    _bodyController.selection =
        TextSelection.collapsed(offset: offset + text.length);
    _hasChanges = true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? AppTheme.textLight : AppTheme.textDark;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () async {
            await _autoSave();
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        actions: [
          // Pin
          IconButton(
            onPressed: () {
              setState(() => _isPinned = !_isPinned);
              _hasChanges = true;
            },
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 20,
              color: _isPinned ? AppTheme.primary : null,
            ),
            tooltip: _isPinned ? 'Unpin' : 'Pin',
          ),
          // Lock (Encrypt/Decrypt)
          IconButton(
            onPressed: _showEncryptSheet,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isEncrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
                key: ValueKey(_isEncrypted),
                size: 20,
                color: _isEncrypted ? AppTheme.primary : null,
              ),
            ),
            tooltip: _isEncrypted ? 'Decrypt Note' : 'Encrypt Note',
          ),
          // More
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'tags':
                  _showTagDialog();
                  break;
                case 'reminder':
                  _showReminderPicker();
                  break;
                case 'delete':
                  _deleteNote();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'tags', child: Text('Manage Tags')),
              const PopupMenuItem(
                  value: 'reminder', child: Text('Set Reminder')),
              const PopupMenuItem(
                value: 'delete',
                child:
                    Text('Delete', style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Toolbar ──
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 0.5,
                ),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _toolbarBtn(Icons.format_bold_rounded, 'Bold', _toggleBold,
                    isActive: _isBold),
                _toolbarBtn(Icons.format_italic_rounded, 'Italic',
                    _toggleItalic,
                    isActive: _isItalic),
                _toolbarBtn(Icons.format_underline_rounded, 'Underline',
                    _toggleUnderline,
                    isActive: _isUnderline),
                _toolbarDivider(),
                _toolbarBtn(Icons.format_list_bulleted_rounded, 'Bullet List',
                    _insertBulletList),
                _toolbarBtn(Icons.format_list_numbered_rounded,
                    'Numbered List', _insertNumberedList),
                _toolbarDivider(),
                _toolbarBtn(Icons.link_rounded, 'Insert Link', _insertLink),
                _toolbarBtn(Icons.image_outlined, 'Insert Image',
                    _pickAndInsertImage,
                    isLoading: _isUploadingImage),
                _toolbarBtn(
                  _isListening ? Icons.mic_rounded : Icons.mic_outlined,
                  'Voice Input',
                  _toggleVoiceInput,
                  isActive: _isListening,
                  color: Colors.red,
                ),
                _toolbarDivider(),
                _toolbarBtn(Icons.auto_awesome_rounded, 'AI Assist',
                    _showAiAssistSheet,
                    color: AppTheme.primary),
              ],
            ),
          ),

          // ── Tags ──
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tags
                      .map((tag) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text('#$tag',
                                  style: GoogleFonts.dmSans(fontSize: 11)),
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.1),
                              labelStyle:
                                  const TextStyle(color: AppTheme.primary),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              deleteIcon:
                                  const Icon(Icons.close, size: 14),
                              deleteIconColor: AppTheme.primary,
                              onDeleted: () {
                                setState(() {
                                  _tags.remove(tag);
                                  _hasChanges = true;
                                });
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),

          // ── Encrypted badge ──
          if (_isEncrypted)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      _masterKey != null
                          ? 'Editing encrypted note'
                          : 'Encrypted — tap lock to decrypt',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Title ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.sora(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: GoogleFonts.sora(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
            ),
          ),

          // ── Body ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TextField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                readOnly: _isEncrypted && _masterKey == null,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: _isEncrypted && _masterKey == null
                      ? (isDark ? Colors.grey.shade500 : Colors.grey.shade600)
                      : textColor,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: _isEncrypted && _masterKey == null
                      ? 'Tap the lock icon to decrypt and edit...'
                      : 'Start writing...',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 16,
                    color:
                        isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Footer ──
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Text(
                '$_wordCount words',
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400),
              ),
              const SizedBox(width: 16),
              Text(
                '$_readTime min read',
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400),
              ),
              const Spacer(),
              if (_hasChanges)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              else
                Icon(Icons.check_rounded, size: 16, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Toolbar Button ──
  Widget _toolbarBtn(IconData icon, String tooltip, VoidCallback onPressed,
      {Color? color, bool isActive = false, bool isLoading = false}) {
    final activeColor = color ?? AppTheme.primary;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: activeColor),
                )
              : Icon(icon,
                  size: 20,
                  color: isActive ? activeColor : Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _toolbarDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: Colors.grey.shade300,
    );
  }

  // ── Dialogs ──
  void _showTagDialog() {
    final tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Tags',
            style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(
            hintText: 'Enter tag (comma separated)',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newTags = tagController.text
                  .split(',')
                  .map((t) => t.trim().toLowerCase())
                  .where((t) => t.isNotEmpty)
                  .toList();
              setState(() {
                _tags.addAll(newTags);
                _hasChanges = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showReminderPicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _reminderAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _hasChanges = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder set')),
      );
    }
  }

  void _deleteNote() {
    if (_noteId != null) {
      ref
          .read(notesProvider.notifier)
          .deleteNote(_noteId!, folderId: _folderId);
    }
    Navigator.pop(context);
  }
}

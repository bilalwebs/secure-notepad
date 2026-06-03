import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/data/services/ai_service.dart';
import 'package:secure_notepad/presentation/providers/ai_provider.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  final String? initialContext;
  const AIChatScreen({super.key, this.initialContext});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isStreaming = false;
  String _streamingBuffer = '';
  bool _welcomeAdded = false;
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get _trimmedHistory => _messages.length > 20
      ? _messages.sublist(_messages.length - 20)
      : [..._messages];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_welcomeAdded && mounted) {
        _welcomeAdded = true;
        // Don't clear messages here - let the guard in add functions handle it
        if (widget.initialContext != null &&
            widget.initialContext!.isNotEmpty) {
          _addWelcomeWithContext();
        } else {
          _addWelcomeMessage();
        }
      }
    });
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
  }

  void _replaceLastMessage(ChatMessage message) {
    if (_messages.isEmpty) return;
    setState(() {
      _messages[_messages.length - 1] = message;
    });
  }

  void _addWelcomeMessage() {
    if (_messages.isNotEmpty) return;
    _addMessage(ChatMessage(
      role: 'assistant',
      content: 'Hello! I\'m SecureNote AI, your intelligent note '
          'assistant crafted by Bilal Hussain. I can help you '
          'summarize notes, fix grammar, expand ideas, and '
          'create notes or folders. How can I help today?',
      timestamp: DateTime.now(),
    ));
  }

  void _addWelcomeWithContext() {
    if (_messages.isNotEmpty) return;
    _addMessage(ChatMessage(
      role: 'assistant',
      content: 'Hello! I\'m SecureNote AI by Bilal Hussain. '
          'I can see you\'ve shared a note with me. '
          'Ask me to summarize, expand, fix, or improve it. '
          'I can also create new notes for you. '
          'What would you like to do?',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming) return;

    final ai = ref.read(aiServiceProvider);
    if (!ai.isReady) {
      _showNotConfigured();
      return;
    }

    _msgController.clear();

    // Check if user wants to create note/folder
    if (_detectCreateIntent(text)) {
      if (_isFolderCreation(text)) {
        await _handleFolderCreate(text);
      } else {
        await _handleCreateCommand(text);
      }
      return;
    }

    _addMessage(ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();

    setState(() {
      _isStreaming = true;
      _streamingBuffer = '';
    });

    _addMessage(ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    ));

    final history = _trimmedHistory;
    final inputHistory = history.length > 1
        ? history.sublist(0, history.length - 1)
        : <ChatMessage>[];

    try {
      await for (final chunk in ai.chatStream(inputHistory, text)) {
        if (!mounted) break;
        setState(() {
          _streamingBuffer += chunk;
        });
        _updateStreamingMessage(_streamingBuffer);
      }
    } finally {
      if (mounted) setState(() => _isStreaming = false);
    }
  }

  bool _detectCreateIntent(String text) {
    final lower = text.toLowerCase();
    return (lower.contains('create') ||
            lower.contains('make') ||
            lower.contains('add') ||
            lower.contains('new')) &&
        (lower.contains('note') || lower.contains('folder') || lower.contains('file'));
  }

  bool _isFolderCreation(String text) {
    final lower = text.toLowerCase();
    return lower.contains('folder') &&
        (lower.contains('create') || lower.contains('make') ||
         lower.contains('add') || lower.contains('new'));
  }

  Future<void> _handleCreateCommand(String userText) async {
    // Add user message to chat
    _addMessage(ChatMessage(
      role: 'user',
      content: userText,
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();

    // Parse DIRECTLY in Dart — no AI call for parsing
    String title = 'Untitled';
    String content = '';

    // Extract title using multiple patterns
    final titlePatterns = [
      RegExp(r'(?:file|note|titled?)\s+(.+?)\s+(?:and|with|description)', caseSensitive: false),
      RegExp(r'(?:file|note|titled?)\s+(.+)$', caseSensitive: false),
      RegExp(r'create\s+(?:a\s+)?(?:file|note)\s+(.+?)\s+(?:and|with)', caseSensitive: false),
    ];

    for (final pattern in titlePatterns) {
      final match = pattern.firstMatch(userText);
      if (match != null) {
        title = match.group(1)?.trim() ?? 'Untitled';
        break;
      }
    }

    // Extract description/content
    final contentPatterns = [
      RegExp(r'description\s+(.+)$', caseSensitive: false),
      RegExp(r'(?:with|content|about)\s+(.+)$', caseSensitive: false),
    ];
    for (final pattern in contentPatterns) {
      final match = pattern.firstMatch(userText);
      if (match != null) {
        content = match.group(1)?.trim() ?? '';
        break;
      }
    }

    // If title still not found, use everything after "create/make/add a note/file"
    if (title == 'Untitled') {
      final fallback = RegExp(
        r'(?:create|make|add)\s+(?:a\s+)?(?:note|file)\s+(.+)',
        caseSensitive: false,
      ).firstMatch(userText);
      if (fallback != null) {
        title = fallback.group(1)
                ?.split(RegExp(r'\s+(?:and|with|description)\s+'))[0]
                .trim() ??
            'Untitled';
      }
    }

    // Clean up title — remove common words
    title = title
        .replaceAll(RegExp(r'^(a|an|the)\s+', caseSensitive: false), '')
        .trim();
    if (title.isEmpty) title = 'Untitled';

    // IMMEDIATELY create the note in Firestore
    try {
      await _createNoteFromChat(title, content);

      // Confirm in chat
      _addMessage(ChatMessage(
        role: 'assistant',
        content: '✅ Note created successfully!\n\n'
            '📝 Title: **$title**\n'
            '${content.isNotEmpty ? '📄 Content: $content\n\n' : ''}'
            'Go to the home screen to see your new note.',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _addMessage(ChatMessage(
        role: 'assistant',
        content: '❌ Failed to create note: $e\n'
            'Please try again.',
        timestamp: DateTime.now(),
      ));
    }
    _scrollToBottom();
    setState(() {});
  }

  void _updateStreamingMessage(String content) {
    if (_messages.isEmpty) return;
    _replaceLastMessage(ChatMessage(
      role: 'assistant',
      content: content,
      timestamp: _messages.last.timestamp,
    ));
    _scrollToBottom();
  }

  Future<void> _createNoteFromChat(
      String title, String content) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final plainContent = content.isEmpty ? ' ' : content;
    final deltaJson = jsonEncode(
      (Document()..insert(0, plainContent))
          .toDelta()
          .toJson());

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notes')
        .add({
      'title': title,
      'content': deltaJson,
      'isEncrypted': false,
      'cipherText': null,
      'plainPreview': plainContent.substring(0, min(80, plainContent.length)),
      'isPinned': false,
      'folderId': null,
      'tags': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createFolderFromChat(String name) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('folders')
        .add({
      'name': name,
      'colorHex': '#2EC4A9',
      'iconName': 'folder',
      'noteCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _handleFolderCreate(String userText) async {
    _addMessage(ChatMessage(
      role: 'user',
      content: userText,
      timestamp: DateTime.now(),
    ));
    _scrollToBottom();

    setState(() {
      _isStreaming = true;
      _streamingBuffer = '';
    });

    _addMessage(ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    ));

    // Extract folder name using regex
    final match = RegExp(
      '(?:folder|directory)\\s+(?:named?|called?)?\\s*["\']?([^"\']+)',
      caseSensitive: false,
    ).firstMatch(userText);
    String name = match?.group(1)?.trim() ?? 'New Folder';

    // Clean up folder name
    name = name
        .replaceAll(RegExp(r'^(a|an|the)\s+', caseSensitive: false), '')
        .trim();
    if (name.isEmpty) name = 'New Folder';

    try {
      await _createFolderFromChat(name);
      _updateStreamingMessage(
        '✅ Folder created successfully!\n\n'
        '📁 Folder name: **$name**\n\n'
        'You can see it in the Folders section on the home screen.',
      );
    } catch (e) {
      _updateStreamingMessage(
        '❌ Failed to create folder: $e\n'
        'Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isStreaming = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showNotConfigured() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            const Text('AI not configured. Add API key to .env file.'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage msg, bool isLast) {
    final isUser = msg.role == 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 16,
        right: isUser ? 16 : 60,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.primary
                  : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
            ),
            child: isLast && _isStreaming && !isUser
                ? _StreamingText(text: msg.content)
                : SelectableText(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(msg.timestamp),
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('SecureNote AI',
                style: GoogleFonts.sora(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Text('by Bilal Hussain',
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch AI provider',
            onPressed: _showProviderSwitch,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _welcomeAdded = true;
                _messages.add(ChatMessage(
                  role: 'assistant',
                  content: 'Hello! I\'m SecureNote AI, your intelligent note '
                      'assistant crafted by Bilal Hussain. I can help you '
                      'summarize notes, fix grammar, expand ideas, and '
                      'create notes or folders. How can I help today?',
                  timestamp: DateTime.now(),
                ));
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) =>
                        _buildMessage(messages[i], i == messages.length - 1),
                  ),
          ),
          if (messages.length <= 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  'Summarize my notes',
                  'Writing tips',
                  'Create a folder',
                  'Create a new note',
                  'Help me write',
                ]
                    .map((chip) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(chip,
                                style: GoogleFonts.dmSans(fontSize: 12)),
                            onPressed: () => _sendMessage(chip),
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.1),
                            side: const BorderSide(
                                color: AppTheme.primary, width: 1),
                          ),
                        ))
                    .toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              border: Border(
                top: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey ==
                              LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance
                              .isShiftPressed &&
                          !_isStreaming) {
                        final text = _msgController.text.trim();
                        if (text.isNotEmpty) _sendMessage(text);
                      }
                    },
                    child: TextField(
                      controller: _msgController,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Ask AI anything...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (v) {
                        if (!_isStreaming && v.trim().isNotEmpty) {
                          _sendMessage(v.trim());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _msgController,
                  builder: (_, val, __) {
                    final hasText = val.text.trim().isNotEmpty;
                    return AnimatedScale(
                      scale: _isStreaming ? 0.9 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: hasText && !_isStreaming
                              ? const Color(0xFF2EC4A9)
                              : Colors.grey[300],
                          foregroundColor: Colors.white,
                        ),
                        icon: _isStreaming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.send_rounded),
                        onPressed: hasText && !_isStreaming
                            ? () => _sendMessage(
                                _msgController.text.trim())
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('SecureNote AI',
                style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('by Bilal Hussain',
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Text('Ask me anything about your notes',
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );

  void _showProviderSwitch() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch AI Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('G',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary)),
              title: const Text('Gemini'),
              subtitle: const Text('Google AI'),
              trailing: dotenv.env['AI_PROVIDER'] == 'gemini'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
              onTap: () {
                dotenv.env['AI_PROVIDER'] = 'gemini';
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Switched to Gemini'),
                        backgroundColor: AppTheme.primary));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.amber),
              title: const Text('Groq (Llama)'),
              subtitle: const Text('Ultra fast responses'),
              trailing: dotenv.env['AI_PROVIDER'] == 'groq'
                  ? const Icon(Icons.check, color: AppTheme.primary)
                  : null,
              onTap: () {
                dotenv.env['AI_PROVIDER'] = 'groq';
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Switched to Groq'),
                        backgroundColor: AppTheme.primary));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _StreamingText extends StatelessWidget {
  final String text;
  const _StreamingText({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        if (text.isNotEmpty)
          Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 2),
            color: AppTheme.primary,
          ),
      ],
    );
  }
}

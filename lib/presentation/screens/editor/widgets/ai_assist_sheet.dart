import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/notes_provider.dart';

class AiAssistSheet extends ConsumerStatefulWidget {
  final String noteContent;
  final Function(String) onResult;

  const AiAssistSheet({
    super.key,
    required this.noteContent,
    required this.onResult,
  });

  @override
  ConsumerState<AiAssistSheet> createState() => _AiAssistSheetState();
}

class _AiAssistSheetState extends ConsumerState<AiAssistSheet> {
  String _result = '';
  bool _isLoading = false;
  String? _activeAction;

  static const _actions = [
    _AiAction(
      icon: Icons.summarize_rounded,
      label: 'Summarize',
      subtitle: 'Condense into 2-3 sentences',
      key: 'summarize',
    ),
    _AiAction(
      icon: Icons.spellcheck_rounded,
      label: 'Fix Grammar',
      subtitle: 'Correct spelling and grammar',
      key: 'grammar',
    ),
    _AiAction(
      icon: Icons.tag_rounded,
      label: 'Generate Tags',
      subtitle: 'Auto-generate relevant tags',
      key: 'tags',
    ),
    _AiAction(
      icon: Icons.expand_rounded,
      label: 'Expand Idea',
      subtitle: 'Add detail and context',
      key: 'expand',
    ),
    _AiAction(
      icon: Icons.compress_rounded,
      label: 'Shorten',
      subtitle: 'Make it concise',
      key: 'shorten',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Handle ──
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Assist',
                      style: GoogleFonts.sora(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textLight : AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'Powered by Gemini',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Action Cards ──
          if (_result.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: _actions.map((action) {
                  final isActive = _activeAction == action.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: widget.noteContent.isEmpty
                          ? null
                          : () => _performAction(action.key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : (isDark
                                  ? AppTheme.cardDark
                                  : AppTheme.surfaceLight),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.primary.withValues(alpha: 0.3)
                                : (isDark
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(action.icon,
                                  color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.label,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textLight
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    action.subtitle,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey.shade500
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: Colors.grey.shade400, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Loading ──
          if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'AI is working on "${_activeAction ?? ''}"...',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Result ──
          if (_result.isNotEmpty && !_isLoading) ...[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: AppTheme.primary, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Result:',
                        style: GoogleFonts.sora(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          height: 1.6,
                          color:
                              isDark ? AppTheme.textLight : AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Action Buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _result = '';
                          _activeAction = null;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Another'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onResult(_result);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_result.isEmpty && !_isLoading)
            const Spacer(),

          // ── Empty state hint ──
          if (widget.noteContent.isEmpty && _result.isEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Write some content first, then use AI Assist.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _performAction(String action) async {
    if (widget.noteContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write some content first!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _activeAction = action;
      _result = '';
    });

    try {
      final notifier = ref.read(notesProvider.notifier);
      String result;

      switch (action) {
        case 'summarize':
          result = await notifier.aiSummarize(widget.noteContent);
          break;
        case 'grammar':
          result = await notifier.aiFixGrammar(widget.noteContent);
          break;
        case 'tags':
          final tags = await notifier.aiGenerateTags(widget.noteContent);
          result = tags.map((t) => '#$t').join(', ');
          break;
        case 'expand':
          result = await notifier.aiExpandIdea(widget.noteContent);
          break;
        case 'shorten':
          result = await notifier.aiShortenNote(widget.noteContent);
          break;
        default:
          result = 'Unknown action';
      }

      if (mounted) {
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }
}

class _AiAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final String key;

  const _AiAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.key,
  });
}

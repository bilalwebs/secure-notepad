import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/presentation/providers/ai_provider.dart';

enum _AIState { idle, loading, result, error }

class AIAssistSheet extends ConsumerStatefulWidget {
  final String noteContent;
  final void Function(String result) onApply;

  const AIAssistSheet({
    super.key,
    required this.noteContent,
    required this.onApply,
  });

  @override
  ConsumerState<AIAssistSheet> createState() => _AIAssistSheetState();
}

class _AIAssistSheetState extends ConsumerState<AIAssistSheet> {
  _AIState _state = _AIState.idle;
  String _result = '';
  String? _activeAction;
  String? _errorMsg;

  static const _actions = [
    {
      'icon': Icons.summarize_rounded,
      'label': 'Summarize',
      'desc': 'Condense into 2-3 sentences',
      'key': 'summarize',
    },
    {
      'icon': Icons.spellcheck_rounded,
      'label': 'Fix Grammar',
      'desc': 'Correct spelling and grammar',
      'key': 'grammar',
    },
    {
      'icon': Icons.tag_rounded,
      'label': 'Generate Tags',
      'desc': 'Auto-generate relevant tags',
      'key': 'tags',
    },
    {
      'icon': Icons.expand_rounded,
      'label': 'Expand Idea',
      'desc': 'Add detail and context',
      'key': 'expand',
    },
    {
      'icon': Icons.compress_rounded,
      'label': 'Shorten Note',
      'desc': 'Make it concise',
      'key': 'shorten',
    },
  ];

  Future<void> _performAction(String action) async {
    setState(() {
      _state = _AIState.loading;
      _activeAction = action;
      _result = '';
      _errorMsg = null;
    });

    try {
      final ai = ref.read(aiServiceProvider);
      String result;

      switch (action) {
        case 'summarize':
          result = await ai.summarize(widget.noteContent);
          break;
        case 'grammar':
          result = await ai.fixGrammar(widget.noteContent);
          break;
        case 'tags':
          final tags = await ai.generateTags(widget.noteContent);
          result = tags.map((t) => '#$t').join(', ');
          break;
        case 'expand':
          result = await ai.expandIdea(widget.noteContent);
          break;
        case 'shorten':
          result = await ai.shortenText(widget.noteContent);
          break;
        default:
          result = 'Unknown action';
      }

      if (mounted) {
        setState(() {
          _result = result;
          _state = _AIState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _state = _AIState.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ai = ref.watch(aiServiceProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assist',
                        style: GoogleFonts.sora(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? AppTheme.textLight : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Powered by ${ai.providerName}',
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
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/ai-chat',
                        extra: {'noteContent': widget.noteContent});
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text('Full Chat',
                      style: GoogleFonts.dmSans(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_state == _AIState.idle)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _actions.length,
                itemBuilder: (context, index) {
                  final action = _actions[index];
                  final isActive = _activeAction == action['key'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: widget.noteContent.isEmpty
                          ? null
                          : () => _performAction(action['key'] as String),
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
                          border: Border(
                            left: BorderSide(
                              color: isActive
                                  ? AppTheme.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(action['icon'] as IconData,
                                  color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action['label'] as String,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppTheme.textLight
                                          : AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    action['desc'] as String,
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
                },
              ),
            ),
          if (_state == _AIState.loading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'AI is working...',
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
          if (_state == _AIState.result) ...[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(
                      left: BorderSide(color: AppTheme.primary, width: 3),
                    ),
                  ),
                  child: _activeAction == 'tags'
                      ? Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _result
                              .split(',')
                              .map((t) => Chip(
                                    label: Text(t.trim(),
                                        style: GoogleFonts.dmSans(
                                            fontSize: 13)),
                                    backgroundColor: AppTheme.primary
                                        .withValues(alpha: 0.1),
                                    labelStyle: const TextStyle(
                                        color: AppTheme.primary),
                                  ))
                              .toList(),
                        )
                      : Text(
                          _result,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            height: 1.6,
                            color: isDark
                                ? AppTheme.textLight
                                : AppTheme.textDark,
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_activeAction != null) {
                          _performAction(_activeAction!);
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Try Again'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onApply(_result);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Apply to note'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_state == _AIState.error) ...[
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMsg ?? 'An error occurred',
                          style: GoogleFonts.dmSans(
                              fontSize: 14, color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_activeAction != null) {
                            _performAction(_activeAction!);
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

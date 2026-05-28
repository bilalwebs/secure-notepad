import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/data/models/note_model.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row ──
            Row(
              children: [
                if (note.isEncrypted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 10, color: AppTheme.primary),
                        const SizedBox(width: 3),
                        Text(
                          'Encrypted',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (note.isVoice) ...[
                  if (note.isEncrypted) const SizedBox(width: 4),
                  Icon(Icons.mic_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600),
                ],
                const Spacer(),
                if (note.isPinned)
                  Icon(Icons.push_pin_rounded,
                      size: 12, color: AppTheme.primary),
              ],
            ),

            // ── Title ──
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Preview ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  note.plainPreview.isEmpty
                      ? 'No content'
                      : note.plainPreview,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // ── Footer: Tags + Date ──
            if (note.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: note.tags
                      .take(2)
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '#$tag',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatDate(note.updatedAt),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color:
                      isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

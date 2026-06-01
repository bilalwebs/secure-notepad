import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/data/models/note_model.dart';
import 'package:secure_notepad/presentation/providers/auth_provider.dart';
import 'package:secure_notepad/presentation/providers/notes_provider.dart';
import 'package:secure_notepad/presentation/screens/home/widgets/note_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  /// The currently selected folder (null = "All Notes").
  String? _selectedFolderId;
  String? _selectedFolderName;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final allNotesAsync = ref.watch(notesStreamProvider);
    final folderNotesAsync = _selectedFolderId != null
        ? ref.watch(notesByFolderProvider(_selectedFolderId!))
        : null;
    final foldersAsync = ref.watch(foldersStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = user?.displayName ?? 'User';

    // Use filtered or all notes depending on selected folder.
    // For folder notes, sort client-side to avoid composite index.
    final AsyncValue<List<NoteModel>> notesAsync;
    if (folderNotesAsync != null) {
      notesAsync = folderNotesAsync.whenData((notes) {
        notes.sort((a, b) {
          final aTime = a.updatedAt;
          final bTime = b.updatedAt;
          return bTime.compareTo(aTime); // newest first
        });
        return notes;
      });
    } else {
      notesAsync = allNotesAsync;
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── Header ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $name',
                            style: GoogleFonts.sora(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTheme.textLight
                                  : AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          notesAsync.when(
                            data: (notes) => Text(
                              '${notes.length} notes',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500,
                              ),
                            ),
                            loading: () => Text(
                              'Loading...',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            error: (_, __) => Text(
                              'Error loading notes',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => context.push('/ai-chat'),
                        icon: const Icon(Icons.auto_awesome_rounded,
                            color: AppTheme.primary),
                        tooltip: 'AI Assistant',
                      ),
                      IconButton(
                        onPressed: () => context.push('/search'),
                        icon: Icon(Icons.search_rounded,
                            color: isDark
                                ? AppTheme.textLight
                                : AppTheme.textDark),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: GoogleFonts.sora(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Folders section ────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Folders',
                            style: GoogleFonts.sora(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textLight
                                  : AppTheme.textDark,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _showCreateFolderSheet(context),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      foldersAsync.when(
                        data: (folders) {
                          if (folders.isEmpty) {
                            return Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.cardDark
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'No folders yet',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }
                          return SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: folders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final folder = folders[index];
                                final color = Color(int.parse(
                                    folder.colorHex.replaceFirst(
                                        '#', '0xFF')));
                                final isSelected =
                                    _selectedFolderId == folder.id;
                                final noteCountAsync = ref.watch(
                                    noteCountByFolderProvider(
                                        folder.id));
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_selectedFolderId ==
                                          folder.id) {
                                        _selectedFolderId = null;
                                        _selectedFolderName = null;
                                      } else {
                                        _selectedFolderId = folder.id;
                                        _selectedFolderName =
                                            folder.name;
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 120,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.withValues(alpha: 0.25)
                                          : color.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? color
                                            : color.withValues(
                                                alpha: 0.3),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.folder_rounded,
                                                color: color, size: 22),
                                            const Spacer(),
                                            noteCountAsync.when(
                                              data: (cnt) => cnt > 0
                                                  ? Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal:
                                                                  6,
                                                              vertical:
                                                                  2),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: color
                                                            .withValues(
                                                                alpha:
                                                                    0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    10),
                                                      ),
                                                      child: Text(
                                                        '$cnt',
                                                        style: GoogleFonts
                                                            .dmSans(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700,
                                                          color: color,
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox
                                                      .shrink(),
                                              loading: () => const SizedBox
                                                  .shrink(),
                                              error: (_, __) =>
                                                  const SizedBox
                                                      .shrink(),
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTapDown: (details) =>
                                                  _showFolderContextMenu(
                                                context,
                                                folder.id,
                                                folder.name,
                                                details.globalPosition,
                                              ),
                                              child: Icon(
                                                Icons.more_vert_rounded,
                                                size: 16,
                                                color:
                                                    Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          folder.name,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppTheme.textLight
                                                : AppTheme.textDark,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        loading: () => const SizedBox(
                            height: 80,
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.primary))),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Notes section header ────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_selectedFolderId != null) ...[
                            GestureDetector(
                              onTap: () => setState(() {
                                _selectedFolderId = null;
                                _selectedFolderName = null;
                              }),
                              child: Icon(Icons.arrow_back_rounded,
                                  size: 20,
                                  color: isDark
                                      ? AppTheme.textLight
                                      : AppTheme.textDark),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _selectedFolderName ?? 'Recent Notes',
                            style: GoogleFonts.sora(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textLight
                                  : AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      if (_selectedFolderId != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedFolderId = null;
                            _selectedFolderName = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_rounded,
                                    size: 14,
                                    color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedFolderName ?? 'Folder',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.close_rounded,
                                    size: 14,
                                    color: AppTheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Notes list ──────────────────────────────
              notesAsync.when(
                data: (notes) {
                  if (notes.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.note_add_outlined,
                                size: 56,
                                color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFolderId != null
                                  ? 'No notes in this folder'
                                  : 'No notes yet',
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap + to create your first note',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = notes[index];
                          final folderName = note.folderId != null
                              ? foldersAsync.whenOrNull(
                                  data: (folders) {
                                    final match = folders.where(
                                        (f) => f.id == note.folderId);
                                    return match.isNotEmpty
                                        ? match.first.name
                                        : null;
                                  },
                                )
                              : null;
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 10),
                            child: NoteCard(
                              note: note,
                              onTap: () =>
                                  context.push('/editor', extra: {
                                'noteId': note.id,
                                'folderId': note.folderId,
                              }),
                              onPin: () => _togglePin(note),
                              onDelete: () =>
                                  _deleteNote(context, note),
                              onDuplicate: () =>
                                  _duplicateNote(note),
                              onMove: () =>
                                  _showMoveToFolderSheet(
                                      context, note),
                              folderName: folderName,
                            ),
                          );
                        },
                        childCount: notes.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary)),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No notes in this folder',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/editor', extra: {
          'noteId': null,
          'folderId': _selectedFolderId,
        }),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  // ── Note actions ────────────────────────────────────────────

  void _togglePin(NoteModel note) {
    ref
        .read(notesRepositoryProvider)
        .togglePinNote(note.id, !note.isPinned);
  }

  Future<void> _deleteNote(BuildContext context, NoteModel note) async {
    // Capture messenger BEFORE async gap to avoid deactivated widget error
    final messenger = ScaffoldMessenger.of(context);

    // Step 1: Delete from Firestore immediately
    // (StreamBuilder will auto-remove the card from the list)
    await ref.read(notesRepositoryProvider).deleteNote(note.id);

    // Step 2: Show brief "Note deleted" toast with Undo (auto-dismiss in 3s)
    if (mounted) {
      messenger
        ..clearSnackBars()
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Note deleted'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B1B2F),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFF2EC4A9),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('notes')
                    .doc(note.id)
                    .set(note.toFirestore());
              },
            ),
          ),
        );

      // Auto-hide after 3 seconds (same pattern as save button)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) messenger.hideCurrentSnackBar();
      });
    }
  }

  void _duplicateNote(NoteModel note) {
    ref.read(notesRepositoryProvider).duplicateNote(note.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note duplicated'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  // ── Move note to folder ─────────────────────────────────────

  void _showMoveToFolderSheet(
      BuildContext context, NoteModel note) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foldersAsync = ref.read(foldersStreamProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Move to folder',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppTheme.textLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            if (note.folderId != null)
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Remove from folder'),
                onTap: () {
                  ref
                      .read(notesRepositoryProvider)
                      .moveNoteToFolder(note.id, null);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Note removed from folder'),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                },
              ),
            foldersAsync.when(
              data: (folders) {
                final available = folders
                    .where((f) => f.id != note.folderId)
                    .toList();
                if (available.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No other folders available',
                      style: GoogleFonts.dmSans(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: available.length,
                  itemBuilder: (context, index) {
                    final folder = available[index];
                    final color = Color(int.parse(
                        folder.colorHex.replaceFirst(
                            '#', '0xFF')));
                    return ListTile(
                      leading: Icon(Icons.folder_rounded,
                          color: color),
                      title: Text(folder.name),
                      onTap: () {
                        ref
                            .read(notesRepositoryProvider)
                            .moveNoteToFolder(
                                note.id, folder.id);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                                'Moved to "${folder.name}"'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    color: AppTheme.primary),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Error loading folders'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Folder context menu (3-dot icon) ────────────────────────

  void _showFolderContextMenu(
    BuildContext context,
    String folderId,
    String folderName,
    Offset position,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined,
                  size: 18,
                  color: isDark
                      ? AppTheme.textLight
                      : AppTheme.textDark),
              const SizedBox(width: 10),
              Text('Rename',
                  style: GoogleFonts.dmSans(
                    color: isDark
                        ? AppTheme.textLight
                        : AppTheme.textDark,
                  )),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'new_note',
          child: Row(
            children: [
              Icon(Icons.note_add_outlined,
                  size: 18,
                  color: isDark
                      ? AppTheme.textLight
                      : AppTheme.textDark),
              const SizedBox(width: 10),
              Text('New note here',
                  style: GoogleFonts.dmSans(
                    color: isDark
                        ? AppTheme.textLight
                        : AppTheme.textDark,
                  )),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              const SizedBox(width: 10),
              Text('Delete',
                  style: GoogleFonts.dmSans(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((action) {
      if (action == null) return;
      switch (action) {
        case 'rename':
          _showRenameFolderDialog(
              context, folderId, folderName);
          break;
        case 'new_note':
          context.push('/editor', extra: {
            'noteId': null,
            'folderId': folderId,
          });
          break;
        case 'delete':
          _showDeleteFolderDialog(context, folderId);
          break;
      }
    });
  }

  // ── Create folder sheet ─────────────────────────────────────

  void _showCreateFolderSheet(BuildContext context) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20,
            MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create Folder',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Folder name',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    ref.read(notesRepositoryProvider).createFolder(
                        controller.text.trim(),
                        '#2EC4A9',
                        'folder');
                    Navigator.pop(context);
                  }
                },
                child: const Text('Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rename folder dialog ────────────────────────────────────

  void _showRenameFolderDialog(
    BuildContext context,
    String folderId,
    String currentName,
  ) {
    final controller =
        TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(notesRepositoryProvider)
                    .renameFolder(
                        folderId, controller.text.trim());
                if (_selectedFolderId == folderId) {
                  setState(() {
                    _selectedFolderName =
                        controller.text.trim();
                  });
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Delete folder dialog ────────────────────────────────────

  void _showDeleteFolderDialog(
      BuildContext context, String folderId) {
    final repo = ref.read(notesRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Folder'),
        content: const Text(
            'What should happen to the notes inside?'),
        actions: [
          TextButton(
            onPressed: () {
              repo.deleteFolderKeepNotes(folderId);
              if (_selectedFolderId == folderId) {
                setState(() {
                  _selectedFolderId = null;
                  _selectedFolderName = null;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Keep notes'),
          ),
          TextButton(
            onPressed: () {
              repo.deleteFolderAndNotes(folderId);
              if (_selectedFolderId == folderId) {
                setState(() {
                  _selectedFolderId = null;
                  _selectedFolderName = null;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Delete all',
                style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

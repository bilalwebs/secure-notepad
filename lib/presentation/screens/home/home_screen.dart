import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/data/models/folder_model.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final notesState = ref.watch(notesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = user?.displayName ?? 'User';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            // Force rebuild by re-watching
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── Top Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $name',
                              style: GoogleFonts.sora(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTheme.textLight
                                    : AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'What are you writing today?',
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
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            name[0].toUpperCase(),
                            style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Search Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => context.push('/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600),
                          const SizedBox(width: 12),
                          Text(
                            'Search notes...',
                            style: GoogleFonts.dmSans(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── My Folders ──
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, top: 24, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Folders',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? AppTheme.textLight : AppTheme.textDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showCreateFolderSheet(context),
                        icon: Icon(Icons.add_rounded,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              ),

              // Folders horizontal list
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: notesState.folders.isEmpty
                      ? _buildEmptyFolders(isDark)
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: notesState.folders.length,
                          itemBuilder: (context, index) {
                            final folder = notesState.folders[index];
                            return _buildFolderCard(folder, isDark);
                          },
                        ),
                ),
              ),

              // ── Notes Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 20, top: 24, bottom: 12),
                  child: Text(
                    'My Notes',
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textLight : AppTheme.textDark,
                    ),
                  ),
                ),
              ),

              // Notes grid or loading/empty state
              _buildNotesContent(notesState, isDark),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/editor'),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  Widget _buildNotesContent(NotesState notesState, bool isDark) {
    if (notesState.isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildShimmerCard(isDark),
            childCount: 4,
          ),
        ),
      );
    }

    if (notesState.notes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyNotes(isDark),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final note = notesState.notes[index];
            return Slidable(
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                children: [
                  SlidableAction(
                    onPressed: (_) => _deleteNote(note.id, note.folderId),
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
              child: NoteCard(
                note: note,
                onTap: () => context.push('/editor', extra: note),
              ),
            );
          },
          childCount: notesState.notes.length,
        ),
      ),
    );
  }

  Widget _buildShimmerCard(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? AppTheme.cardDark : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildFolderCard(FolderModel folder, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/editor'),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.folder_rounded,
                color: _parseColor(folder.colorHex), size: 28),
            const Spacer(),
            Text(
              folder.name,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? AppTheme.textLight : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${folder.noteCount} notes',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: isDark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFolders(bool isDark) {
    return Center(
      child: Text(
        'No folders yet. Tap + to create one.',
        style: GoogleFonts.dmSans(
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildEmptyNotes(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_add_rounded,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first note',
            style: GoogleFonts.dmSans(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_rounded, 'Home', true, isDark),
              _navItem(Icons.search_rounded, 'Search', false, isDark,
                  onTap: () => context.push('/search')),
              _navItem(
                  Icons.calendar_today_rounded, 'Calendar', false, isDark,
                  onTap: () => context.push('/calendar')),
              _navItem(Icons.person_rounded, 'Profile', false, isDark,
                  onTap: () => context.push('/profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      IconData icon, String label, bool isActive, bool isDark,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isActive
                  ? AppTheme.primary
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade400)),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? AppTheme.primary
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  void _deleteNote(String noteId, String? folderId) {
    ref.read(notesProvider.notifier).deleteNote(noteId, folderId: folderId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note deleted')),
    );
  }

  void _showCreateFolderSheet(BuildContext context) {
    final nameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Folder',
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                prefixIcon: Icon(Icons.folder_rounded),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    final folder = FolderModel(
                      id: '',
                      name: nameController.text.trim(),
                      colorHex: '#2EC4A9',
                      iconName: 'folder',
                      createdAt: DateTime.now(),
                    );
                    ref.read(notesProvider.notifier).createFolder(folder);
                    Navigator.pop(ctx);
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
}

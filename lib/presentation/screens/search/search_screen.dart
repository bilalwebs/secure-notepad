import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:secure_notepad/core/theme/app_theme.dart';
import 'package:secure_notepad/data/models/note_model.dart';
import 'package:secure_notepad/presentation/providers/notes_provider.dart';
import 'package:secure_notepad/presentation/screens/home/widgets/note_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<String> _recentSearches = [];
  late Box<String> _recentSearchBox;

  @override
  void initState() {
    super.initState();
    _initRecentSearches();
  }

  Future<void> _initRecentSearches() async {
    _recentSearchBox = await Hive.openBox<String>('recent_searches');
    setState(() {
      _recentSearches = _recentSearchBox.values.toList().reversed.toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) return;
    ref.read(notesProvider.notifier).search(query.trim());
    _saveRecentSearch(query.trim());
  }

  Future<void> _saveRecentSearch(String query) async {
    // Remove duplicates
    _recentSearchBox.values
        .where((q) => q == query)
        .toList()
        .forEach((q) {
      final key = _recentSearchBox.keyAt(
          _recentSearchBox.values.toList().indexOf(q));
      if (key != null) _recentSearchBox.delete(key);
    });
    await _recentSearchBox.add(query);
    // Keep only last 10
    if (_recentSearchBox.length > 10) {
      await _recentSearchBox.deleteAt(0);
    }
    setState(() {
      _recentSearches = _recentSearchBox.values.toList().reversed.toList();
    });
  }

  Future<void> _clearRecentSearches() async {
    await _recentSearchBox.clear();
    setState(() => _recentSearches = []);
  }

  List<NoteModel> _applyFilter(List<NoteModel> notes) {
    switch (_selectedFilter) {
      case 'Encrypted':
        return notes.where((n) => n.isEncrypted).toList();
      case 'Voice':
        return notes.where((n) => n.isVoice).toList();
      case 'Folders':
        return notes.where((n) => n.folderId != null).toList();
      default:
        return notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchResults = notesState.searchResults ?? [];

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearch,
          style: GoogleFonts.dmSans(
            color: isDark ? AppTheme.textLight : AppTheme.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Search notes, tags...',
            hintStyle: GoogleFonts.dmSans(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                ref.read(notesProvider.notifier).clearSearch();
                setState(() {});
              },
              icon: const Icon(Icons.clear_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Encrypted', 'Voice', 'Folders']
                    .map((filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter,
                                style: GoogleFonts.dmSans(fontSize: 13)),
                            selected: _selectedFilter == filter,
                            onSelected: (_) =>
                                setState(() => _selectedFilter = filter),
                            selectedColor:
                                AppTheme.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _selectedFilter == filter
                                  ? AppTheme.primary
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600),
                            ),
                            side: BorderSide(
                              color: _selectedFilter == filter
                                  ? AppTheme.primary
                                  : (isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),

          // ── Content ──
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildRecentSearches(isDark)
                : searchResults.isEmpty
                    ? _buildNoResults(isDark)
                    : _buildResults(searchResults, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(bool isDark) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: 64,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Search your notes',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search by title or tags',
              style: GoogleFonts.dmSans(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                child: Text(
                  'Clear',
                  style: GoogleFonts.dmSans(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return ListTile(
                leading: Icon(Icons.history_rounded,
                    color: isDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade400),
                title: Text(query,
                    style: GoogleFonts.dmSans(
                      color:
                          isDark ? AppTheme.textLight : AppTheme.textDark,
                    )),
                onTap: () {
                  _searchController.text = query;
                  _onSearch(query);
                },
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: GoogleFonts.sora(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: GoogleFonts.dmSans(
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(List<NoteModel> results, bool isDark) {
    final filtered = _applyFilter(results);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No notes match this filter',
          style: GoogleFonts.dmSans(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final note = filtered[index];
        return NoteCard(
          note: note,
          onTap: () => context.push('/editor', extra: note),
        );
      },
    );
  }
}

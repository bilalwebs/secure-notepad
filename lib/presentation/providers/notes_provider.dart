import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_notepad/data/models/note_model.dart';
import 'package:secure_notepad/data/models/folder_model.dart';
import 'package:secure_notepad/data/repositories/notes_repository.dart';
import 'package:secure_notepad/data/services/gemini_service.dart';

// ───────────────────────── Providers ─────────────────────────────

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

/// Notes stream provider.
final notesStreamProvider = StreamProvider<List<NoteModel>>((ref) {
  return ref.watch(notesRepositoryProvider).getNotes();
});

/// Folders stream provider.
final foldersStreamProvider = StreamProvider<List<FolderModel>>((ref) {
  return ref.watch(notesRepositoryProvider).getFolders();
});

/// Notes state notifier for complex operations.
final notesProvider =
    StateNotifierProvider<NotesNotifier, NotesState>((ref) {
  return NotesNotifier(
    ref.watch(notesRepositoryProvider),
    ref.watch(geminiServiceProvider),
  );
});

// ───────────────────────── NotesState ────────────────────────────

enum NotesStatus { initial, loading, loaded, error }

class NotesState {
  final NotesStatus status;
  final List<NoteModel> notes;
  final List<FolderModel> folders;
  final String? errorMessage;
  final String? searchQuery;
  final List<NoteModel>? searchResults;

  const NotesState({
    required this.status,
    this.notes = const [],
    this.folders = const [],
    this.errorMessage,
    this.searchQuery,
    this.searchResults,
  });

  const NotesState.initial() : this(status: NotesStatus.initial);
  const NotesState.loading() : this(status: NotesStatus.loading);
  NotesState.loaded(List<NoteModel> notes, List<FolderModel> folders)
      : this(status: NotesStatus.loaded, notes: notes, folders: folders);
  const NotesState.error(String message)
      : this(status: NotesStatus.error, errorMessage: message);

  bool get isLoading => status == NotesStatus.loading;
}

// ───────────────────────── NotesNotifier ──────────────────────────

class NotesNotifier extends StateNotifier<NotesState> {
  final NotesRepository _repo;
  final GeminiService _gemini;
  StreamSubscription<List<NoteModel>>? _notesSub;
  StreamSubscription<List<FolderModel>>? _foldersSub;
  List<NoteModel> _currentNotes = [];
  List<FolderModel> _currentFolders = [];

  NotesNotifier(this._repo, this._gemini)
      : super(const NotesState.initial()) {
    _init();
  }

  Future<void> _init() async {
    await _repo.initCache();
    state = const NotesState.loading();

    _notesSub = _repo.getNotes().listen(
      (notes) {
        _currentNotes = notes;
        state = NotesState.loaded(_currentNotes, _currentFolders);
      },
      onError: (e) => state = NotesState.error(e.toString()),
    );

    _foldersSub = _repo.getFolders().listen(
      (folders) {
        _currentFolders = folders;
        state = NotesState.loaded(_currentNotes, _currentFolders);
      },
      onError: (e) => state = NotesState.error(e.toString()),
    );
  }

  @override
  void dispose() {
    _notesSub?.cancel();
    _foldersSub?.cancel();
    super.dispose();
  }

  // ── Note Operations ──

  Future<String> createNote(NoteModel note) async {
    return await _repo.createNote(note);
  }

  Future<void> updateNote(NoteModel note) async {
    await _repo.updateNote(note);
  }

  Future<void> deleteNote(String noteId, {String? folderId}) async {
    await _repo.deleteNote(noteId, folderId: folderId);
  }

  Future<void> togglePin(String noteId, bool isPinned) async {
    await _repo.togglePin(noteId, isPinned);
  }

  // ── Folder Operations ──

  Future<String> createFolder(FolderModel folder) async {
    return await _repo.createFolder(folder);
  }

  Future<void> updateFolder(FolderModel folder) async {
    await _repo.updateFolder(folder);
  }

  Future<void> deleteFolder(String folderId) async {
    await _repo.deleteFolder(folderId);
  }

  // ── Search ──

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = NotesState.loaded(_currentNotes, _currentFolders);
      return;
    }
    final results = await _repo.searchNotes(query);
    state = NotesState.loaded(_currentNotes, _currentFolders);
    state = NotesState(
      status: NotesStatus.loaded,
      notes: _currentNotes,
      folders: _currentFolders,
      searchQuery: query,
      searchResults: results,
    );
  }

  void clearSearch() {
    state = NotesState.loaded(_currentNotes, _currentFolders);
  }

  // ── AI Operations ──

  Future<String> aiSummarize(String content) async {
    return await _gemini.summarizeNote(content);
  }

  Future<String> aiFixGrammar(String content) async {
    return await _gemini.fixGrammar(content);
  }

  Future<List<String>> aiGenerateTags(String content) async {
    return await _gemini.generateTags(content);
  }

  Future<String> aiExpandIdea(String idea) async {
    return await _gemini.expandIdea(idea);
  }

  Future<String> aiShortenNote(String content) async {
    return await _gemini.shortenNote(content);
  }

  Stream<String> aiSummarizeStream(String content) {
    return _gemini.summarizeNoteStream(content);
  }

  Stream<String> aiFixGrammarStream(String content) {
    return _gemini.fixGrammarStream(content);
  }

  Stream<String> aiExpandIdeaStream(String idea) {
    return _gemini.expandIdeaStream(idea);
  }

  Stream<String> aiShortenNoteStream(String content) {
    return _gemini.shortenNoteStream(content);
  }

  // ── Reminders ──

  Future<void> createReminder({
    required String noteId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    await _repo.createReminder(
      noteId: noteId,
      title: title,
      scheduledAt: scheduledAt,
    );
  }
}

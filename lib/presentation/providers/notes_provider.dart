import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_notepad/data/models/note_model.dart';
import 'package:secure_notepad/data/models/folder_model.dart';
import 'package:secure_notepad/data/repositories/notes_repository.dart';
import 'package:secure_notepad/data/services/gemini_service.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository();
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final notesStreamProvider = StreamProvider<List<NoteModel>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.allNotesStream().map((snapshot) =>
      snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList());
});

final notesByFolderProvider =
    StreamProvider.family<List<NoteModel>, String>((ref, folderId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.notesStream(folderId: folderId).map((snapshot) =>
      snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList());
});

final foldersStreamProvider = StreamProvider<List<FolderModel>>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.foldersStream().map((snapshot) =>
      snapshot.docs.map((doc) => FolderModel.fromFirestore(doc)).toList());
});

final remindersStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.remindersStream();
});

/// Real-time count of notes inside a specific folder.
final noteCountByFolderProvider =
    StreamProvider.family<int, String>((ref, folderId) {
  final repo = ref.watch(notesRepositoryProvider);
  return repo.notesStream(folderId: folderId).map((s) => s.docs.length);
});

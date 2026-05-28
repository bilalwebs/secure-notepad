import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:secure_notepad/data/models/note_model.dart';
import 'package:secure_notepad/data/models/folder_model.dart';

class NotesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  late Box<Map> _notesCache;

  NotesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference get _notesRef =>
      _firestore.collection('users').doc(_uid).collection('notes');

  CollectionReference get _foldersRef =>
      _firestore.collection('users').doc(_uid).collection('folders');

  CollectionReference get _remindersRef =>
      _firestore.collection('users').doc(_uid).collection('reminders');

  /// Initialize Hive cache.
  Future<void> initCache() async {
    _notesCache = await Hive.openBox<Map>('notes_cache');
  }

  // ───────────────────────── Notes CRUD ─────────────────────────

  /// Get all notes as a stream (real-time).
  Stream<List<NoteModel>> getNotes() {
    return _notesRef
        .orderBy('isPinned', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final notes =
          snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList();
      _cacheNotes(notes);
      return notes;
    });
  }

  /// Get notes by folder.
  Stream<List<NoteModel>> getNotesByFolder(String folderId) {
    return _notesRef
        .where('folderId', isEqualTo: folderId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList());
  }

  /// Get cached notes (offline).
  List<NoteModel> getCachedNotes() {
    return _notesCache.values.map((map) {
      final data = Map<String, dynamic>.from(map);
      return NoteModel(
        id: data['id'] ?? '',
        title: data['title'] ?? '',
        cipherText: data['cipherText'] ?? '',
        plainPreview: data['plainPreview'] ?? '',
        isEncrypted: data['isEncrypted'] ?? false,
        isVoice: data['isVoice'] ?? false,
        audioUrl: data['audioUrl'],
        folderId: data['folderId'],
        tags: List<String>.from(data['tags'] ?? []),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt:
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
        isPinned: data['isPinned'] ?? false,
      );
    }).toList();
  }

  /// Create a new note.
  Future<String> createNote(NoteModel note) async {
    final docRef = await _notesRef.add(note.toFirestore());
    if (note.folderId != null) {
      await _updateFolderNoteCount(note.folderId!);
    }
    return docRef.id;
  }

  /// Update an existing note.
  Future<void> updateNote(NoteModel note) async {
    await _notesRef.doc(note.id).update(note.toFirestore());
  }

  /// Delete a note.
  Future<void> deleteNote(String noteId, {String? folderId}) async {
    await _notesRef.doc(noteId).delete();
    if (folderId != null) {
      await _updateFolderNoteCount(folderId);
    }
  }

  /// Toggle pin status.
  Future<void> togglePin(String noteId, bool isPinned) async {
    await _notesRef.doc(noteId).update({'isPinned': isPinned});
  }

  /// Search notes by title or tags.
  Future<List<NoteModel>> searchNotes(String query) async {
    final lowerQuery = query.toLowerCase();
    final snapshot = await _notesRef.get();
    return snapshot.docs
        .map((doc) => NoteModel.fromFirestore(doc))
        .where((note) =>
            note.title.toLowerCase().contains(lowerQuery) ||
            note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)))
        .toList();
  }

  // ───────────────────────── Folders CRUD ─────────────────────────

  /// Get all folders as a stream.
  Stream<List<FolderModel>> getFolders() {
    return _foldersRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FolderModel.fromFirestore(doc))
            .toList());
  }

  /// Create a new folder.
  Future<String> createFolder(FolderModel folder) async {
    final docRef = await _foldersRef.add(folder.toFirestore());
    return docRef.id;
  }

  /// Update a folder.
  Future<void> updateFolder(FolderModel folder) async {
    await _foldersRef.doc(folder.id).update(folder.toFirestore());
  }

  /// Delete a folder.
  Future<void> deleteFolder(String folderId) async {
    // Move notes out of folder first
    final notes = await _notesRef
        .where('folderId', isEqualTo: folderId)
        .get();
    for (final doc in notes.docs) {
      await doc.reference.update({'folderId': null});
    }
    await _foldersRef.doc(folderId).delete();
  }

  /// Update folder note count.
  Future<void> _updateFolderNoteCount(String folderId) async {
    final count = await _notesRef
        .where('folderId', isEqualTo: folderId)
        .count()
        .get();
    await _foldersRef
        .doc(folderId)
        .update({'noteCount': count.count});
  }

  // ───────────────────────── Reminders ─────────────────────────

  /// Create a reminder.
  Future<String> createReminder({
    required String noteId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    final docRef = await _remindersRef.add({
      'noteId': noteId,
      'title': title,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'isCompleted': false,
    });
    return docRef.id;
  }

  /// Get reminders grouped by date.
  Stream<List<QueryDocumentSnapshot>> getReminders() {
    return _remindersRef
        .where('isCompleted', isEqualTo: false)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  /// Mark reminder as completed.
  Future<void> completeReminder(String reminderId) async {
    await _remindersRef.doc(reminderId).update({'isCompleted': true});
  }

  // ───────────────────────── Cache ─────────────────────────

  void _cacheNotes(List<NoteModel> notes) {
    // Keep only the last 50 notes in cache
    final toCache = notes.take(50).toList();
    _notesCache.clear();
    for (final note in toCache) {
      final data = note.toFirestore();
      data['id'] = note.id;
      _notesCache.put(note.id, data);
    }
  }
}


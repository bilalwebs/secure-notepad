import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotesRepository {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _notes => FirebaseFirestore.instance
      .collection('users').doc(_uid).collection('notes');

  CollectionReference get _folders => FirebaseFirestore.instance
      .collection('users').doc(_uid).collection('folders');

  CollectionReference get _reminders => FirebaseFirestore.instance
      .collection('users').doc(_uid).collection('reminders');

  // ── Notes CRUD ──────────────────────────────────────────

  /// Stream notes optionally filtered by folderId.
  /// Does NOT use .orderBy() to avoid requiring a composite index.
  /// Sorting is done client-side in the provider/home screen.
  Stream<QuerySnapshot> notesStream({String? folderId}) {
    Query q = _notes;
    if (folderId != null) {
      q = q.where('folderId', isEqualTo: folderId);
    }
    return q.snapshots();
  }

  Stream<QuerySnapshot> allNotesStream() {
    return _notes
        .orderBy('isPinned', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Create a brand-new note and return its document id.
  Future<String> createNote(Map<String, dynamic> data) async {
    final ref = await _notes.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateNote(String id, Map<String, dynamic> data) async {
    await _notes.doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNoteTitle(String id, String title) =>
      updateNote(id, {'title': title.isEmpty ? 'Untitled' : title});

  /// Fetch a single note document by id.
  Future<DocumentSnapshot> getNote(String id) => _notes.doc(id).get();

  Future<void> deleteNote(String id) => _notes.doc(id).delete();

  Future<void> moveNoteToFolder(String id, String? folderId) =>
      updateNote(id, {'folderId': folderId});

  Future<void> togglePinNote(String id, bool pin) =>
      updateNote(id, {'isPinned': pin});

  Future<void> duplicateNote(String id) async {
    final snap = await _notes.doc(id).get();
    if (!snap.exists) return;
    final d = snap.data() as Map<String, dynamic>;
    await _notes.add({
      ...d,
      'title': '${d['title']} (Copy)',
      'isPinned': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Folders CRUD ─────────────────────────────────────────

  Stream<QuerySnapshot> foldersStream() =>
      _folders.orderBy('createdAt').snapshots();

  Future<void> createFolder(
      String name, String colorHex, String icon) async {
    await _folders.add({
      'name': name,
      'colorHex': colorHex,
      'iconName': icon,
      'noteCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameFolder(String id, String name) =>
      _folders.doc(id).update({'name': name});

  Future<void> changeFolderColor(String id, String hex) =>
      _folders.doc(id).update({'colorHex': hex});

  Future<void> deleteFolderKeepNotes(String id) async {
    final snaps = await _notes.where('folderId', isEqualTo: id).get();
    for (final d in snaps.docs) {
      await d.reference.update({'folderId': null});
    }
    await _folders.doc(id).delete();
  }

  Future<void> deleteFolderAndNotes(String id) async {
    final snaps = await _notes.where('folderId', isEqualTo: id).get();
    for (final d in snaps.docs) {
      await d.reference.delete();
    }
    await _folders.doc(id).delete();
  }

  // ── Reminders CRUD ───────────────────────────────────────

  Stream<QuerySnapshot> remindersStream() =>
      _reminders.orderBy('scheduledAt').snapshots();

  Future<DocumentReference> addReminder(
      Map<String, dynamic> data) => _reminders.add(data);

  Future<void> updateReminder(
      String id, Map<String, dynamic> data) =>
      _reminders.doc(id).update(data);

  Future<void> deleteReminder(String id) =>
      _reminders.doc(id).delete();
}

import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String title;
  final String cipherText;
  final String plainPreview;
  final bool isEncrypted;
  final bool isVoice;
  final String? audioUrl;
  final String? folderId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reminderAt;
  final bool isPinned;

  const NoteModel({
    required this.id,
    required this.title,
    required this.cipherText,
    required this.plainPreview,
    this.isEncrypted = false,
    this.isVoice = false,
    this.audioUrl,
    this.folderId,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.reminderAt,
    this.isPinned = false,
  });

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoteModel(
      id: doc.id,
      title: data['title'] ?? '',
      cipherText: data['cipherText'] ?? '',
      plainPreview: data['plainPreview'] ?? '',
      isEncrypted: data['isEncrypted'] ?? false,
      isVoice: data['isVoice'] ?? false,
      audioUrl: data['audioUrl'],
      folderId: data['folderId'],
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'cipherText': cipherText,
      'plainPreview': plainPreview,
      'isEncrypted': isEncrypted,
      'isVoice': isVoice,
      'audioUrl': audioUrl,
      'folderId': folderId,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt!) : null,
      'isPinned': isPinned,
    };
  }

  NoteModel copyWith({
    String? id,
    String? title,
    String? cipherText,
    String? plainPreview,
    bool? isEncrypted,
    bool? isVoice,
    String? audioUrl,
    String? folderId,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reminderAt,
    bool? isPinned,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      cipherText: cipherText ?? this.cipherText,
      plainPreview: plainPreview ?? this.plainPreview,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isVoice: isVoice ?? this.isVoice,
      audioUrl: audioUrl ?? this.audioUrl,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderAt: reminderAt ?? this.reminderAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class FolderModel {
  final String id;
  final String name;
  final String colorHex;
  final String iconName;
  final int noteCount;
  final DateTime createdAt;

  const FolderModel({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
    this.noteCount = 0,
    required this.createdAt,
  });

  factory FolderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FolderModel(
      id: doc.id,
      name: data['name'] ?? '',
      colorHex: data['colorHex'] ?? '#2EC4A9',
      iconName: data['iconName'] ?? 'folder',
      noteCount: data['noteCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'colorHex': colorHex,
      'iconName': iconName,
      'noteCount': noteCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FolderModel copyWith({
    String? id,
    String? name,
    String? colorHex,
    String? iconName,
    int? noteCount,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      noteCount: noteCount ?? this.noteCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteType {
  text,
  voice,
  drawing,
  photo,
  checklist,
  document,
}

// Note color options matching the design
class NoteColor {
  final Color color;
  final Color backgroundColor;
  final String name;

  const NoteColor({
    required this.color,
    required this.backgroundColor,
    required this.name,
  });

  static const List<NoteColor> colors = [
    NoteColor(
      color: Color(0xFFFEF3C7),
      backgroundColor: Color(0xFFFEF3C7),
      name: 'Yellow',
    ),
    NoteColor(
      color: Color(0xFFFFFFFF),
      backgroundColor: Color(0xFFFFFFFF),
      name: 'White',
    ),
    NoteColor(
      color: Color(0xFFDBEAFE),
      backgroundColor: Color(0xFFDBEAFE),
      name: 'Blue',
    ),
    NoteColor(
      color: Color(0xFFDCFCE7),
      backgroundColor: Color(0xFFDCFCE7),
      name: 'Green',
    ),
    NoteColor(
      color: Color(0xFFF3E8FF),
      backgroundColor: Color(0xFFF3E8FF),
      name: 'Purple',
    ),
    NoteColor(
      color: Color(0xFFFFEDD5),
      backgroundColor: Color(0xFFFFEDD5),
      name: 'Orange',
    ),
    NoteColor(
      color: Color(0xFFF1F5F9),
      backgroundColor: Color(0xFFF1F5F9),
      name: 'Gray',
    ),
  ];

  // Default pink color from screenshot
  static const NoteColor defaultColor = NoteColor(
    color: Color(0xFFFCE7F3),
    backgroundColor: Color(0xFFFCE7F3),
    name: 'Pink',
  );
}

class Note {
  final String id;
  final String title;
  final String content;
  final NoteType type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;
  final bool isPinned;
  final bool isFavorite;
  final bool isLocked;
  final String? voicePath;
  final String? imagePath;
  final String? pdfPath;
  final List<ChecklistItem>? checklistItems;
  final int colorIndex;
  final List<String> tags;
  final String? ocrText;
  final DateTime? reminderDateTime;

  Note({
    required this.id,
    required this.title,
    this.content = '',
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.isPinned = false,
    this.isFavorite = false,
    this.isLocked = false,
    this.voicePath,
    this.imagePath,
    this.pdfPath,
    this.checklistItems,
    this.colorIndex = -1, // -1 means default pink
    this.tags = const [],
    this.ocrText,
    this.reminderDateTime,
  });

  Color get noteColor {
    if (colorIndex < 0 || colorIndex >= NoteColor.colors.length) {
      return NoteColor.defaultColor.backgroundColor;
    }
    return NoteColor.colors[colorIndex].backgroundColor;
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    NoteType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    bool? isPinned,
    bool? isFavorite,
    bool? isLocked,
    String? voicePath,
    String? imagePath,
    String? pdfPath,
    List<ChecklistItem>? checklistItems,
    int? colorIndex,
    List<String>? tags,
    String? ocrText,
    bool clearOcrText = false,
    DateTime? reminderDateTime,
    bool clearReminder = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      isLocked: isLocked ?? this.isLocked,
      voicePath: voicePath ?? this.voicePath,
      imagePath: imagePath ?? this.imagePath,
      pdfPath: pdfPath ?? this.pdfPath,
      checklistItems: checklistItems ?? this.checklistItems,
      colorIndex: colorIndex ?? this.colorIndex,
      tags: tags ?? this.tags,
      ocrText: clearOcrText ? null : (ocrText ?? this.ocrText),
      reminderDateTime: clearReminder ? null : (reminderDateTime ?? this.reminderDateTime),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'folderId': folderId,
      'isPinned': isPinned,
      'isFavorite': isFavorite,
      'isLocked': isLocked,
      'voicePath': voicePath,
      'imagePath': imagePath,
      'pdfPath': pdfPath,
      'checklistItems': checklistItems?.map((e) => e.toJson()).toList(),
      'colorIndex': colorIndex,
      'tags': tags,
      'ocrText': ocrText,
      'reminderDateTime': reminderDateTime?.toIso8601String(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'] ?? '',
      type: NoteType.values[json['type']],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      folderId: json['folderId'],
      isPinned: json['isPinned'] ?? false,
      isFavorite: json['isFavorite'] ?? false,
      isLocked: json['isLocked'] ?? false,
      voicePath: json['voicePath'],
      imagePath: json['imagePath'],
      pdfPath: json['pdfPath'],
      checklistItems: json['checklistItems'] != null
          ? (json['checklistItems'] as List)
              .map((e) => ChecklistItem.fromJson(e))
              .toList()
          : null,
      colorIndex: json['colorIndex'] ?? -1,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      ocrText: json['ocrText'],
      reminderDateTime: json['reminderDateTime'] != null
          ? DateTime.parse(json['reminderDateTime'])
          : null,
    );
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'type': type.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'folderId': folderId,
      'isPinned': isPinned,
      'isFavorite': isFavorite,
      'isLocked': isLocked,
      'voicePath': voicePath,
      'imagePath': imagePath,
      'pdfPath': pdfPath,
      'checklistItems': checklistItems?.map((e) => e.toJson()).toList(),
      'colorIndex': colorIndex,
      'tags': tags,
      'ocrText': ocrText,
      'reminderDateTime': reminderDateTime != null
          ? Timestamp.fromDate(reminderDateTime!)
          : null,
    };
  }

  factory Note.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Note(
      id: documentId,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      type: NoteType.values[data['type'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      folderId: data['folderId'],
      isPinned: data['isPinned'] ?? false,
      isFavorite: data['isFavorite'] ?? false,
      isLocked: data['isLocked'] ?? false,
      voicePath: data['voicePath'],
      imagePath: data['imagePath'],
      pdfPath: data['pdfPath'],
      checklistItems: data['checklistItems'] != null
          ? (data['checklistItems'] as List)
              .map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      colorIndex: data['colorIndex'] ?? -1,
      tags: data['tags'] != null ? List<String>.from(data['tags']) : [],
      ocrText: data['ocrText'],
      reminderDateTime: (data['reminderDateTime'] as Timestamp?)?.toDate(),
    );
  }
}

class ChecklistItem {
  final String id;
  final String text;
  final bool isChecked;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isChecked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isChecked': isChecked,
    };
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'],
      text: json['text'],
      isChecked: json['isChecked'] ?? false,
    );
  }
}

class Folder {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool hasAI;
  final bool isSystem;

  const Folder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.hasAI = false,
    this.isSystem = false,
  });

  static List<Folder> defaultFolders = [
    Folder(
      id: 'all',
      name: 'All Notes',
      icon: Icons.note_alt_outlined,
      color: const Color(0xFF8B5CF6),
      hasAI: true,
      isSystem: true,
    ),
    Folder(
      id: 'work',
      name: 'Work',
      icon: Icons.work_outline,
      color: const Color(0xFF3B82F6),
    ),
    Folder(
      id: 'personal',
      name: 'Personal',
      icon: Icons.person_outline,
      color: const Color(0xFFEC4899),
    ),
    Folder(
      id: 'ideas',
      name: 'Ideas',
      icon: Icons.lightbulb_outline,
      color: const Color(0xFFEAB308),
    ),
    Folder(
      id: 'voice',
      name: 'Voice Notes',
      icon: Icons.mic_none,
      color: const Color(0xFF22C55E),
      hasAI: true,
    ),
    Folder(
      id: 'favorites',
      name: 'Favorites',
      icon: Icons.star_outline,
      color: const Color(0xFFF97316),
      isSystem: true,
    ),
    Folder(
      id: 'locked',
      name: 'Locked',
      icon: Icons.lock_outline,
      color: const Color(0xFF6B7280),
      isSystem: true,
    ),
  ];
}

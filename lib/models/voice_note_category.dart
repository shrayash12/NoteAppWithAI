import 'package:flutter/material.dart';

/// A voice note category used by Smart Voice Note's offline classifier to
/// route transcribed recordings into the right folder.
class VoiceNoteCategory {
  final String id;
  final String displayName;
  final IconData icon;
  final Color color;
  final String folderId;
  final List<String> keywords;

  const VoiceNoteCategory({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.folderId,
    required this.keywords,
  });

  static const meeting = VoiceNoteCategory(
    id: 'meeting',
    displayName: 'Meeting',
    icon: Icons.groups_outlined,
    color: Color(0xFF3B82F6),
    folderId: 'meeting',
    keywords: ['meeting', 'agenda', 'attendees', 'minutes', 'discussed', 'action item', 'follow up', 'standup', 'sync up'],
  );

  static const todo = VoiceNoteCategory(
    id: 'todo',
    displayName: 'To-Do',
    icon: Icons.check_circle_outline,
    color: Color(0xFF10B981),
    folderId: 'todo',
    keywords: ['to-do', 'todo', 'need to', 'remember to', "don't forget", 'must do', 'task list', 'reminder to'],
  );

  static const grocery = VoiceNoteCategory(
    id: 'grocery',
    displayName: 'Grocery',
    icon: Icons.local_grocery_store_outlined,
    color: Color(0xFF84CC16),
    folderId: 'grocery',
    keywords: ['grocery', 'groceries', 'supermarket', 'grocery store', 'grocery list', 'milk', 'eggs', 'bread', 'vegetables', 'fruits', 'produce'],
  );

  static const shopping = VoiceNoteCategory(
    id: 'shopping',
    displayName: 'Shopping',
    icon: Icons.shopping_cart_outlined,
    color: Color(0xFFF59E0B),
    folderId: 'shopping',
    keywords: ['buy', 'shopping', 'purchase', 'clothes', 'shirt', 'shoes', 'toy', 'toys', 'book', 'order online', 'mall', 'gift', 'amazon'],
  );

  static const health = VoiceNoteCategory(
    id: 'health',
    displayName: 'Health',
    icon: Icons.favorite_outline,
    color: Color(0xFFEF4444),
    folderId: 'health',
    keywords: ['doctor', 'appointment', 'medication', 'symptom', 'prescription', 'hospital', 'clinic', 'dose', 'diagnosis'],
  );

  static const travel = VoiceNoteCategory(
    id: 'travel',
    displayName: 'Travel',
    icon: Icons.flight_outlined,
    color: Color(0xFF06B6D4),
    folderId: 'travel',
    keywords: ['flight', 'trip', 'travel', 'hotel', 'itinerary', 'vacation', 'booking', 'passport', 'airport'],
  );

  static const study = VoiceNoteCategory(
    id: 'study',
    displayName: 'Study',
    icon: Icons.school_outlined,
    color: Color(0xFF8B5CF6),
    folderId: 'study',
    keywords: ['study', 'exam', 'lecture', 'homework', 'assignment', 'chapter', 'professor', 'quiz', 'syllabus'],
  );

  static const work = VoiceNoteCategory(
    id: 'work',
    displayName: 'Work',
    icon: Icons.work_outline,
    color: Color(0xFF3B82F6),
    folderId: 'work',
    keywords: ['deadline', 'client', 'boss', 'office', 'colleague', 'report', 'presentation', 'quarterly'],
  );

  static const finance = VoiceNoteCategory(
    id: 'finance',
    displayName: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF059669),
    folderId: 'finance',
    keywords: ['budget', 'expense', 'payment', 'invoice', 'bank', 'salary', 'bill', 'tax', 'investment'],
  );

  static const journal = VoiceNoteCategory(
    id: 'journal',
    displayName: 'Journal',
    icon: Icons.book_outlined,
    color: Color(0xFFD946EF),
    folderId: 'journal',
    keywords: ['today i', 'feeling', 'diary', 'journal', 'grateful', 'reflect', 'my mood', 'i felt'],
  );

  static const ideas = VoiceNoteCategory(
    id: 'ideas',
    displayName: 'Ideas',
    icon: Icons.lightbulb_outline,
    color: Color(0xFFEAB308),
    folderId: 'ideas',
    keywords: ['idea', 'what if', 'concept', 'brainstorm', 'innovation', 'occurred to me'],
  );

  static const recipe = VoiceNoteCategory(
    id: 'recipe',
    displayName: 'Recipe',
    icon: Icons.restaurant_outlined,
    color: Color(0xFFF97316),
    folderId: 'recipe',
    keywords: ['recipe', 'ingredients', 'cook', 'bake', 'cup of', 'tablespoon', 'teaspoon', 'oven', 'preheat'],
  );

  static const fitness = VoiceNoteCategory(
    id: 'fitness',
    displayName: 'Fitness',
    icon: Icons.fitness_center_outlined,
    color: Color(0xFFDC2626),
    folderId: 'fitness',
    keywords: ['workout', 'gym', 'exercise', 'reps', 'sets', 'cardio', 'training', 'muscle', 'run today'],
  );

  static const personal = VoiceNoteCategory(
    id: 'personal',
    displayName: 'Personal',
    icon: Icons.person_outline,
    color: Color(0xFFEC4899),
    folderId: 'personal',
    keywords: ['my family', 'my friend', 'at home', 'relationship', 'personal life'],
  );

  static const project = VoiceNoteCategory(
    id: 'project',
    displayName: 'Project',
    icon: Icons.folder_special_outlined,
    color: Color(0xFF6366F1),
    folderId: 'project',
    keywords: ['project', 'milestone', 'sprint', 'deliverable', 'roadmap', 'project plan', 'kickoff'],
  );

  static const quickNote = VoiceNoteCategory(
    id: 'quick_note',
    displayName: 'Quick Note',
    icon: Icons.mic_none_outlined,
    color: Color(0xFF6B7280),
    folderId: 'quick_note',
    keywords: [],
  );

  /// All categories considered during classification, in priority order.
  /// [quickNote] is intentionally excluded — it's the fallback when nothing
  /// else scores above threshold.
  static const List<VoiceNoteCategory> all = [
    meeting,
    todo,
    grocery,
    shopping,
    health,
    travel,
    study,
    work,
    finance,
    journal,
    ideas,
    recipe,
    fitness,
    personal,
    project,
  ];
}

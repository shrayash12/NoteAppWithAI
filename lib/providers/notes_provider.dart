import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import '../utils/notification_service.dart';

enum SortOrder { newest, oldest, alphabetical }

class NoteFilter {
  final Set<NoteType> noteTypes;
  final bool? isPinned;
  final bool? isFavorite;
  final bool? isLocked;
  final SortOrder sortOrder;

  const NoteFilter({
    this.noteTypes = const {},
    this.isPinned,
    this.isFavorite,
    this.isLocked,
    this.sortOrder = SortOrder.newest,
  });

  NoteFilter copyWith({
    Set<NoteType>? noteTypes,
    bool? isPinned,
    bool? isFavorite,
    bool? isLocked,
    SortOrder? sortOrder,
    bool clearPinned = false,
    bool clearFavorite = false,
    bool clearLocked = false,
  }) {
    return NoteFilter(
      noteTypes: noteTypes ?? this.noteTypes,
      isPinned: clearPinned ? null : (isPinned ?? this.isPinned),
      isFavorite: clearFavorite ? null : (isFavorite ?? this.isFavorite),
      isLocked: clearLocked ? null : (isLocked ?? this.isLocked),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasActiveFilters =>
      noteTypes.isNotEmpty ||
      isPinned != null ||
      isFavorite != null ||
      isLocked != null;

  static const NoteFilter none = NoteFilter();
}

class NotesProvider extends ChangeNotifier {
  List<Note> _notes = [];
  List<String> _customOrder = []; // persisted drag-and-drop order (note IDs)
  bool _isDarkMode = false;
  int _themeColorIndex = 21;
  bool _notificationsEnabled = true;
  bool _appLockEnabled = false;
  bool _biometricEnabled = true;
  bool _isGridView = false;
  bool _isLoading = true;
  bool _remindersRescheduled = false;
  String _searchQuery = '';
  NoteFilter _filter = NoteFilter.none;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  // Per-user Firestore path
  String? _userId;
  CollectionReference get _notesCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(_userId!)
      .collection('notes');

  // Stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _notesSubscription;

  List<Note> get notes => _notes;
  bool get isDarkMode => _isDarkMode;
  int get themeColorIndex => _themeColorIndex;
  bool get notificationsEnabled => _notificationsEnabled;
  TimeOfDay get reminderTime => _reminderTime;
  bool get appLockEnabled => _appLockEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get isGridView => _isGridView;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  NoteFilter get filter => _filter;
  bool get hasActiveFilters => _filter.hasActiveFilters;

  // Search notes by title, content, or OCR text
  List<Note> searchNotes(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _notes.where((note) {
      return note.title.toLowerCase().contains(lowerQuery) ||
          note.content.toLowerCase().contains(lowerQuery) ||
          (note.ocrText?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Targeted update of OCR text — avoids overwriting other fields
  Future<void> updateNoteOcrText(String noteId, String? ocrText) async {
    try {
      await _notesCollection.doc(noteId).update({'ocrText': ocrText});
    } catch (e) {
      debugPrint('Error updating OCR text in Firestore: $e');
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // Filter methods
  void setFilter(NoteFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearFilters() {
    _filter = NoteFilter.none;
    notifyListeners();
  }

  void toggleNoteTypeFilter(NoteType type) {
    final newTypes = Set<NoteType>.from(_filter.noteTypes);
    if (newTypes.contains(type)) {
      newTypes.remove(type);
    } else {
      newTypes.add(type);
    }
    _filter = _filter.copyWith(noteTypes: newTypes);
    notifyListeners();
  }

  void setSortOrder(SortOrder order) {
    _filter = _filter.copyWith(sortOrder: order);
    notifyListeners();
  }

  void togglePinnedFilter() {
    if (_filter.isPinned == true) {
      _filter = _filter.copyWith(clearPinned: true);
    } else {
      _filter = _filter.copyWith(isPinned: true);
    }
    notifyListeners();
  }

  void toggleFavoriteFilter() {
    if (_filter.isFavorite == true) {
      _filter = _filter.copyWith(clearFavorite: true);
    } else {
      _filter = _filter.copyWith(isFavorite: true);
    }
    notifyListeners();
  }

  void toggleLockedFilter() {
    if (_filter.isLocked == true) {
      _filter = _filter.copyWith(clearLocked: true);
    } else {
      _filter = _filter.copyWith(isLocked: true);
    }
    notifyListeners();
  }

  List<Note> applyFilters(List<Note> notes) {
    var filtered = notes.toList();

    // Filter by note type
    if (_filter.noteTypes.isNotEmpty) {
      filtered = filtered.where((n) => _filter.noteTypes.contains(n.type)).toList();
    }

    // Filter by status
    if (_filter.isPinned == true) {
      filtered = filtered.where((n) => n.isPinned).toList();
    }
    if (_filter.isFavorite == true) {
      filtered = filtered.where((n) => n.isFavorite).toList();
    }
    if (_filter.isLocked == true) {
      filtered = filtered.where((n) => n.isLocked).toList();
    }

    // Sort
    switch (_filter.sortOrder) {
      case SortOrder.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOrder.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOrder.alphabetical:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }

    // Pinned notes always first
    filtered.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    return filtered;
  }

  // Get filtered notes for display
  List<Note> get filteredNotes => applyFilters(_notes);

  // Stats
  int get totalNotes => _notes.length;
  int get voiceNotes => _notes.where((n) => n.type == NoteType.voice).length;
  int get favoriteNotes => _notes.where((n) => n.isFavorite).length;
  int get pinnedNotes => _notes.where((n) => n.isPinned).length;
  int get lockedNotes => _notes.where((n) => n.isLocked).length;
  int get documentNotes => _notes.where((n) => n.type == NoteType.document).length;
  List<Note> get documentNotesList => _notes.where((n) => n.type == NoteType.document).toList();

  // Filtered notes
  List<Note> get allNotes => _notes;
  List<Note> get pinnedNotesList => _notes.where((n) => n.isPinned).toList();
  List<Note> get voiceNotesList =>
      _notes.where((n) => n.type == NoteType.voice).toList();
  List<Note> get favoriteNotesList =>
      _notes.where((n) => n.isFavorite).toList();
  List<Note> get lockedNotesList => _notes.where((n) => n.isLocked).toList();

  List<Note> getNotesByFolder(String folderId) {
    switch (folderId) {
      case 'all':
        return _notes;
      case 'voice':
        return voiceNotesList;
      case 'favorites':
        return favoriteNotesList;
      case 'locked':
        return lockedNotesList;
      default:
        return _notes.where((n) => n.folderId == folderId).toList();
    }
  }

  int getNoteCountByFolder(String folderId) {
    return getNotesByFolder(folderId).length;
  }

  // ── Custom order helpers ─────────────────────────────────────────────────

  Future<void> _loadCustomOrder() async {
    final prefs = await SharedPreferences.getInstance();
    _customOrder = prefs.getStringList('notes_custom_order') ?? [];
  }

  Future<void> _saveCustomOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'notes_custom_order', _notes.map((n) => n.id).toList());
  }

  /// Sorts [notes] in-place according to the saved custom order.
  /// Notes not yet in the saved order (e.g. newly created) appear at the end.
  void _applyCustomOrder(List<Note> notes) {
    if (_customOrder.isEmpty) return;
    final orderMap = <String, int>{
      for (var i = 0; i < _customOrder.length; i++) _customOrder[i]: i
    };
    notes.sort((a, b) {
      final aIdx = orderMap[a.id] ?? _customOrder.length;
      final bIdx = orderMap[b.id] ?? _customOrder.length;
      return aIdx.compareTo(bIdx);
    });
  }

  // ── Preferences only (call before auth so login screen uses saved theme) ──

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    _themeColorIndex = prefs.getInt('themeColorIndex') ?? 21;
    notifyListeners();
  }

  // ── Load notes from Firestore with real-time updates ─────────────────────

  /// Call this after the user signs in.
  Future<void> loadNotes({required String userId}) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    _themeColorIndex = prefs.getInt('themeColorIndex') ?? 21;
    _notificationsEnabled = prefs.getBool('notifications') ?? true;
    _appLockEnabled = prefs.getBool('appLock') ?? false;
    _biometricEnabled = prefs.getBool('biometric') ?? true;
    _isGridView = prefs.getBool('gridView') ?? false;
    final reminderHour = prefs.getInt('reminderHour') ?? 9;
    final reminderMinute = prefs.getInt('reminderMinute') ?? 0;
    _reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);
    // Reschedule on every app start in case it was lost after reboot/update
    if (_notificationsEnabled) {
      await NotificationService.scheduleDailyReminder(_reminderTime);
    }
    // Load persisted drag-and-drop order before first Firestore snapshot
    await _loadCustomOrder();

    // Set up real-time listener for Firestore
    _notesSubscription?.cancel();
    _notesSubscription = _notesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Note.fromFirestore(data, doc.id);
      }).toList();
      _applyCustomOrder(_notes); // restore drag-and-drop order
      _isLoading = false;
      if (!_remindersRescheduled) {
        _remindersRescheduled = true;
        final now = DateTime.now();
        for (final note in _notes) {
          if (note.reminderDateTime != null && note.reminderDateTime!.isAfter(now)) {
            NotificationService.scheduleNoteReminder(
              noteId: note.id,
              noteTitle: note.title,
              reminderTime: note.reminderDateTime!,
            );
          }
        }
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error loading notes from Firestore: $error');
      _isLoading = false;
      notifyListeners();
    });

    notifyListeners();
  }

  /// Call this when the user signs out — clears all in-memory state.
  Future<void> clearOnSignOut() async {
    _notesSubscription?.cancel();
    _notesSubscription = null;
    _notes = [];
    _customOrder = [];
    _userId = null;
    _isLoading = true;
    _remindersRescheduled = false;
    _searchQuery = '';
    _filter = NoteFilter.none;
    notifyListeners();
  }

  @override
  void dispose() {
    _notesSubscription?.cancel();
    super.dispose();
  }

  Future<void> toggleGridView() async {
    _isGridView = !_isGridView;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gridView', _isGridView);
    notifyListeners();
  }

  // Add note to Firestore
  Future<void> addNote(Note note) async {
    try {
      await _notesCollection.doc(note.id).set(note.toFirestore());
      if (note.reminderDateTime != null) {
        await NotificationService.scheduleNoteReminder(
          noteId: note.id,
          noteTitle: note.title,
          reminderTime: note.reminderDateTime!,
        );
      }
    } catch (e) {
      debugPrint('Error adding note to Firestore: $e');
      rethrow;
    }
  }

  // Update note in Firestore
  Future<void> updateNote(Note note) async {
    try {
      await _notesCollection.doc(note.id).update(note.toFirestore());
      await NotificationService.cancelNoteReminder(note.id);
      if (note.reminderDateTime != null) {
        await NotificationService.scheduleNoteReminder(
          noteId: note.id,
          noteTitle: note.title,
          reminderTime: note.reminderDateTime!,
        );
      }
    } catch (e) {
      debugPrint('Error updating note in Firestore: $e');
      rethrow;
    }
  }

  // Delete note from Firestore
  Future<void> deleteNote(String id) async {
    try {
      await NotificationService.cancelNoteReminder(id);
      await _notesCollection.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting note from Firestore: $e');
      rethrow;
    }
  }

  Future<void> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final updatedNote = _notes[index].copyWith(isPinned: !_notes[index].isPinned);
      await updateNote(updatedNote);
    }
  }

  Future<void> toggleFavorite(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final updatedNote = _notes[index].copyWith(isFavorite: !_notes[index].isFavorite);
      await updateNote(updatedNote);
    }
  }

  Future<void> toggleLock(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final updatedNote = _notes[index].copyWith(isLocked: !_notes[index].isLocked);
      await updateNote(updatedNote);
    }
  }

  Future<void> reorderNotes(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final note = _notes.removeAt(oldIndex);
    _notes.insert(newIndex, note);
    _customOrder = _notes.map((n) => n.id).toList();
    notifyListeners();
    await _saveCustomOrder(); // persist so order survives screen switches & restarts
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    notifyListeners();
  }

  Future<void> setThemeColor(int index) async {
    _themeColorIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColorIndex', index);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    notifyListeners();

    if (value) {
      final granted = await NotificationService.requestPermissions();
      if (granted) {
        await NotificationService.scheduleDailyReminder(_reminderTime);
        await NotificationService.showInstantNotification(
          title: 'Notifications Enabled',
          body: 'You\'ll receive a daily reminder at ${_formatTime(_reminderTime)}.',
        );
      }
    } else {
      await NotificationService.cancelAll();
    }
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    _reminderTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminderHour', time.hour);
    await prefs.setInt('reminderMinute', time.minute);
    notifyListeners();
    if (_notificationsEnabled) {
      await NotificationService.scheduleDailyReminder(time);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> setAppLock(bool value) async {
    _appLockEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('appLock', value);
    notifyListeners();
  }

  Future<void> setBiometric(bool value) async {
    _biometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric', value);
    notifyListeners();
  }

  Note createNote({
    required String title,
    String content = '',
    required NoteType type,
    String? folderId,
    String? voicePath,
    String? imagePath,
    String? pdfPath,
    List<ChecklistItem>? checklistItems,
  }) {
    final now = DateTime.now();
    return Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      type: type,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
      voicePath: voicePath,
      imagePath: imagePath,
      pdfPath: pdfPath,
      checklistItems: checklistItems,
    );
  }
}

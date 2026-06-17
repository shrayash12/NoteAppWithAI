# SmartNotes — Project Context

## Overview
SmartNotes is a Flutter-based cross-platform note-taking app with AI-powered note types, Firebase cloud sync, and a polished Material Design 3 UI. Supports Android, iOS, macOS, and Chrome (web).

**Version:** 1.0.0+1
**Flutter SDK:** >=3.0.0 <4.0.0

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| State Management | Provider (`ChangeNotifier`) |
| Backend | Firebase Firestore (data) + Firebase Storage (files) |
| Local Storage | `shared_preferences` |
| Audio | `record` (recording) + `audioplayers` (playback) |
| Images | `image_picker` |
| IDs | `uuid` v4 |
| Theming | Material Design 3 |

---

## Project Structure

```
lib/
├── main.dart                    # App entry point, Firebase init, Provider setup
├── firebase_options.dart        # Firebase platform config (auto-generated)
├── models/
│   └── note.dart                # Note, ChecklistItem, Folder, NoteColor, NoteType
├── providers/
│   └── notes_provider.dart      # NotesProvider — all state, Firestore CRUD, filters
├── screens/
│   ├── main_screen.dart         # Shell with bottom nav + FAB routing
│   ├── home_screen.dart         # Notes list/grid, search, filter chips
│   ├── folders_screen.dart      # Folder list view
│   ├── folder_detail_screen.dart# Notes within a specific folder
│   ├── voice_screen.dart        # Voice recording + playback UI
│   ├── text_note_screen.dart    # Text note editor
│   ├── drawing_screen.dart      # Drawing/sketch note
│   ├── checklist_screen.dart    # Checklist note editor
│   └── settings_screen.dart     # Dark mode, notifications, lock, biometrics
├── widgets/
│   ├── bottom_nav_bar.dart      # Custom bottom nav with center FAB
│   ├── create_note_modal.dart   # Note type picker modal
│   ├── filter_bottom_sheet.dart # Filter/sort bottom sheet
│   ├── gradient_header.dart     # Purple-magenta-pink gradient header
│   ├── voice_recording_modal.dart
│   ├── photo_note_modal.dart
│   ├── photo_preview_modal.dart
│   └── animated_notification.dart
├── theme/
│   └── app_theme.dart           # Light/dark ThemeData + color constants + gradients
└── utils/
    ├── storage_helper.dart      # Firebase Storage upload/download helpers
    ├── image_helper.dart        # Image picking/processing
    ├── file_helper.dart         # Conditional import shim
    ├── file_helper_io.dart      # IO-specific file ops
    └── file_helper_stub.dart    # Web stub for file ops
```

---

## Data Models

### `Note`
| Field | Type | Description |
|-------|------|-------------|
| `id` | `String` | UUID v4 (used as Firestore document ID) |
| `title` | `String` | Note title |
| `content` | `String` | Text body |
| `type` | `NoteType` | text / voice / drawing / photo / checklist |
| `createdAt` | `DateTime` | Creation timestamp |
| `updatedAt` | `DateTime` | Last modified timestamp |
| `folderId` | `String?` | Folder ID (null = no folder) |
| `isPinned` | `bool` | Pinned to top |
| `isFavorite` | `bool` | Starred |
| `isLocked` | `bool` | Locked/private |
| `voicePath` | `String?` | Firebase Storage URL or local path |
| `imagePath` | `String?` | Firebase Storage URL or local path |
| `checklistItems` | `List<ChecklistItem>?` | Checklist entries |
| `colorIndex` | `int` | -1 = default pink; 0–6 = NoteColor.colors |
| `tags` | `List<String>` | Tag labels |

### `NoteType` enum
`text`, `voice`, `drawing`, `photo`, `checklist` (stored as index in Firestore)

### `NoteColor` (7 colors + 1 default)
Yellow, White, Blue, Green, Purple, Orange, Gray + default Pink (`0xFFFCE7F3`)

### `ChecklistItem`
`id` (String), `text` (String), `isChecked` (bool)

### `Folder` (7 default folders)
| ID | Name | System? |
|----|------|---------|
| `all` | All Notes | Yes |
| `work` | Work | No |
| `personal` | Personal | No |
| `ideas` | Ideas | No |
| `voice` | Voice Notes | No |
| `favorites` | Favorites | Yes |
| `locked` | Locked | Yes |

System folders (`all`, `favorites`, `locked`) filter by note properties rather than `folderId`.

---

## State Management — `NotesProvider`

Single `ChangeNotifier` registered at app root. Key responsibilities:

- **Firestore sync**: Real-time `StreamSubscription` on `notes` collection ordered by `createdAt desc`
- **CRUD**: `addNote`, `updateNote`, `deleteNote` → all go directly to Firestore
- **Filtering**: `NoteFilter` with `noteTypes`, `isPinned`, `isFavorite`, `isLocked`, `SortOrder`
- **Search**: `searchNotes(query)` — title + content substring match
- **Settings** (persisted via `SharedPreferences`): `isDarkMode`, `isGridView`, `notificationsEnabled`, `appLockEnabled`, `biometricEnabled`
- **Quick toggles**: `togglePin`, `toggleFavorite`, `toggleLock` — update Firestore in place

### `NoteFilter`
```dart
enum SortOrder { newest, oldest, alphabetical }

class NoteFilter {
  Set<NoteType> noteTypes;  // filter by type(s)
  bool? isPinned;
  bool? isFavorite;
  bool? isLocked;
  SortOrder sortOrder;
}
```

---

## Navigation

`MainScreen` hosts 4 bottom nav tabs + a center FAB:

| Index | Tab | Screen |
|-------|-----|--------|
| 0 | Home | `HomeScreen` |
| 1 | Folders | `FoldersScreen` |
| 2 | Voice | `VoiceScreen` |
| 3 | Settings | `SettingsScreen` |

FAB → `CreateNoteModal` → routes to the appropriate note creation screen/modal.

---

## Theming

**Primary gradient**: Purple `#8B5CF6` → Magenta `#D946EF` → Pink `#EC4899` (used in header + FAB)

**Light mode**: Background `#F5F5F5`, cards white, text `#1F2937`
**Dark mode**: Background `#0F172A`, cards `#1E293B`, text `#F1F5F9`

`AppTheme` provides static helper methods (`getBackgroundColor`, `getCardColor`, etc.) that read from the current `BuildContext` brightness.

---

## Firebase

- **Firestore collection**: `notes` — documents use UUID as doc ID
- **Serialization**: `toFirestore()` / `fromFirestore()` — dates stored as `Timestamp`, type as index int
- **Storage**: Used for voice recordings and photo notes (paths stored in note fields)
- **Real-time**: Notes stream on app start, auto-updates UI on any remote change

---

## Key Patterns

- All screens access state via `Provider.of<NotesProvider>(context)`
- `Note` is immutable — use `copyWith()` to produce updates
- `reorderNotes` is local-only (Firestore doesn't support custom order easily)
- File helpers use conditional imports (`file_helper.dart`) for web/IO platform split
- Settings are saved to `SharedPreferences` immediately on change

---

## Changelog

### 2026-06-17 — Import Notes Feature

#### Added
- **`lib/widgets/import_notes_sheet.dart`** — New bottom sheet widget for importing notes from external apps
  - **Google Keep** import: parses `.json` files exported via Google Takeout
    - Preserves title, content, pinned state, checklist items, labels (as tags), and timestamps
    - Trashed notes are automatically skipped
    - Checklist notes imported as `NoteType.checklist` with `ChecklistItem` list
  - **Text / Markdown** import: parses `.txt` and `.md` files
    - First `#` heading in `.md` files used as note title
    - Works with Apple Notes, Obsidian, Notion, Bear exports

#### Modified
- **`lib/screens/settings_screen.dart`**
  - Added `DATA` section below Security
  - Added `Import Notes` tile → opens `ImportNotesSheet` as modal bottom sheet
- **`pubspec.yaml`**
  - Added `file_picker: ^8.0.0` dependency
- **`.gitignore`**
  - Added `google-services.json`, `GoogleService-Info.plist`, `lib/firebase_options.dart` to prevent Firebase secrets from being committed

#### Bug Fix (same session)
- **`lib/widgets/import_notes_sheet.dart`** — Fixed file picker not responding on Android 9 (Moto G8, API 28)
  - Root cause: `FileType.custom` with `allowedExtensions` silently fails on older Android due to SAF MIME type filtering limitations
  - Fix: switched to `FileType.any` + `withData: true`, filter by file extension after picking
  - Added `try-catch` around `FilePicker.platform.pickFiles()` with user-facing SnackBar error messages
  - Added orange SnackBar guidance when wrong file type is selected
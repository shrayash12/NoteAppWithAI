# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SmartNotes is a Flutter cross-platform note-taking app with AI-powered features including voice recording, photo capture, drawing, and checklists. Uses Firebase (Firestore + Storage) for cloud sync.

## Common Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run in debug mode
flutter run -d chrome        # Run in Chrome browser
flutter build apk            # Build Android APK
flutter test                 # Run all tests
flutter test test/widget_test.dart  # Run single test file
flutter analyze              # Lint code
```

## Architecture

**State Management**: Provider pattern with ChangeNotifier (`lib/providers/notes_provider.dart`)
- Real-time Firestore sync via StreamSubscription
- Handles notes CRUD, filtering, search, and app settings (dark mode, grid view, etc.)

**Data Models** (`lib/models/note.dart`):
- `Note` - Core model with JSON/Firestore serialization
- `NoteType` enum: text, voice, drawing, photo, checklist
- `Folder` - 7 default folders including system folders (All Notes, Favorites, Locked, Voice Notes)
- `NoteColor` - 7 color themes

**UI Layer**:
- `lib/screens/` - Full-page StatefulWidget screens (9 screens)
- `lib/widgets/` - Reusable components: modals, bottom sheets, navigation (8 widgets)
- `lib/theme/app_theme.dart` - Light/dark theme definitions using Material Design 3

**Key Dependencies**:
- `provider` - State management
- `cloud_firestore` + `firebase_storage` - Backend
- `shared_preferences` - Local settings persistence
- `record` + `audioplayers` - Voice notes
- `image_picker` - Photo notes

## Code Patterns

- Notes use UUID for unique IDs
- Firestore collection: `notes` with real-time listeners
- Filter system supports: note type, pin status, favorite, locked status, sort order
- All screens access state via `Provider.of<NotesProvider>(context)`

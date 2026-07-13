import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'models/note.dart';
import 'providers/notes_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/auth_wrapper.dart';
import 'screens/main_screen.dart';
import 'screens/text_note_screen.dart';
import 'screens/checklist_screen.dart';
import 'theme/app_theme.dart';
import 'utils/notification_service.dart';
import 'widgets/photo_preview_modal.dart';
import 'widgets/document_note_modal.dart';
import 'widgets/shimmer_widgets.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GoogleSignIn.instance.initialize(
    serverClientId:
        '186920755881-n58ca34cch9f2rfd280j8mtfqb1ts22d.apps.googleusercontent.com',
  );
  GoogleSignIn.instance.authenticationEvents.listen((event) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      final idToken = event.user.authentication.idToken;
      if (idToken != null && FirebaseAuth.instance.currentUser == null) {
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    }
  });

  await NotificationService.initialize();

  NotificationService.noteTapStream.listen((noteId) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final provider = ctx.read<NotesProvider>();
    final note = provider.notes.cast<Note?>().firstWhere(
      (n) => n?.id == noteId,
      orElse: () => null,
    );
    if (note != null) _openNoteFromNotification(ctx, note);
  });

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SmartNotesApp());
}

void _openNoteFromNotification(BuildContext context, Note note) {
  switch (note.type) {
    case NoteType.text:
      showTextNoteModal(context, note: note);
      break;
    case NoteType.checklist:
      showChecklistModal(context, note: note);
      break;
    case NoteType.photo:
      showPhotoPreviewModal(context, note);
      break;
    case NoteType.document:
      showDocumentNoteModal(context, note);
      break;
    default:
      // For voice and drawing, open as text note fallback
      showTextNoteModal(context, note: note);
      break;
  }
}

class SmartNotesApp extends StatelessWidget {
  const SmartNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NotesProvider()..loadPreferences(),
        ),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<NotesProvider, LocaleProvider>(
        builder: (context, notesProvider, localeProvider, child) {
          return MaterialApp(
            title: 'SmartNotes',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme(AppTheme.accentColor(notesProvider.themeColorIndex)),
            darkTheme: AppTheme.darkTheme(AppTheme.accentColor(notesProvider.themeColorIndex)),
            themeMode:
                notesProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: localeProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

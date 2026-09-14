import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../providers/usage_provider.dart';
import '../services/subscription_service.dart';
import '../widgets/shimmer_widgets.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _splashDone = false;
  User? _pendingUser; // user waiting for splash to finish before loading notes

  @override
  void initState() {
    super.initState();

    // Always show splash for at least 2.5s so animations are visible
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _splashDone = true);
      // If a user was already detected during splash, load their notes now
      if (_pendingUser != null) {
        context.read<NotesProvider>().loadNotes(userId: _pendingUser!.uid);
      }
    });

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;
      final notesProvider = context.read<NotesProvider>();
      final usageProvider = context.read<UsageProvider>();
      if (user != null) {
        // A guest who just completed real sign-in — copy their local notes
        // into the new account before the Firestore stream takes over.
        if (notesProvider.isGuestMode) {
          await notesProvider.migrateGuestNotesToFirestore(user.uid);
        }
        SubscriptionService.login(user.uid);
        usageProvider.refresh();
        if (_splashDone) {
          // Splash already done — load immediately (e.g. user just signed in)
          notesProvider.loadNotes(userId: user.uid);
        } else {
          // Still showing splash — defer until splash completes
          _pendingUser = user;
        }
      } else {
        _pendingUser = null;
        // Guests never sign in to Firebase, so this stream also fires with
        // a null user for them — don't wipe their just-loaded local notes.
        if (!notesProvider.isGuestMode) {
          notesProvider.clearOnSignOut();
        }
        usageProvider.clear();
        SubscriptionService.logout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash until minimum time has passed AND auth is resolved
        if (!_splashDone || snapshot.connectionState == ConnectionState.waiting) {
          return const SplashAnimationScreen();
        }

        // Guest mode wins regardless of Firebase auth state, so a
        // relaunching guest lands straight in MainScreen.
        if (notesProvider.isGuestMode) {
          return const MainScreen();
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        // User is signed in — MainScreen handles its own shimmer internally
        return const MainScreen();
      },
    );
  }
}

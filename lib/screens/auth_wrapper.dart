import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
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
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final notesProvider = context.read<NotesProvider>();
      if (user != null) {
        if (_splashDone) {
          // Splash already done — load immediately (e.g. user just signed in)
          notesProvider.loadNotes(userId: user.uid);
        } else {
          // Still showing splash — defer until splash completes
          _pendingUser = user;
        }
      } else {
        _pendingUser = null;
        notesProvider.clearOnSignOut();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash until minimum time has passed AND auth is resolved
        if (!_splashDone || snapshot.connectionState == ConnectionState.waiting) {
          return const SplashAnimationScreen();
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

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Firebase startup state is deliberately separated from the UI startup.
/// The app can open even if Firebase is slow or unavailable.
class FirebaseBootstrap {
  FirebaseBootstrap._();
  static final FirebaseBootstrap instance = FirebaseBootstrap._();

  final ValueNotifier<bool> ready = ValueNotifier<bool>(Firebase.apps.isNotEmpty);
  bool _started = false;

  Future<void> start() async {
    if (_started || ready.value) return;
    _started = true;

    while (!ready.value) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
        ready.value = Firebase.apps.isNotEmpty;
        if (ready.value) return;
      } catch (_) {
        // Firebase initialization failures must never block the app UI.
      }

      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  void dispose() => ready.dispose();
}

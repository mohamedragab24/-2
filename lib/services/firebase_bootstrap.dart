import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Coordinates Firebase startup without calling FlutterFire Core on Android.
/// Android initializes the native FirebaseApp first through MainActivity.
class FirebaseBootstrap {
  FirebaseBootstrap._();
  static final FirebaseBootstrap instance = FirebaseBootstrap._();

  static const MethodChannel _nativeChannel =
      MethodChannel('masar_app/firebase');

  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  Future<void>? _running;

  Future<void> start() {
    if (ready.value) return Future<void>.value();
    return _running ??= _start();
  }

  Future<void> _start() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        Object? lastError;
        for (var attempt = 0; attempt < 8; attempt++) {
          try {
            final result = await _nativeChannel
                .invokeMethod<bool>('ensureInitialized')
                .timeout(const Duration(seconds: 3));
            if (result == true) {
              ready.value = true;
              error.value = null;
              return;
            }
            lastError = 'Native FirebaseApp was not initialized.';
          } catch (e) {
            lastError = e;
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        throw StateError('تعذر تهيئة Firebase على Android: $lastError');
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
      ready.value = true;
      error.value = null;
    } catch (e) {
      error.value = e.toString();
      ready.value = false;
      // Allow a later login attempt to retry startup instead of keeping a
      // permanently completed/failed Future.
      _running = null;
    }
  }

  Future<bool> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (ready.value) return true;

    final completer = Completer<bool>();
    Timer? timer;

    void listener() {
      if (ready.value && !completer.isCompleted) {
        completer.complete(true);
      }
    }

    ready.addListener(listener);
    unawaited(start());

    timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final result = await completer.future;
    ready.removeListener(listener);
    timer.cancel();
    return result;
  }

  String get lastError => error.value ?? '';

  void dispose() {
    ready.dispose();
    error.dispose();
  }
}

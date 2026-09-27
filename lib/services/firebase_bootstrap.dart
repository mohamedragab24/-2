import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Controls Firebase readiness without invoking the FlutterFire Core channel
/// on Android. Android Firebase is initialized natively by google-services.json.
class FirebaseBootstrap {
  FirebaseBootstrap._();
  static final FirebaseBootstrap instance = FirebaseBootstrap._();

  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  bool _started = false;
  Future<void>? _running;

  Future<void> start() {
    if (ready.value) return Future<void>.value();
    return _running ??= _start();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // FirebaseInitProvider initializes the native default FirebaseApp
        // before the Flutter engine. Do not call Firebase.initializeApp()
        // here: doing so previously produced a FlutterFire channel-error.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        ready.value = true;
        error.value = null;
        return;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      ready.value = true;
      error.value = null;
    } catch (e) {
      error.value = e.toString();
      ready.value = false;
    }
  }

  Future<bool> waitUntilReady({Duration timeout = const Duration(seconds: 30)}) async {
    if (ready.value) return true;

    final completer = Completer<bool>();
    Timer? timer;

    void listener() {
      if (ready.value && !completer.isCompleted) completer.complete(true);
    }

    ready.addListener(listener);
    unawaited(start());

    if (ready.value && !completer.isCompleted) completer.complete(true);

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

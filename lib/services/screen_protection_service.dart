import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Applies screen-capture protection app-wide (every screen, not just the
/// player) the moment the app starts.
///
/// Android: `FLAG_SECURE` is a real OS-level block — it stops screenshots
/// and screen recording outright, and blanks the app's preview in the
/// recent-apps switcher. Enabling it once at startup covers every screen
/// for the whole session, so nothing further is needed per-screen.
///
/// iOS: Apple gives apps no public API to block screenshots or recording
/// outright — this is an OS policy, not a Flutter/plugin limitation. What
/// IS possible is *detecting* both in real time and reacting immediately
/// (blank the screen, pause video). That detection is done in native
/// Swift (see ios/Runner/AppDelegate.swift) and streamed to Dart here.
class ScreenProtectionService {
  static const _channel = EventChannel('masar/screen_protection');
  StreamSubscription? _sub;

  final _blockController = StreamController<bool>.broadcast();

  /// Emits true when the UI should show the opaque "المحتوى محمي" cover
  /// (iOS screen recording in progress, or right after a screenshot).
  Stream<bool> get shouldBlockContent => _blockController.stream;

  Future<void> init() async {
    if (Platform.isAndroid) {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      return; // FLAG_SECURE alone is a full block — nothing else needed.
    }

    if (Platform.isIOS) {
      _sub = _channel.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          if (event['type'] == 'recording') {
            _blockController.add(event['active'] == true);
          } else if (event['type'] == 'screenshot') {
            // Can't be prevented on iOS — cover the content briefly and
            // rely on the sessions log (below) for anything more than that.
            _blockController.add(true);
            Future.delayed(const Duration(seconds: 2), () => _blockController.add(false));
          }
        }
      });
    }
  }

  void dispose() {
    _sub?.cancel();
    _blockController.close();
  }
}

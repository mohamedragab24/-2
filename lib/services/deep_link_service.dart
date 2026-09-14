import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

/// Handles links like https://YOURDOMAIN.com/course/123 (or the app's own
/// custom scheme masar://course/123 as a fallback).
///
/// Setup required outside this file (cannot be done from Dart alone):
///  Android — add an <intent-filter> with autoVerify="true" in
///    android/app/src/main/AndroidManifest.xml for your https domain, and
///    host a Digital Asset Links file at
///    https://YOURDOMAIN.com/.well-known/assetlinks.json
///  iOS — enable "Associated Domains" capability with
///    applinks:YOURDOMAIN.com in ios/Runner/Runner.entitlements, and host
///    https://YOURDOMAIN.com/.well-known/apple-app-site-association
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  void init(GoRouter router) {
    // Handle the link that launched the app (cold start).
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri, router);
    });

    // Handle links received while the app is already running.
    _sub = _appLinks.uriLinkStream.listen((uri) => _handle(uri, router));
  }

  void _handle(Uri uri, GoRouter router) {
    // Matches /course/123 or /courses/123 regardless of host.
    final segments = uri.pathSegments;
    final idx = segments.indexWhere((s) => s == 'course' || s == 'courses');
    if (idx != -1 && idx + 1 < segments.length) {
      final courseId = segments[idx + 1];
      router.push('/course/$courseId');
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}

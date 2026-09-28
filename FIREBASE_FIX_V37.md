# Firebase fix V37

## Root cause
V31/V36 stopped calling `Firebase.initializeApp()` on Android. But FlutterFire keeps its own
Dart-side registry of apps, so even with a native default app, `FirebaseAuth.instance` throws
`[core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()`.

## Fix
- `firebase_bootstrap.dart`: Dart `Firebase.initializeApp()` now runs on Android too (native check
  is best-effort), with retries, an options fallback, and a `Firebase.app()` verification.
  `waitUntilReady()` now retries instead of waiting passively.
- `android/app/build.gradle`: release build no longer minifies/shrinks (R8 can strip FlutterFire
  channel classes, which was the likely source of the old `channel-error`).
- `signup_screen.dart`: waits for Firebase and shows real error messages.

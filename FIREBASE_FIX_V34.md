# Firebase fix V34

## Root cause found in V33
V33 used Kotlin reflection:
`Class.forName("com.google.firebase.FirebaseApp")` and `getMethod("getApps", Context::class.java)`.
Release builds can obfuscate/rename methods, so reflection can fail with an error resembling `...FirebaseApp.getApps(Context)...`.

## V34 fix
- Added an explicit native Firebase App dependency using Firebase BoM 33.5.1.
- Replaced reflection with the direct `FirebaseApp.initializeApp(this)` API.
- `FirebaseInitProvider` can initialize the default app before MainActivity; calling `initializeApp` then safely reuses the existing default app.
- Dart still does NOT call `Firebase.initializeApp()` on Android, avoiding the previous FlutterFire channel-error path.
- Auth/Firestore/Messaging continue to use the native Firebase default app through FlutterFire plugins after readiness.

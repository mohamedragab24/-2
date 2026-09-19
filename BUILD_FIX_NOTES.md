# Build fix

The dependency conflict reported by `flutter pub get` was fixed by aligning
`firebase_messaging` with the Firebase Flutter BoM used by this project:

- firebase_core: ^3.6.0
- firebase_auth: ^5.3.1
- cloud_firestore: ^5.4.4
- cloud_functions: ^5.1.3
- firebase_storage: ^12.3.4
- firebase_messaging: 15.1.3

`firebase_messaging 16.2.0` requires `firebase_core ^4.7.0`, which was incompatible
with the project's Firebase 3.x generation.

Validation to run in a Flutter environment:
flutter clean
flutter pub get
flutter analyze
flutter build apk --release

This archive was statically inspected here; Flutter SDK/Gradle were not installed
in the execution environment, so the final APK build could not be executed here.

## Fix 2 - Flutter 3.24.5 / Jitsi
- Changed `jitsi_meet_flutter_sdk` from `^13.1.1` to `^11.6.0` because the installed Flutter SDK is 3.24.5 and newer Jitsi SDK versions require Flutter >=3.38.0.


v5 fixes: corrected Dart syntax in admin_control_center_screen.dart and meetings_tab.dart; removed unsupported minDate argument from showDatePicker for Flutter 3.24.5.


## v6
- Added the official Jitsi Maven repository to `android/settings.gradle` because the project uses `RepositoriesMode.PREFER_SETTINGS`; without it Gradle cannot resolve `org.jitsi.react:jitsi-meet-sdk:11.6.0`.
- Added `cupertino_icons` to silence the CupertinoIcons font asset warning. `uses-material-design: true` was already present.

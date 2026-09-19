# Build fix v8

- Raised Android `minSdk` from 24 to 26 because Jitsi Meet SDK 11.6.0 declares minSdk 26.
- Added `tools:replace="android:label"` to the application manifest to resolve the Jitsi manifest label conflict while keeping the app label `مسار`.
- The AndroidX/legacy support-library messages for Giphy and Media3 are warnings; they are not the build-stopping errors in the reported log.

Run:
flutter clean
flutter pub get
flutter analyze
flutter build apk --release --build-number 87 --build-name 1.0.87

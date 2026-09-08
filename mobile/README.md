# CrewClocker mobile

Read [build status](../docs/BUILD_STATUS.md) and the
[Android preview guide](../docs/ANDROID_PREVIEW.md) first.
The repository root preserves the original Kotlin prototype. Flutter builds run
from this `mobile` directory.

## Build requirements

- Flutter 3.47.2 / Dart 3.13.2 (pinned in the workflow)
- Java 17 and Android SDK
- Android device with API 26 or newer; the preview targets ARM64

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
dart test/tracking_standalone.dart
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/development.json
```

GitHub Actions performs the same checks and uploads an APK on development-branch
source changes. The APK is an engineering preview, not a payroll-ready app.

## Configuration

`config/development.json` reuses the prototype's Supabase URL and publishable
client key. It contains no server/service-role key. Other environments can supply
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` via Dart defines or a local JSON file.
Database authorization must be completed before real crew use.

Maps are off by default. To enable them in a configured build, set the
`ANDROID_MAPS_API_KEY` build environment variable and add
`--dart-define=MAPS_ENABLED=true`. Restrict that key to the preview package and
signing certificate. The server's address-search key must never be used here.

**Check this phone** is available before sign-in. It reads native status without
starting monitoring. Automated registration, upload, and payroll reconciliation
are still disabled or incomplete; see the build-status document.

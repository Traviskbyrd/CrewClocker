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
The field-test migrations are deployed and authorization checks pass; see build status for remaining production gates.

The field-test job editor uses OpenStreetMap tiles with visible attribution. Tap
the map to place a job pin; the address is a label, not geocoded. No Google Maps
key is required for this flow. The original Google Maps prototype remains in the
source but is not the active field-test editor.

**Check this phone** is available before sign-in and reads native status without
starting monitoring. After sign-in, create your company and a self-assigned test
site, follow the permission steps, and explicitly enable monitoring. Android
captures raw observations in SQLite; Flutter uploads them while open/resumed.
There is no native background upload worker or payroll reconciliation yet.

The workflow also runs `./gradlew :app:testDebugUnitTest` from `android` to test
journal persistence, exact acknowledgements, account handoff, and v1 migration.
The downloadable field APK is re-signed with the retained internal signing key.
A fresh CI debug artifact has a temporary certificate; do not distribute it as
an update to the signed field APK. The original 0.1 preview must be uninstalled
once before installing 0.2. Never commit signing credentials to this repository.

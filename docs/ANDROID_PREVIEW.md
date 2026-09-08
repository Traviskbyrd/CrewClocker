# CrewClocker Android engineering preview

Target phone: Samsung Galaxy S26 Ultra (ARM64).

This is an installation and native-connection check, not the finished Android
evaluation version. Automatic timekeeping remains disabled. Do not use it to
calculate payroll.

## Install and check

1. Download the successful workflow's `CrewClocker-Android-preview` ZIP on the phone.
2. Extract it with My Files, tap `CrewClocker-preview.apk`, and install.
3. Open **CrewClocker Preview**, then **Check this phone** before signing in.
4. Confirm **Android connection available: Yes** and that no tracking issue appears.
5. Close and reopen the app. Report any crash or installation error.

Location permissions can stay off for this first check. The diagnostic screen
does not request permissions, register sites, or write work records.

The preview has its own package (`com.tbyrd.crewclocker.preview`), so it can be
installed alongside the original Kotlin app. This is debug-signed for internal
testing. Separate CI runs may have different debug certificates; if Android
rejects a later update, preserve any needed app data before uninstalling the old
preview. Stable internal signing must be configured before field event testing.

## What is connected

- Flutter UI, native Android Activity and tracking method channel.
- Native SQLite journal and manifest-declared geofence receiver.
- Existing prototype Supabase URL and publishable client key, copied from the
  original app into `mobile/config/development.json`. This file contains no
  service-role/server secret. No backend migration or account was created.

## Still incomplete

Account invitations/provisioning, tenant isolation, job-write endpoint deployment,
restricted Android Maps key, tracking setup/assignment sync, boot recovery,
server event ingestion, manual time controls, manager approval and exports.
Do not interpret a successful compilation as proof of background reliability.

## Reproduce

Use Flutter 3.47.2, Java 17 and an Android SDK. From `mobile`:

```sh
flutter pub get --enforce-lockfile
flutter analyze
dart test/tracking_standalone.dart
flutter test
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=config/development.json
```

GitHub Actions runs these commands on the development branch. Output includes
the APK, this guide, and its SHA-256 checksum. The original root Android project
is preserved; all new Flutter builds run from `mobile`.

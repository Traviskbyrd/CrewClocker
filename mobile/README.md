# CrewClocker mobile source

Read ../docs/BUILD_STATUS.md before running. Platform generation and dependency
resolution are incomplete; this folder is not yet a buildable Flutter project.
The original repository root remains the old Kotlin prototype.

The dependency-free ledger checks can run with a supported Dart SDK:

    dart test/tracking_standalone.dart

After platform setup and dependency resolution in an approved build environment:

    flutter analyze
    flutter test

Build configuration will use SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY through
Dart defines. Never put a Supabase server/service key in the mobile build.
Android's Maps SDK key belongs in ignored local build configuration and must be
restricted to the Android package and signing fingerprint. Google address lookup
uses the server-side GOOGLE_MAPS_API_KEY secret; it is not sent to the app.

Do not connect this checkpoint to production crew timekeeping yet.

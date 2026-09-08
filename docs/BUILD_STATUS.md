# CrewClocker implementation checkpoint — 2026-09-08

## Android build work — 2026-09-08

Flutter 3.47.2 (Dart 3.13.2) is installed in the build session. The earlier SDK
blocker was resolved by using the official Flutter Git repository. Inspection
of Flutter's `bot_detector.dart` identified its automatic Azure metadata probe;
standard `CI=true` short-circuits that probe. No metadata service was contacted.
Archive extraction uses `TAR_OPTIONS=--no-same-owner` for this container.

Android platform source has been generated and the Activity now installs
TrackingChannel. Manifest declares location permissions and the private geofence
receiver. The preview package is `com.tbyrd.crewclocker.preview`, min SDK 26.
Flutter dependencies are locked in `mobile/pubspec.lock`; Maps requires Dart 3.10
or newer, so the declared lower bound was corrected. The Supabase initialization
uses the installed package's `publishableKey` parameter.

Local verification: `flutter analyze --no-pub` reports no issues. All four Flutter
tests pass (the original eleven logic checks plus three screen tests). The
standalone runner also reports eleven passing checks. No phone test has occurred.

The pre-sign-in Device check screen reads native health only. Maps and job editing
remain disabled until a restricted Android Maps key is configured; backend
configuration reuses the original prototype's URL and publishable key. No account
or schema was created and no live backend writes were performed.

GitHub build: https://github.com/Traviskbyrd/CrewClocker/actions/runs/34286786361
Result: SUCCESS. Android Kotlin/Gradle compilation and APK upload completed.
Built source commit: `1f705e29d7644eb5334c1324e237caed1cee657e`.
Artifact: https://github.com/Traviskbyrd/CrewClocker/actions/runs/34286786361/artifacts/10079926160
APK size: 83,778,293 bytes. SHA-256:
`996bf227788a8e6b6757d7685723ebdc02cdd085bcc42a03120b68a3a8d0c5fb`.
Downloaded archive digest matched GitHub; APK checksum matched the build's
checksum file. ZIP integrity and ARM64 Flutter library presence were checked.
A physical phone installation and background behavior remain UNTESTED.
Read `docs/ANDROID_PREVIEW.md` for scope, installation and remaining gates.

## Checkpoint transferred — 2026-09-08

The supplied patch was applied cleanly and saved to GitHub on
`codex/crewclocker-development` in commit
`2e9cb6ac7c99d940fc4ab3a05bb9df05a7039965`. Existing prototype files were
preserved. GitHub read/write access is now verified; the earlier access blocker
below is historical. Target Android evaluation phone: Samsung Galaxy S26 Ultra.

This runtime has Java but no Flutter or Dart executable on PATH. Fetching the
official Flutter Linux release manifest returned HTTP 404, so platform generation,
compilation and rerunning the eleven checks remain unverified in this session.
The eleven passing checks below describe the original checkpoint only.

## Original checkpoint status (historical)

This is the first source checkpoint, NOT the Android evaluation build and NOT an installable APK.
Base: Traviskbyrd/CrewClocker at 336ffaebe22293162252c70874fe5376d5ceb4af.
Local branch: development/flutter-app. GitHub branch creation returned HTTP 403,
“Resource not accessible by integration”. No new code was pushed.
Original prototype files are unchanged. Live Supabase was inspected read-only;
no schema changes or new Edge Functions were deployed.

## Added

- mobile/lib: Flutter sign-in/session gate, existing Supabase job/time reads,
  role-aware navigation, job map with radius circles, draft pin/radius editor.
- Native Android SQLite observation journal, receiver, method-channel handler.
  Raw observations are persisted separately from payroll. Native adapter source
  is NOT yet wired into a generated Flutter Activity/manifest/build.
- Pure Dart draft event interpreter: enter/dwell separation, duplicate event
  suppression, site-specific exits, overlap/late-event review, manual-stop hold.
- Eleven behavioral checks, also wrapped for flutter_test.
- Proposed admin-only job-write SQL, not applied. This is an incremental draft,
  not the final multi-company schema. Existing records were preserved.
- Product plan carried into docs/product-plan.md.

## Verification actually performed

- Pure Dart standalone tests: PASS, 11 checks.
- Dart formatter: PASS across seven source/test files (syntax parsed).
- Repository inspection and read-only Supabase tables/policies: complete.
- Flutter package resolution, analyzer, widget tests, Android/iOS builds: NOT complete.
- Native Kotlin compile/device testing: NOT performed.
- API write, background capture, persistence recovery on a physical phone: NOT verified.

The downloaded Dart VM initially lacked its executable bit; fixing that SDK file
allowed the pure Dart tests to run. Full `flutter create` subsequently could not
be completed: automatic approval review rejected a connection to the cloud
instance metadata service. Do not retry that connection or bypass its protection.
Use an approved build environment and investigate why that request occurred.

## Backend findings

Existing tables: profiles (0 rows), jobs (4 rows), time_entries (0 rows).
These are metadata counts reported by the connector, not exported employee data.
The policy named “Crew view own time” has no row predicate. Active jobs are
readable via a public-role policy. Do not put the new build into crew production
until tenant/role policies have been replaced and adversarial access tests pass.
The starter repository applies an own-user filter to time reads, but that is not
a substitute for server authorization. Existing profile policies and helper
functions need further review. No owner profile exists in the observed table.

## Required next work, in dependency order

1. Restore GitHub integration Contents read/write permission on CrewClocker.
2. Complete Flutter platform generation in an approved runtime, preserving
   mobile/lib and native tracking source; resolve dependencies and commit lockfile.
3. Wire Android Activity to TrackingChannel, add receiver/location declarations,
   play-services-location dependency and restricted Maps key configuration.
4. Finish auth/account provisioning and isolated company/membership/job/assignment
   schema with server policy tests. Replace prototype reads accordingly.
5. Deploy and validate authenticated job write/address-search endpoints. Reuse
   GOOGLE_MAPS_API_KEY as a server secret without exposing its value.
6. Add native assignment versions, boot recovery and device ownership generation;
   map configuration acknowledgements and permission onboarding.
7. Implement authenticated idempotent event ingestion/reconciliation and a
   retrying upload worker. Acknowledge local IDs only after durable server receipt.
8. Add manual time/break/travel controls, corrections/audit, manager workflow,
   approvals and exports, localization and full accessibility/error states.
9. Run Flutter analysis/widget tests, compile Kotlin/Android, and produce a signed
   internal build for the Galaxy S26 Ultra background-tracking proof.
10. Complete independent iOS adapter and physical iPhone spike, then pilot gates.

## Deliberate limits of this checkpoint

No demo data simulates completed backend writes. Job save calls the versioned
RPC and reports failure until it is deployed. Address input is a label, not yet
geocoded. Automatic payroll writing is disabled in the UI. Native registration
is not offered until assignment/permission/server processing is integrated.
No continuous GPS route recording. No automatic wage or lunch assumptions.
No iOS platform files have been generated yet.

The final evaluation definition remains docs/product-plan.md; this checkpoint
must not be represented as satisfying it.

# CrewClocker field test 0.2

Target: Travis's Samsung Galaxy S26 Ultra. This is an owner-led location-event
field test, not the finished payroll/evaluation product.

## Install

Use the delivered **CrewClocker-field-test.apk**, signed with the private internal
signing key. GitHub's intermediate artifact is debug-signed by its temporary
runner and must not be used for upgrades after the delivered internal build.

The old 0.1 installation-check APK used a different temporary signing key.
Uninstall that old **CrewClocker Preview** once before installing 0.2. It did not
have a monitoring control, and the supplied device screenshot showed zero events.
Do not uninstall/clear storage on later versions with unsynced observations.
Future delivered field builds must reuse the preserved internal signing key.

## Owner setup

1. Sign in with your existing CrewClocker email/password, or tap **New owner?
   Create an account**. New accounts require a password of at least 10 characters.
2. If email confirmation is required, open the confirmation email, then return
   to the app and sign in. Email delivery/provider settings are not verified by
   our database tests; report any confirmation or sign-in error.
3. Enter your name and create your company workspace. This creates your own
   isolated company, not membership in someone else's company.
4. Jobs → **Add site and assign to me**. Tap the map at a safe test location, or
   tap **Use my current location**, then verify the pin. Choose a radius, name it,
   and save. Start with 175–200 meters. This assigns the site to your account.

The map uses attributed OpenStreetMap tiles with app identification and the
mapping library's normal HTTP-aware cache. No offline-map downloads or address
search are included. A restricted Google Maps key is not needed for this build.

## Enable monitoring

On Today, allow precise foreground location first. Then open the app's Android
settings and choose Permissions → Location → Allow all the time; keep Precise
location enabled. Return to CrewClocker and tap **Enable monitoring**.
Verify that Today reports monitoring enabled, the expected site count, and no
tracking error. Pause monitoring before adding another site, then enable again
to register the updated assignments.

## First arrival/departure proof

1. Begin outside the circle, with internet and location services on.
2. Lock the screen, enter the circle, and stay inside for at least 3–5 minutes.
3. Leave well outside the circle, then allow several minutes for Android to
   deliver the exit. Do not test only a few steps either side of the boundary.
4. Reopen CrewClocker → Events. Compare enter/dwell/exit observations with the
   actual visit. These are raw observations, not a timesheet.
5. Repeat with the app swiped away (not Android **Force stop**).
6. Check offline persistence: with internet temporarily unavailable, delivered
   observations stay on the phone. Reconnect and reopen the app to sync. Android
   location/geofence delivery itself can be delayed without network positioning;
   local persistence does not guarantee that Android detects every offline visit.
7. Test reboot recovery separately: enable monitoring, restart/unlock the phone,
   then repeat a visit and inspect results. Record any missing or late event.

Upload runs on opening/resuming the app and every 30 seconds while the app is
running. There is no native background network uploader in this version. Never
interpret an empty server list as proof that the phone has no pending events.

**Pause monitoring and sync** stops native capture before unregistering.
Sign-out syncs your pending rows first. If accidentally logged into another
account, sign out and return to the original owner; the journal is preserved.

## Implemented safeguards

- Server RLS isolates companies and limits crew reads to assigned sites/own events.
- Atomic owner workspace and site/self-assignment creation.
- Native SQLite events retain account, device, immutable assignment/version.
- Late callbacks from an old monitoring generation are ignored.
- Exact, idempotent server acknowledgements precede local acknowledgement.
- Journal version-1 upgrade retains old unsent rows. Legacy rows lacking assignment
  metadata are not silently deleted or attributed to a new assignment.
- Restart/package-update registration recovery is implemented, awaiting phone proof.

## Not finished

Crew invitations, assignment editing/revocation synchronization, native background
upload worker, wage/time reconciliation, manual time controls, approval/export,
full localization, and iOS. This version records client-reported observations;
it does not prove payable work or calculate payroll.

See BUILD_STATUS.md for verified checks and remaining service advisories.

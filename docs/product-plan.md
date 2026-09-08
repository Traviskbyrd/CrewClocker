# CrewTracker — Complete App Plan

Prepared for Travis, T-Byrd Painting & Construction Services LLC • September 8, 2026

Status: implementation-ready product direction, not a claim that software has been built or tested. This plan extends the supplied “Crew Time Tracker — Project Handoff & Development Summary.” Where it changes earlier suggestions, the decisions below are the proposed new baseline. Business defaults are recommendations, not previously confirmed company policies.

## 1. The finished product

CrewTracker is a native-installed Android and iPhone app that records crew time at assigned job sites, helps employees fix exceptions, and gives the owner a trustworthy, approved time report for each pay period.

For an ordinary workday, a crew member should put the phone in their pocket, arrive at a job, work, and leave. The app handles the usual site arrivals and departures. The employee only needs to act for breaks, unusual work, corrections, or a tracking problem. Travis can manage the entire company from his Android phone.

Success means replacing the weekly reconstruction of everybody’s hours with a short review of exceptions. The product must preserve the distinction between what the phone observed, what the software calculated, and what management approved.

**Release order:** complete Android business app first; iOS production release second. Use shared Flutter screens and domain contracts, with native Kotlin and Swift location modules. Flutter supports native platform integration; this is an installed mobile application rather than a website wrapped in an app. [Flutter architecture](https://docs.flutter.dev/resources/architectural-overview)

The eventual cross-platform product includes the same employee and manager workflows on both phones. A desktop manager dashboard is a later convenience, not a prerequisite for using Android independently.

## 2. What is included at each stage

| Capability | Android finished release | iOS finished release | Later expansion |
|---|---|---|---|
| Automatic assigned-site arrival/departure | Yes | Yes, separately field-tested | Improve from field evidence |
| Offline event capture and recovery | Yes | Yes | — |
| Manual work, break, travel, correction controls | Yes | Same business behavior | — |
| Employees, crews, sites, assignments | Yes | Yes | Calendar integrations |
| Manager exception review and approvals | Yes | Yes | Delegated payroll roles |
| Pay-period and job-hours reports; CSV | Yes | Yes | Payroll-specific integrations |
| Tracking health and last-update visibility | Yes | Yes | Support diagnostics refinement |
| English and Spanish core crew flows | Yes | Yes | Additional languages |
| Multiple-company data isolation | Built in | Built in | Self-service SaaS onboarding |
| Desktop administration | Not required | Not required | Responsive dashboard |
| Subscription billing | No | No | After external customer validation |
| Dollar labor costing | No; job hours included | Same | Effective-dated rates and burden |
| HR documents, PTO, estimating, invoices, chat | No | No | Separate validated additions |

This defines a complete timekeeping product without requiring it to become an entire construction-management platform. Multi-company foundations are worthwhile now; a full SaaS sales and billing system is not necessary for T-Byrd’s first release.

## 3. Roles and access

| Role | Allowed work |
|---|---|
| Employee | Own current status, own time history, assigned site details, manual entries, break/travel controls, correction requests, tracking settings |
| Manager | Company crew status, sites and assignments, timesheet corrections with reasons, exception resolution, period approval and export |
| Owner | Manager capabilities plus membership/role administration, company policies, ownership and account administration |

One app changes navigation according to role. Travis can switch between “My time” and “Manage crew,” so the owner can also track personal work. Crew labels group employees for assignments; they do not replace individual time records. Initial managers have company-wide access; restricted crew supervisors are a later role.

Employees cannot inspect coworkers’ timesheets, change pay policies, approve their own corrections, or obtain company exports. Enforcement belongs on the server, not just in hidden buttons.

## 4. What the screens look like

Design direction: bright, readable surfaces, dark navy text, teal for active work, amber for review, red for a confirmed problem. Status always has text and an icon, not color alone. Large touch targets, scalable text, minimal typing, and readable outdoor contrast. Use system accessibility and date/time preferences. Show hours as “7h 35m”; use decimal hours only where exports need them.

### Employee navigation: Today · My Time · Jobs · Account

| Screen | Contents and main action |
|---|---|
| Welcome and join | Accept an owner-provided invitation link/code; verify account; choose language; explain automatic tracking |
| Tracking setup | Stepwise location permissions, notification choice, assigned sites download, readiness check, manual-use fallback |
| Today | Large status card, site name, start time, today’s total, event timeline, last sync; primary action changes with state |
| On-site actions | Start break, switch job, record travel/supply run, finish work; manual actions clearly labeled |
| My Time | Day/week/pay-period views; work and break segments; recorded versus approved hours; request correction |
| Entry details | Original times, current times, source, review state, correction history; plain-language explanation |
| Jobs | Assigned jobs, address, directions, assignment dates, whether automatic monitoring is ready |
| Account | Language, notification preferences, tracking health, pause/resume automation, help, privacy, sign-out and account request options |

Example Today card: “Working · Smith Residence,” “Started 7:04 AM · Automatic,” “Today 5h 16m,” and “Synced 2 minutes ago.” Offline becomes “Saved on this phone — waiting to sync.” Pending arrival becomes “Arrival detected — checking site.” Uncertainty must be visible.

Manual clock-out suppresses automatic reopening at the same site until a confirmed exit/re-entry or an explicit employee resume. Starting a break also prevents an ENTER callback from restarting work. Employees can report work outside assignment hours or at an unlisted site; those records go to review rather than being blocked.

### Manager navigation: Overview · Crew · Jobs · Time · More

| Screen | Contents and main action |
|---|---|
| Overview | Working by site, on break, not clocked in, status unknown; exceptions first; last-sync labels |
| Crew | Invite/deactivate, crew grouping, role, assignments, device readiness, employee time |
| Jobs | Create/edit/archive; search address or place map pin; visible radius; dates and assigned crew |
| Assignment detail | Employees and dates; saved server version versus device-confirmed monitoring status |
| Time | Employee/job/date/pay-period filters; day totals and segments; review and approve |
| Exceptions | Missing boundary, overlap, unknown travel, employee request, stale device or unassigned work; proposed resolution with evidence |
| Reports | Hours by employee, job and period; approved totals; unresolved count; CSV export |
| Settings | Timezone, pay periods, workweek, tracking defaults, travel/break rules, membership, privacy and support |

The main dashboard includes the crew roster. Jobs provides Google Maps and list views; the map displays authorized job-site pins and their geofence circles at the saved radius. Managers see company jobs; employees see assigned jobs. Employee movement routes are not part of the product. An invitation is created in-app for Travis to share; email/SMS delivery can be added as an explicit action later.

## 5. A complete workday

1. Travis creates a job, checks the pin/radius, assigns a crew, and sees whether each device has registered the assignment.
2. An employee arrives. The device records an arrival candidate locally; validated presence opens job work using the earliest supported observation.
3. A confirmation appears when notification permission permits. Today shows the current job even if the internet is unavailable, labeled provisional until reconciled.
4. The employee starts and ends lunch with simple controls. A forgotten break can be reported later; location alone cannot tell whether someone stopped working.
5. Leaving closes the site-work segment. Travel or a supply run is recorded separately. Unknown gaps between work segments require classification before approval.
6. Arrival at the next job starts that site’s segment without overlapping the first. Returning to the first job creates another segment under the same job.
7. At day’s end the employee can review the timeline and flag an issue. Travis resolves exceptions, approves the pay period, and exports a reproducible report.

## 6. Timekeeping decisions

### Separate presence from payable work

Site presence is evidence, not proof of all payable work. A departure ends allocation to that site; it does not establish that the employee stopped all work. Use segment categories: job work, travel, supply run, other work, paid break, unpaid break, and unresolved gap. Payability is a separate policy/result field.

Initial behavior: identify gaps between site-work segments as unresolved until employee or manager classifies them. Do not automatically classify the first/last commute, every absence, or every supply run. Employees may manually record work before arrival or after departure. No automatic lunch deduction. No time rounding in version 1; preserve actual stored precision and calculate totals before display rounding.

Payroll exports contain approved hours. Optional regular/overtime categorization requires an owner-confirmed, effective-dated policy; do not assume one generic rule covers every employee or jurisdiction. This app does not calculate taxes or issue wages.

### Proposed starting settings

| Setting | Proposed baseline | Reason |
|---|---|---|
| Company timezone | America/Chicago, confirm during setup | Appropriate starting assumption for T-Byrd |
| Pay period/workweek | Owner selects before first approval | Not established by the source notes |
| Site radius | 175 m, editable and map-previewed | Field-test against roads, parking, nearby properties |
| Android arrival dwell | 2 minutes | Reduce drive-by entries; tune in pilot |
| Departure reconciliation window | 2 minutes | Merge short boundary oscillations when evidence supports it |
| Long open shift warning | 12 hours | Review trigger, never fabricated clock-out |
| Device freshness | Mark stale after 60 minutes without contact during expected work | Unknown status, not proof of absence |
| Automatic final payroll approval | Disabled | Manager review stays explicit |
| Active tracking device | One per employee/company | Avoid competing phone clocks |

The dwell and reconciliation durations are product tuning values, not promises of precisely timed OS callbacks. Work schedules help interpret events and send reminders; they never cap actual recorded work or silently discard overtime.

## 7. Background tracking that is honest about its limits

Android’s documented geofence limit is 100 per app/device user. It supports ENTER, EXIT and DWELL; background responses can take minutes. Re-registration and error handling are necessary, including after reboot. Use the native API and a durable callback handler, not a continuously running Flutter timer. [Android geofencing](https://developer.android.com/develop/sensors-and-location/location/geofencing)

iOS gets its own Swift Core Location adapter. Apple’s archived region-monitoring guide documents a 20-region cap and an explicit inside-region state check at registration. These are the planning baseline; verify behavior against the selected current SDK and physical phones during the iOS spike. [Apple region monitoring](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/RegionMonitoring/RegionMonitoring.html)

Do not promise that either phone will keep tracking after every form of force-stop, permission change, reboot, battery restriction, or user termination. Test ordinary backgrounding, task removal, OS termination, and explicit user stop separately. A dead phone or missing phone cannot observe attendance. The app must detect problems when it next runs and provide manual recovery.

### Arrival and departure validation

Android may use native DWELL. iOS must not imitate that with an assumed two-minute background Dart timer. It records native observations, uses an allowed fresh location/state check when available, and otherwise keeps uncertain arrivals provisional for later evidence or confirmation. The backend may run delayed reconciliation; elapsed time without an EXIT is not itself proof of continued presence.

Persist candidate state and deadlines so process death does not reset the interpretation. Short exit/re-entry pairs can be merged when appropriate; unresolved departures remain visible. A late event can revise an unapproved draft, but never silently change approved payroll.

Record callback-observed time, any trustworthy source timestamp, and server-received time separately. Do not name callback time “exact property-line crossing time.” Never subtract an assumed latency to invent arrival time. Display estimated/reviewed status where appropriate.

### Assignment capacity and freshness

Register active assigned jobs first; keep the current working job registered until its work is resolved. Within capacity, use deterministic assignment priority. The server retains every job. Device registration acknowledgements show which assignment revision is actually active.

When iOS has more than 20 relevant jobs, show capacity overflow and require a selected active set. Do not assume the phone can continuously discover and rotate the nearest jobs while asleep. Refresh on app use, supported callbacks, and successful sync; remote notification is a hint, not a guaranteed wake-up. Offer manual selection for an unmonitored job. Android follows the same model with its larger cap.

Editing a site or ending an assignment must not truncate an open work segment. Preserve site versions; retain necessary monitoring until resolution, then remove it. A late event uses the assignment/site version applicable when observed.

## 8. Event interpretation and difficult cases

Presence state and pay-period approval state are separate. Presence can be outside, arrival pending, on site, departure pending, or unknown. Work activity can independently be job work, break, travel, other work, or stopped. Review flags are independent of both.

| Situation | Required behavior |
|---|---|
| Drive past a site | Keep evidence; do not create approved work from a brief unconfirmed visit |
| Nearby/overlapping jobs | Prefer an unambiguous assignment; otherwise ask which job; never create parallel work segments |
| EXIT A arrives after ENTER B | Reconcile by evidence/sequence; do not close B using A’s EXIT |
| No EXIT all evening | Show missing departure; exclude open duration from finalized export until resolved |
| Phone starts inside a site | Check initial state; ask about earlier start rather than inventing it |
| No internet | Save events and manual commands locally; show pending sync |
| No usable location | Manual clock controls remain available; disclose degraded automation |
| Permission revoked while offline | Local warning when observable; manager sees last-known health until contact resumes |
| Phone switch | Explicit active-device handoff; late old-device events preserved for review, not silently discarded |
| Device time changes | Preserve device wall time, monotonic sequence/boot context and receipt time; flag suspicious timing |
| Overnight/DST shift | Store UTC instants; use company timezone for display/grouping; split reporting at boundaries without losing duration |
| Manual change conflicts with auto event | Preserve both; explicit manual intent wins draft behavior and raises review if boundaries conflict |
| Archived site or deactivated employee | Retain history; prevent new unauthorized commands; review legitimate late evidence |
| Unsynced data then logout/uninstall | Attempt safe upload before logout; warn if pending records remain; uninstall can destroy unsynced evidence |
| Spoofed location or phone left on site | Do not claim fraud-proof attendance; evidence and audit help investigation, not automatic discipline |

## 9. Technical architecture

| Layer | Responsibility |
|---|---|
| Google Maps Platform | Map display on Android/iOS, job-site pins and radius circles, address lookup; background transitions handled by native location services |
| Flutter/Dart + Riverpod | Employee/manager UI, navigation, local projections, account and sync presentation |
| Native Android/Kotlin | Geofence registration, callbacks, permission/boot recovery, durable event capture and eligible upload work |
| Native iOS/Swift | Core Location registration/callbacks, durable capture, allowed background upload opportunities |
| Local SQLite persistence | Native-writable event journal, command outbox, assignment versions, acknowledgement state; survives process restart |
| Shared event contract | Versioned observation/command schema and deterministic interpretation fixtures across implementations |
| Supabase Auth/Postgres | Identity, membership, company isolation, authoritative work ledger, revisions and approvals |
| Server ingestion/processor | Validate events, idempotent ingestion, transactional reconciliation, authorized corrections and exports |
| Notifications | Best-effort local confirmations and remote review reminders; never the source of truth |

The native callback must persist the event before relying on Flutter startup or network access. Establish one controlled SQLite access strategy with transactions and migrations; do not let unrelated Dart/native libraries compete over schema ownership. Flutter reads the journal through the adapter or coordinated repository.

Native capture needs to work even if no Flutter screen is running. Background upload authenticates securely and tolerates token expiry; failure leaves the journal pending. The server is authoritative, while local status is a provisional projection. Shared fixtures check consistent interpretation without forcing the phone and backend to use the same language.

Keep geofencing behind an internal interface: registerSites, removeSites, readMonitoringStatus, readPendingEvents, acknowledgeEvents, requestCurrentSiteCheck. Evaluate package maintenance/licensing during implementation; the baseline is owning a thin native adapter, not depending on an unverified package’s “always running” claim.

## 10. Data model and integrity

| Entity | Purpose and essential information |
|---|---|
| companies / company_policy_versions | Company identity, timezone, effective-dated pay/tracking configuration |
| memberships / invitations | Auth-user relationship, role, active status, employee code; expiring single-use invitations |
| crews / crew_memberships | Crew grouping and membership dates |
| job_sites / site_versions | Address, pin, radius, timezone if needed, lifecycle and historical definitions |
| site_assignments | Employee/crew, effective dates, priority, assignment version |
| employee_devices | Active-device generation, platform, app version, last-known permissions, last contact |
| device_registration_acks | Device’s confirmed active site set and revision |
| tracking_events | Immutable observation UUID, employee/device/site version, type, sequence, timestamps, optional accuracy evidence |
| work_segments | Work category, site when applicable, start/end, source, confidence, current revision |
| correction_requests / segment_revisions | Requested and authorized changes, reason, actor, prior/new values |
| review_issues | Missing boundary, ambiguous site, unresolved gap, device conflict and resolution |
| pay_periods / approvals | Scope, included segment revisions, approval actor/time, lock state |
| export_runs / audit_log | Snapshot version, parameters, totals, actor and append-only actions |

Use company-scoped relationships so a site from company B cannot be attached to company A’s employee, even through a crafted API call. Enforce valid end-after-start boundaries and no overlapping active work for one employee. Breaks are separate nonoverlapping segments in the work timeline. Status flags such as “adjusted” should not replace whether a segment is open or approved.

Ingestion accepts a batch with per-event acknowledgement. Deduplicate by immutable event UUID and verify device ownership. Upload retries must not duplicate time. Serialize reconciliation per employee and apply ledger changes in one database transaction. Preserve out-of-order observations; replay the affected draft interval deterministically using an interpreter version. Reject malformed data with visible retryable/permanent outcomes.

Approved intervals are immutable snapshots. New evidence against a locked period creates a proposed revision and review issue. An authorized reopen invalidates the prior approval for the changed version and requires a new approval/export. Earlier exports remain identifiable.

## 11. Security, privacy and operations

Supabase row-level policies must enforce company membership and role on every exposed business table. Employee observations are append-only; client apps cannot directly approve time or change membership roles. Do not put server secret keys in either mobile app. [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security)

Use protected device credential storage, authenticated TLS transport, expiring invitations, server-checked membership revocation, rate limits and an audit trail. Avoid putting worker/customer information in crash logs. Test cross-company access attempts, forged employee/device identifiers and employee-to-manager escalation explicitly.

Collect site transitions and essential diagnostics rather than continuous route history. Precise callback coordinates are optional, minimized and access-restricted; retain derived times and change history separately from short-lived diagnostics. Final retention durations need a company policy before production; implement independent retention classes and no silent purge of approved records. Give employees a clear explanation of what managers can see and how to request account/data handling.

Pausing automation stops location monitoring on the phone and records the pause when possible; it does not erase hours or automatically terminate a shift. Resuming re-registers the current assignments. Do not promise exact scheduled monitoring shutdown while an OS has suspended the app. Registration outside ordinary hours must be disclosed; events outside the expected schedule can require review.

Google Play background-location review requires prominent disclosure, a privacy policy and evidence of the core background feature. Prepare a working demonstration and accurate store declarations as part of release work; approval is a release dependency, not assured by architecture. [Google Play background-location requirements](https://support.google.com/googleplay/android-developer/answer/9799150?hl=en)

Operational completion includes separate development/staging/production environments, managed signing credentials, pinned dependencies, migration rollback planning, database backups with a demonstrated restore, crash/error monitoring, sync-failure visibility, support instructions, and a switch to disable faulty automation while keeping manual timekeeping usable.

## 12. Reporting and approval

Employee totals, job totals and export totals must reconcile to the same approved segment revisions. Show unresolved/open time separately; never include an endlessly increasing live timer in a finalized payroll file.

CSV detail fields: company, employee code/name, pay-period identifier, local work date, timezone, category, job code/name, start/end UTC, local start/end with offset, duration minutes, decimal hours, payability classification, optional confirmed regular/overtime split, source, approval revision and export identifier. Provide a summary by employee and by job. Export handling must escape spreadsheet formula-like text in names/notes.

Re-exporting the same approved snapshot produces the same hours. Corrections after an export generate a new revision clearly identified as replacing/supplementing the earlier report. Actual submission to a payroll provider remains a separate workflow.

## 13. Build sequence and release gates

| Milestone | Deliverable | Gate to move forward |
|---|---|---|
| 0 — Foundations | Repository, Flutter app shell, environments, event contract, minimal schema/access model | Build reproducible; no secret in app; company isolation test passes |
| 1 — Android proof | One employee/site; native callback journal; offline sync; basic timeline and manual fallback | Physical phone records background arrival/departure and retains events through process restart |
| 2 — iOS risk spike | Thin Swift adapter using the same contract | Physical iPhone exercises capture, persistence, initial-inside behavior and background limits; gaps documented |
| 3 — Android workflow | Crew/site administration, multiple jobs, breaks/travel, corrections, health states | Full workday and failure cases work end to end |
| 4 — Android business completion | Period review/lock, reports/CSV, translations, account lifecycle, support | Totals reconcile; approved history protected; restore and security checks pass |
| 5 — T-Byrd pilot | Real devices/sites with independent actual-arrival log | Quantified reliability and correction burden meet pilot gates below |
| 6 — Android production | Signed release, store materials, onboarding and rollout | Release review/distribution complete; Travis runs a whole period successfully |
| 7 — iOS production | Feature parity, TestFlight testing, iPhone-specific permission/recovery UX | Independent iOS pilot and store release gates pass |
| 8 — SaaS expansion | External-company onboarding, billing, larger-scale support | T-Byrd workflow proven and external demand validated |

The iOS spike is a bounded architecture check. It does not require finishing the iPhone app before delivering useful Android builds. Calendar estimates should follow the native proof: background behavior and actual crew devices are the largest unknowns. No existing repository, implementation, accounts, or deployed database were inspected for this planning task.

### Pilot acceptance targets — proposed, not measured

Run at least two working weeks with 3–5 crew phones where available, covering actual Android manufacturers used by T-Byrd, and at least 100 independently logged arrival/departure transitions. Evaluate each device family rather than hiding a poor device inside an average.

- At least 95% of ordinary eligible transitions captured automatically within five minutes of the independently logged boundary event. Count delayed/missed events separately; record force-stopped/permission-disabled cases as degraded operation, never omit them from the overall field report.
- Zero duplicate or overlapping work segments from retries, reordered events or device handoff.
- Zero loss of events already committed locally across restart and a 24-hour offline interval, followed by foreground reconnection. Track background-sync delay separately because OS scheduling is variable.
- Every ambiguous or missing boundary can be corrected with a reason and visible history; known unresolved issues block final approval.
- Approved report totals match independently reviewed time for an entire pay period.
- Proposed owner review target: under ten minutes per week for a five-person crew after normal setup; measure corrections required per employee-day.
- Proposed battery target: median incremental use under five percentage points over an eight-hour shift versus matched baseline days; investigate device outliers.

If these gates fail, tune boundaries/validation or change the location approach before broad release. Do not lower the published promise while quietly claiming the original reliability target was achieved.

## 14. Definition of finished

The Android app is finished when Travis can create jobs, onboard the crew, rely on routine automatic entries, handle every exception, approve a pay period and export accurate hours from his phone; employees can understand and correct their records; and the real-device, security, recovery and distribution gates have passed.

The cross-platform app is finished when an iPhone employee or manager can use the same business workflow with independently verified iOS tracking behavior. Sharing Flutter screens alone does not establish iOS readiness.

## 15. Decisions resolved and remaining setup inputs

Resolved by this plan: Android first, Flutter with native location modules, Supabase relational backend, local-first capture, auditable server interpretation, manager controls in the mobile app, manual fallback in the first usable release, travel/break separation, no automatic lunch deduction or rounding, approved CSV before direct payroll integration, and multi-company isolation before SaaS billing.

These inputs are needed before pilot setup, but do not block initial engineering: crew phone models/Android versions, worker count and concurrent site count, pay-period/workweek settings, actual travel/break policies, preferred employee sign-in method, initial test locations, and access to an iPhone plus a Mac or macOS build runner for iOS signing/testing. Proposed authentication baseline is verified email/password with persistent sessions and invitation codes; adapt if crew members lack usable email. No credentials are requested in this document.

The next concrete build is one vertical Android slice: sign in, register one assigned site, persist a native arrival/departure event while backgrounded, sync safely, generate a draft segment, display it, and manually correct it. The offline journal belongs in that first slice rather than being added after the demo.


## 16. Confirmed direction — Supabase and Google Maps

Travis explicitly confirmed these requirements after reviewing the initial plan:

- Supabase holds all authoritative backend business data: companies, employees, jobs, assignments, geofence definitions, observations, time records, corrections and approvals. Local phone storage remains an offline cache and durable upload queue, not a separate backend.
- Use Google Maps for the job-site map on both Android and iOS.
- Create a job by entering an address, placing a pin directly on the map, or searching an address and adjusting its pin.
- Display job-site markers and a visible geofence circle around each marker at its configured radius.
- Automatically clock crew members into the job on validated arrival and out of that job on validated departure, including ordinary background use.

### Job creation and editing workflow

1. Tap Add Job and enter a job name.
2. Search an address and select the intended result, or long-press the map to place a pin. Permit a pin-only job when a new construction site has no useful street address.
3. Drag the pin to the actual work area or appropriate arrival location. The final confirmed pin, rather than the address label, defines the fence center.
4. Set the radius with a slider and numeric input. Show feet by default for the crew, with a meters option; store a canonical radius in meters. The circle changes immediately while editing, with its radius clearly labeled.
5. Show nearby job circles so overlap can be spotted. Retain the ambiguous-site handling defined earlier.
6. Assign employees/crews, set active dates, and save to Supabase.
7. Synchronize the versioned center/radius to assigned phones and show pending versus confirmed device registration. Saving the map does not falsely imply every offline phone is already updated.

On the Jobs map, tapping a pin or circle opens the job name, address if present, radius, assignment information and details action. Managers can edit the site. Employees can view their assigned sites and open directions. Provide a list view for quick selection and when map tiles are unavailable.

### Map and tracking responsibilities

Google Maps renders the map, markers and circles. Address lookup uses Google Maps Platform address-search/geocoding capabilities; geocoding converts between addresses and coordinates. [Google Geocoding overview](https://developers.google.com/maps/documentation/geocoding/overview)

Android background detection uses the Google Play services Geofencing API; iOS uses Apple Core Location. Both consume the same Supabase job-site center/radius definition displayed on the Google map. A displayed circle does not itself register background monitoring. The circle is the intended boundary; real location observations can be delayed or uncertain as described in section 7. [Android geofencing](https://developer.android.com/develop/sensors-and-location/location/geofencing)

The employee does not need to keep the map open for ordinary automatic tracking. Previously registered fences and local event persistence operate independently of whether map tiles or address search can load; location detection itself still depends on device conditions.

Store the job's user-entered label/address, confirmed geofence center, radius, location-input provenance and configuration revision. Keep Google-derived lookup content distinct and verify the selected API's storage/refresh requirements before implementation; do not treat whole lookup responses as unrestricted permanent business records.

### Additional acceptance criteria

- Address search, pin-only creation and address-then-pin-adjustment all create usable job sites.
- The persisted center/radius matches both the drawn circle and the native registration payload, including feet/meters conversion.
- Reloading a saved job reproduces its pin and circle; dragging or resizing updates the preview before saving.
- Company maps and assigned-job maps enforce existing access permissions.
- New radius/pin revisions show pending registration until the device acknowledges them.
- A physical Android phone records arrival and departure with the map closed, and the resulting site time synchronizes to Supabase.

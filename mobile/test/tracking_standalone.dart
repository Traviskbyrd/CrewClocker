import '../lib/domain/tracking.dart';

void main() {
  var checks = 0;
  void check(bool value, String label) {
    if (!value) throw StateError(label);
    checks++;
  }

  final start = DateTime.utc(2026, 9, 8, 7);
  Observation event(
    String id,
    Transition transition,
    int minute, [
    String site = 'a',
  ]) => Observation(
    id: id,
    siteId: site,
    at: start.add(Duration(minutes: minute)),
    transition: transition,
  );
  final ledger = TrackingLedger();
  ledger.apply(event('enter', Transition.enter, 0));
  check(ledger.active == null, 'ENTER is provisional');
  ledger.apply(event('dwell', Transition.dwell, 2));
  ledger.apply(event('dwell', Transition.dwell, 2));
  ledger.apply(event('dwell-again', Transition.dwell, 3));
  check(
    ledger.active?.start == start,
    'Dwell uses observed arrival and does not duplicate',
  );
  ledger.apply(event('other-site', Transition.dwell, 4, 'b'));
  check(
    ledger.active?.siteId == 'a' && ledger.reviewIssues.length == 1,
    'Overlap flagged',
  );
  ledger.apply(event('other-exit', Transition.exit, 5, 'b'));
  check(
    ledger.active?.siteId == 'a',
    'Other site EXIT cannot close active work',
  );
  ledger.apply(event('stop', Transition.manualStop, 6));
  ledger.apply(event('spurious-enter', Transition.enter, 7));
  ledger.apply(event('spurious-dwell', Transition.dwell, 8));
  check(
    ledger.active == null,
    'Manual stop suppresses callbacks until departure',
  );
  ledger.apply(event('exit', Transition.exit, 9));
  ledger.apply(event('return', Transition.enter, 10));
  ledger.apply(event('return-dwell', Transition.dwell, 12));
  check(
    ledger.active?.start == start.add(const Duration(minutes: 10)),
    'Return starts new segment',
  );
  ledger.apply(event('late', Transition.exit, 3));
  check(
    ledger.active != null && ledger.reviewIssues.length == 2,
    'Late events require reconciliation',
  );
  check(
    ledger.completed.single.elapsed == const Duration(minutes: 6),
    'Completed duration exact',
  );
  final driveBy = TrackingLedger()
    ..apply(event('one', Transition.enter, 0))
    ..apply(event('two', Transition.exit, 1));
  check(
    driveBy.active == null && driveBy.completed.isEmpty,
    'Drive-by produces no work',
  );
  final site = JobSite(
    id: 'x',
    name: 'Test',
    latitude: 30,
    longitude: -97,
    radiusMeters: 175,
  );
  check(JobSite.fromJson(site.toJson()).radiusMeters == 175, 'Site round trip');
  check(
    const JobSite(
          id: 'x',
          name: '',
          latitude: 0,
          longitude: 0,
          radiusMeters: 175,
        ).validate() !=
        null,
    'Name validation',
  );
  print('Passed $checks event and site checks.');
}

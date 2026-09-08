/// Pure event interpretation. Native callbacks and network retries must never
/// write payroll directly. Decisions are drafts until server reconciliation.
enum Transition { enter, dwell, exit, manualStart, manualStop }

class Observation {
  const Observation({
    required this.id,
    required this.siteId,
    required this.at,
    required this.transition,
  });
  final String id;
  final String siteId;
  final DateTime at;
  final Transition transition;
}

class WorkSegment {
  const WorkSegment({required this.siteId, required this.start, this.end});
  final String siteId;
  final DateTime start;
  final DateTime? end;
  Duration get elapsed => (end ?? start).difference(start);
}

class TrackingLedger {
  final Set<String> processed = {};
  final Map<String, Observation> arrivals = {};
  final List<WorkSegment> completed = [];
  final List<String> reviewIssues = [];
  final Set<String> manuallyStoppedSites = {};
  WorkSegment? active;
  DateTime? latestAt;

  void apply(Observation event) {
    if (!processed.add(event.id)) return;
    if (latestAt != null && event.at.isBefore(latestAt!)) {
      reviewIssues.add(
        'Late observation ${event.id}: server reconciliation required',
      );
      return;
    }
    latestAt = event.at;
    switch (event.transition) {
      case Transition.enter:
        if (manuallyStoppedSites.contains(event.siteId)) return;
        if (active?.siteId != event.siteId)
          arrivals.putIfAbsent(event.siteId, () => event);
      case Transition.dwell:
        if (manuallyStoppedSites.contains(event.siteId)) return;
        if (active?.siteId == event.siteId) return;
        if (active != null) {
          reviewIssues.add('Overlapping arrival at ${event.siteId}');
          return;
        }
        // A DWELL without ENTER is valid evidence from its observed timestamp;
        // do not subtract an assumed dwell delay.
        final arrival = arrivals.remove(event.siteId);
        active = WorkSegment(
          siteId: event.siteId,
          start: arrival?.at ?? event.at,
        );
      case Transition.exit:
        manuallyStoppedSites.remove(event.siteId);
        arrivals.remove(event.siteId);
        if (active?.siteId == event.siteId) _close(event.at);
      case Transition.manualStart:
        if (active != null) {
          reviewIssues.add('Manual start conflicts with open work');
          return;
        }
        manuallyStoppedSites.remove(event.siteId);
        arrivals.remove(event.siteId);
        active = WorkSegment(siteId: event.siteId, start: event.at);
      case Transition.manualStop:
        if (active?.siteId != event.siteId) return;
        manuallyStoppedSites.add(event.siteId);
        _close(event.at);
    }
  }

  void _close(DateTime at) {
    final current = active!;
    completed.add(
      WorkSegment(siteId: current.siteId, start: current.start, end: at),
    );
    active = null;
  }
}

class JobSite {
  const JobSite({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.address = '',
  });
  final String id, name, address;
  final double latitude, longitude, radiusMeters;
  factory JobSite.fromJson(Map<String, dynamic> row) => JobSite(
    id: row['id'] as String,
    name: row['name'] as String,
    address: row['address'] as String? ?? '',
    latitude: (row['lat'] as num).toDouble(),
    longitude: (row['lng'] as num).toDouble(),
    radiusMeters: (row['radius_meters'] as num? ?? 175).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'lat': latitude,
    'lng': longitude,
    'radius_meters': radiusMeters,
  };
  String? validate() {
    if (name.trim().isEmpty) return 'Enter a job name.';
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      return 'Choose a valid location.';
    }
    if (!radiusMeters.isFinite || radiusMeters < 100 || radiusMeters > 1000) {
      return 'Choose a radius between 100 and 1,000 meters.';
    }
    return null;
  }
}

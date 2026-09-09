import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/field_repository.dart';
import '../platform/tracking_bridge.dart';
import 'device_check.dart';

class FieldWorkspace extends StatefulWidget {
  const FieldWorkspace({super.key, required this.repository});
  final FieldRepository repository;
  @override
  State<FieldWorkspace> createState() => _FieldWorkspaceState();
}

class _FieldWorkspaceState extends State<FieldWorkspace>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> companies = [],
      assignments = [],
      events = [],
      pending = [];
  Map<String, dynamic> health = {};
  String? error;
  bool initialized = false, busy = false, refreshing = false;
  int page = 0;
  DateTime? lastSync;
  Timer? timer;
  FieldRepository get repo => widget.repository;
  Map<String, dynamic>? get company =>
      companies.isEmpty ? null : companies.first;
  bool get owner => company?['owner_id'] == repo.userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!busy) refresh();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    String? problem;
    try {
      final cs = await repo.companies();
      // Prefer the caller's own company for this owner-led field test.
      cs.sort(
        (a, b) => (a['owner_id'] == repo.userId ? 0 : 1).compareTo(
          b['owner_id'] == repo.userId ? 0 : 1,
        ),
      );
      final as = cs.isEmpty
          ? <Map<String, dynamic>>[]
          : await repo.assignments(cs.first['id'] as String);
      if (mounted)
        setState(() {
          companies = cs;
          assignments = as;
          initialized = true;
        });
      try {
        await repo.sync();
      } catch (_) {
        problem =
            'Observations are still on this phone. Check your connection and tap Sync. If you changed accounts, sign in to the original account.';
      }
      final es = await repo.events();
      if (mounted)
        setState(() {
          events = es;
          if (problem == null) lastSync = DateTime.now();
        });
    } catch (_) {
      problem =
          'Could not reach your company. Saved phone observations are kept. Try again when connected.';
    }
    try {
      final h = await repo.bridge.health();
      final ps = await repo.bridge.pending();
      if (mounted)
        setState(() {
          health = h;
          pending = ps;
        });
    } catch (_) {
      problem =
          'Could not read native tracking status. Close and reopen the app.';
    }
    if (mounted) setState(() => error = problem);
    refreshing = false;
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await refresh();
    } catch (e) {
      if (mounted)
        setState(() => error = 'Action could not finish: ${e.toString()}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> newSite() async {
    if (health['enabled'] == true) {
      setState(
        () => error =
            'Pause monitoring and sync before adding a site. Then enable the updated assignments.',
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FieldSiteEditor(
          repository: repo,
          companyId: company!['id'] as String,
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized)
      return Scaffold(
        appBar: AppBar(title: const Text('CrewClocker')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error == null)
                  const CircularProgressIndicator()
                else
                  Text(error!),
                TextButton(onPressed: refresh, child: const Text('Retry')),
                TextButton(
                  onPressed: () => act(repo.signOutSafely),
                  child: const Text('Sign out safely'),
                ),
              ],
            ),
          ),
        ),
      );
    if (company == null)
      return CompanySetup(
        onCreate: (name, person) => act(() => repo.createCompany(name, person)),
        busy: busy,
        error: error,
        onSignOut: () => act(repo.signOutSafely),
      );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ['Field test', 'Job sites', 'Observations', 'Account'][page],
        ),
        actions: [
          IconButton(
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.sync),
            tooltip: 'Sync',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(onPressed: refresh, child: const Text('Retry')),
                ],
              ),
            Expanded(child: [today(), jobs(), observations(), account()][page]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (p) => setState(() => page = p),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Events'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  Widget today() {
    final ready =
        health['fineLocation'] == true &&
        health['backgroundLocation'] == true &&
        health['locationServices'] == true;
    final monitoring =
        health['enabled'] == true &&
        (health['registeredSites'] as num? ?? 0) > 0 &&
        ready &&
        health['employeeId'] == repo.userId &&
        health['lastError'] == null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          company!['name'] as String,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  monitoring ? Icons.radar : Icons.pause_circle_outline,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  monitoring
                      ? 'Monitoring assigned sites'
                      : 'Monitoring paused or needs setup',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${health['registeredSites'] ?? 0} registered • ${health['pendingEvents'] ?? 0} waiting to sync',
                ),
                if (health['lastError'] != null) Text('${health['lastError']}'),
                const SizedBox(height: 8),
                const Text(
                  'Field test only. Arrivals and departures are observations, not payroll hours.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tracking setup',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const Text(
          'With your permission, CrewClocker detects assigned job-site arrivals and departures even when the app is closed. It stores events on this phone, then uploads them when you reopen the app. It does not record continuous travel routes. Pause monitoring any time below.',
        ),
        ListTile(
          leading: Icon(
            health['fineLocation'] == true
                ? Icons.check_circle
                : Icons.location_on_outlined,
          ),
          title: const Text('1. Allow precise location'),
          subtitle: const Text('Choose Precise and While using the app.'),
          onTap: busy
              ? null
              : () => act(repo.bridge.requestForegroundPermission),
        ),
        ListTile(
          leading: Icon(
            health['backgroundLocation'] == true
                ? Icons.check_circle
                : Icons.settings,
          ),
          title: const Text('2. Allow background location'),
          subtitle: const Text(
            'Open Permissions → Location → Allow all the time. Keep Precise location on.',
          ),
          onTap: busy ? null : () => act(repo.bridge.openSettings),
        ),
        if (health['locationServices'] != true)
          const Text(
            'Turn on your phone’s Location setting before enabling monitoring.',
          ),
        ListTile(
          leading: const Icon(Icons.assignment_outlined),
          title: Text('3. ${assignments.length} assigned job sites'),
          subtitle: const Text(
            'Your saved assignments are registered when you enable monitoring.',
          ),
          onTap: () => setState(() => page = 1),
        ),
        FilledButton.icon(
          onPressed: busy || !ready || assignments.isEmpty
              ? null
              : () => act(() => repo.enable(assignments)),
          icon: const Icon(Icons.play_arrow),
          label: Text(monitoring ? 'Refresh monitoring' : 'Enable monitoring'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => act(() async {
                  await repo.bridge.stop();
                  await repo.sync();
                }),
          child: const Text('Pause monitoring and sync'),
        ),
        TextButton(
          onPressed: busy ? null : refresh,
          child: const Text('Sync observations now'),
        ),
        if (lastSync != null)
          Text(
            'Last successful sync: ${TimeOfDay.fromDateTime(lastSync!).format(context)}',
          ),
        const SizedBox(height: 12),
        const Text(
          'A confirmed dwell takes at least two minutes. Android may deliver background events later. After an offline walk, reopen this app with internet and check Events.',
        ),
      ],
    );
  }

  Widget jobs() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (owner)
        FilledButton.icon(
          onPressed: busy ? null : newSite,
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Add site and assign to me'),
        ),
      const SizedBox(height: 12),
      if (assignments.isEmpty)
        const Text('No sites assigned yet. Add a test site to get started.'),
      ...assignments.map((a) {
        final s = Map<String, dynamic>.from(a['cc_sites'] as Map);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.place),
            title: Text(s['name'] as String),
            subtitle: Text(
              '${s['address']}\n${s['radius_meters']} m radius • assignment v${a['version']}',
            ),
            isThreeLine: true,
          ),
        );
      }),
      const SizedBox(height: 16),
      const Text(
        'This owner-led field build assigns new sites to your account. Crew invitations and assignment editing are a later step.',
      ),
    ],
  );
  Widget observations() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text(
        'Raw arrival and departure observations. These do not calculate work hours.',
      ),
      const SizedBox(height: 12),
      if (pending.isNotEmpty)
        Text(
          '${health['pendingEvents'] ?? pending.length} observations saved on this phone',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ...pending.take(30).map((e) => eventTile(e, local: true)),
      const SizedBox(height: 12),
      const Text(
        'Received by server',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      if (events.isEmpty) const Text('No synced observations yet.'),
      ...events.map((e) => eventTile(e, local: false)),
    ],
  );
  Widget eventTile(Map<String, dynamic> e, {required bool local}) {
    final a = e['cc_assignments'] as Map?;
    final s = a?['cc_sites'] as Map?;
    final site = s?['name']?.toString() ?? 'Assigned site';
    final date = DateTime.tryParse(
      e['observed_at']?.toString() ?? '',
    )?.toLocal();
    return Card(
      child: ListTile(
        leading: Icon(local ? Icons.phone_android : Icons.cloud_done_outlined),
        title: Text('${e['transition']} • $site'),
        subtitle: Text(
          '${date ?? 'Time unavailable'}\n${local ? 'Waiting to upload' : 'Stored on server'}',
        ),
      ),
    );
  }

  Widget account() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        title: Text(repo.client.auth.currentUser?.email ?? 'Signed in'),
        subtitle: Text(owner ? 'Company owner' : 'Company member'),
      ),
      ListTile(
        title: const Text('Device check'),
        leading: const Icon(Icons.phone_android),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DeviceCheckScreen()),
        ),
      ),
      const Text(
        'Sign-out pauses monitoring and syncs pending observations first. If you are offline, reconnect before changing accounts.',
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: busy ? null : () => act(repo.signOutSafely),
        child: const Text('Sign out safely'),
      ),
    ],
  );
}

class CompanySetup extends StatefulWidget {
  const CompanySetup({
    super.key,
    required this.onCreate,
    required this.busy,
    this.error,
    required this.onSignOut,
  });
  final Future<void> Function(String, String) onCreate;
  final bool busy;
  final String? error;
  final VoidCallback onSignOut;
  @override
  State<CompanySetup> createState() => _CompanySetupState();
}

class _CompanySetupState extends State<CompanySetup> {
  final company = TextEditingController(
    text: 'T-Byrd Painting & Construction Services LLC',
  );
  final person = TextEditingController();
  String? validation;
  @override
  void dispose() {
    company.dispose();
    person.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up your company')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Create your owner workspace',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your workspace and its job-site records are isolated from other companies.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: person,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: company,
            decoration: const InputDecoration(labelText: 'Company name'),
          ),
          const SizedBox(height: 16),
          if (validation != null || widget.error != null)
            Text(validation ?? widget.error!),
          FilledButton(
            onPressed: widget.busy
                ? null
                : () {
                    if (person.text.trim().isEmpty ||
                        company.text.trim().isEmpty) {
                      setState(
                        () => validation = 'Enter your name and company name.',
                      );
                      return;
                    }
                    widget.onCreate(company.text.trim(), person.text.trim());
                  },
            child: Text(widget.busy ? 'Creating…' : 'Create owner workspace'),
          ),
          TextButton(
            onPressed: widget.busy ? null : widget.onSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}

class FieldSiteEditor extends StatefulWidget {
  const FieldSiteEditor({
    super.key,
    required this.repository,
    required this.companyId,
  });
  final FieldRepository repository;
  final String companyId;
  @override
  State<FieldSiteEditor> createState() => _FieldSiteEditorState();
}

class _FieldSiteEditorState extends State<FieldSiteEditor> {
  final name = TextEditingController(), address = TextEditingController();
  final map = MapController();
  LatLng? pin;
  double radius = 175;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    address.dispose();
    map.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() => busy = true);
    try {
      final bridge = TrackingBridge();
      await bridge.requestForegroundPermission();
      final fix = await bridge.currentLocation();
      final point = LatLng(
        (fix['lat'] as num).toDouble(),
        (fix['lng'] as num).toDouble(),
      );
      if (mounted) {
        setState(() => pin = point);
        map.move(point, 17);
      }
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Could not locate the phone. Allow precise location, or tap the map to place the pin.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (pin == null || name.text.trim().isEmpty) {
      setState(() => error = 'Enter a name and place the job-site pin.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repository.createSite(widget.companyId, {
        'name': name.text.trim(),
        'address': address.text.trim(),
        'lat': pin!.latitude,
        'lng': pin!.longitude,
        'radius_meters': radius.round(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Site was not saved. Check your connection and owner access, then retry.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New test site')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tap the map to place the pin at your job site. Tap again to adjust it.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: FlutterMap(
              mapController: map,
              options: MapOptions(
                initialCenter: const LatLng(30.5083, -97.6789),
                initialZoom: 12,
                maxZoom: 19,
                onTap: (_, point) {
                  if (!busy) setState(() => pin = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: const String.fromEnvironment(
                    'MAP_TILE_URL',
                    defaultValue:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  userAgentPackageName: 'com.tbyrd.crewclocker.preview',
                ),
                if (pin != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: pin!,
                        radius: radius,
                        useRadiusInMeter: true,
                        color: const Color(0x33087f8c),
                        borderColor: const Color(0xff087f8c),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pin!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_pin,
                          size: 40,
                          color: Color(0xff087f8c),
                        ),
                      ),
                    ],
                  ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: busy ? null : locate,
            icon: const Icon(Icons.my_location),
            label: const Text('Use my current location'),
          ),
          if (pin != null)
            Text(
              'Pin: ${pin!.latitude.toStringAsFixed(5)}, ${pin!.longitude.toStringAsFixed(5)}',
            ),
          TextField(
            controller: name,
            enabled: !busy,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Site name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: address,
            enabled: !busy,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Address label (optional)',
            ),
          ),
          Text(
            'Radius: ${radius.round()} m / ${(radius * 3.28084).round()} ft',
          ),
          Slider(
            value: radius,
            min: 100,
            max: 1000,
            divisions: 36,
            onChanged: busy ? null : (v) => setState(() => radius = v),
          ),
          const Text(
            'This site will be assigned to you. Pause monitoring before changing your assigned sites.',
          ),
          if (error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(error!)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Please wait…' : 'Save and assign to me'),
          ),
        ],
      ),
    ),
  );
}

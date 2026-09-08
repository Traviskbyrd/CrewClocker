import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/crew_repository.dart';
import '../domain/tracking.dart';
import '../platform/tracking_bridge.dart';

const _mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');

class CrewWorkspace extends StatefulWidget {
  const CrewWorkspace({super.key, required this.repository});
  final CrewRepository repository;
  @override
  State<CrewWorkspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<CrewWorkspace> {
  int page = 0;
  bool loading = true;
  String? error;
  String role = 'crew';
  List<JobSite> jobs = [];
  List<Map<String, dynamic>> time = [];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fetchedJobs = await widget.repository.jobs();
      final fetchedTime = await widget.repository.myTime();
      final fetchedRole = await widget.repository.role();
      if (mounted)
        setState(() {
          jobs = fetchedJobs;
          time = fetchedTime;
          role = fetchedRole;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Could not load your workspace. Check your connection and retry.',
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(['Today', 'My time', 'Job sites', 'Account'][page]),
      actions: [
        IconButton(
          onPressed: loading ? null : refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: refresh, child: const Text('Retry')),
              ],
            ),
          )
        : [today(), timeList(), jobsView(), account()][page],
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (value) => setState(() => page = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Today'),
        NavigationDestination(icon: Icon(Icons.schedule), label: 'My time'),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Jobs'),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );
  Widget today() {
    final open = time.where((entry) => entry['clock_out'] == null).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Your workday', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.work_outline, size: 32),
                const SizedBox(height: 12),
                Text(
                  open.isEmpty
                      ? 'No open time record'
                      : '${open.length} open time record${open.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Last loaded from your company records. This is not a live location status.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: ListTile(
            leading: Icon(Icons.construction),
            title: Text('Development build'),
            subtitle: Text(
              'Automatic payroll updates are not enabled. Native capture and server reconciliation must pass verification first.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('${jobs.length} active job sites available'),
      ],
    );
  }

  Widget timeList() => time.isEmpty
      ? const Center(child: Text('No time records yet.'))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: time.length,
          itemBuilder: (context, i) {
            final entry = time[i];
            final start = DateTime.tryParse(
              entry['clock_in']?.toString() ?? '',
            )?.toLocal();
            final end = DateTime.tryParse(
              entry['clock_out']?.toString() ?? '',
            )?.toLocal();
            final job = entry['jobs'] as Map?;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(job?['name']?.toString() ?? 'Job'),
                subtitle: Text(
                  '${start ?? 'Start unavailable'}\n${end == null ? 'Open — needs completion' : 'Ended $end'}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
  Widget jobsView() => Column(
    children: [
      if (role == 'admin' && _mapsEnabled)
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => JobEditor(repository: widget.repository),
                ),
              );
              if (mounted) refresh();
            },
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Create job site'),
          ),
        ),
      Expanded(
        child: jobs.isEmpty
            ? const Center(child: Text('No active job sites.'))
            : !_mapsEnabled
            ? const Center(
                child: Text(
                  'Map preview is not configured yet.\nYour job sites are listed below.',
                  textAlign: TextAlign.center,
                ),
              )
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(jobs.first.latitude, jobs.first.longitude),
                  zoom: 12,
                ),
                markers: jobs
                    .map(
                      (job) => Marker(
                        markerId: MarkerId(job.id),
                        position: LatLng(job.latitude, job.longitude),
                        infoWindow: InfoWindow(
                          title: job.name,
                          snippet: '${job.radiusMeters.round()} m radius',
                        ),
                      ),
                    )
                    .toSet(),
                circles: jobs
                    .map(
                      (job) => Circle(
                        circleId: CircleId(job.id),
                        center: LatLng(job.latitude, job.longitude),
                        radius: job.radiusMeters,
                        fillColor: const Color(0x22087f8c),
                        strokeColor: const Color(0xff087f8c),
                        strokeWidth: 2,
                      ),
                    )
                    .toSet(),
              ),
      ),
      SizedBox(
        height: 140,
        child: ListView(
          children: jobs
              .map(
                (job) => ListTile(
                  title: Text(job.name),
                  subtitle: Text(
                    job.address.isEmpty ? 'Pinned location' : job.address,
                  ),
                  trailing: Text('${job.radiusMeters.round()} m'),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
  Widget account() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(
          widget.repository.client.auth.currentUser?.email ?? 'Signed in',
        ),
        subtitle: Text(role == 'admin' ? 'Administrator' : 'Crew member'),
      ),
      ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: const Text('Tracking diagnostics'),
        subtitle: const Text(
          'Check local permissions and pending observations',
        ),
        onTap: () async {
          String message;
          try {
            message = (await TrackingBridge().health()).entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
          } catch (_) {
            message = 'Native tracking is not available in this build yet.';
          }
          if (mounted)
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Tracking status'),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
        },
      ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Job-site events support timekeeping. CrewClocker does not record continuous travel routes.',
        ),
      ),
      OutlinedButton(
        onPressed: () async {
          // Block logout if pending native events cannot be ruled out; never erase
          // a user's locally captured observations through a casual sign-out.
          try {
            if ((await TrackingBridge().pending()).isNotEmpty) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Pending observations must sync before signing out.',
                    ),
                  ),
                );
              return;
            }
            await TrackingBridge().stop();
            await widget.repository.client.auth.signOut();
          } catch (_) {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not verify pending tracking records. Sign-out is paused to protect them.',
                  ),
                ),
              );
          }
        },
        child: const Text('Sign out'),
      ),
    ],
  );
}

class JobEditor extends StatefulWidget {
  const JobEditor({super.key, required this.repository});
  final CrewRepository repository;
  @override
  State<JobEditor> createState() => _JobEditorState();
}

class _JobEditorState extends State<JobEditor> {
  final name = TextEditingController(), address = TextEditingController();
  LatLng? pin;
  double radius = 175;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (pin == null || name.text.trim().isEmpty) {
      setState(() => error = 'Enter a job name and place its pin.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.saveJob(
        JobSite(
          id: '',
          name: name.text.trim(),
          address: address.text.trim(),
          latitude: pin!.latitude,
          longitude: pin!.longitude,
          radiusMeters: radius,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Job not saved. The secured job-saving service must be available and your account must have permission.',
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New job site')),
    body: Column(
      children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(30.2672, -97.7431),
              zoom: 12,
            ),
            onTap: saving ? null : (point) => setState(() => pin = point),
            markers: pin == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('draft'),
                      position: pin!,
                      draggable: !saving,
                      onDragEnd: (point) => setState(() => pin = point),
                    ),
                  },
            circles: pin == null
                ? {}
                : {
                    Circle(
                      circleId: const CircleId('draft'),
                      center: pin!,
                      radius: radius,
                      fillColor: const Color(0x22087f8c),
                      strokeColor: const Color(0xff087f8c),
                      strokeWidth: 2,
                    ),
                  },
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Tap the map to place a pin. Drag it to adjust.'),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Job name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Address label (optional)',
                    helperText:
                        'Address search is not connected in this development build.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Radius: ${radius.round()} m · ${(radius * 3.28084).round()} ft',
                ),
                Slider(
                  value: radius,
                  min: 100,
                  max: 1000,
                  divisions: 36,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => radius = value),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving…' : 'Save job'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

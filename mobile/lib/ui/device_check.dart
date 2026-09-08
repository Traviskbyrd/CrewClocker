import 'package:flutter/material.dart';

import '../platform/tracking_bridge.dart';

/// Read-only diagnostics are available before an employee account is provisioned.
class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({super.key});

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckState();
}

class _DeviceCheckState extends State<DeviceCheckScreen> {
  Map<String, dynamic>? health;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await TrackingBridge().health();
      if (mounted) setState(() => health = value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not read this phone’s tracking status.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget status(String label, bool ready) => ListTile(
    leading: Icon(ready ? Icons.check_circle_outline : Icons.info_outline),
    title: Text(label),
    trailing: Text(ready ? 'Yes' : 'No'),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Device check')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'CrewClocker • Engineering preview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'This check reads your phone’s settings. It does not start tracking or record work hours.',
          ),
          const SizedBox(height: 20),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!busy && error == null && health != null) ...[
            status('Android connection available', true),
            status('Location services on', health!['locationServices'] == true),
            status('Precise location allowed', health!['fineLocation'] == true),
            status(
              'Background location allowed',
              health!['backgroundLocation'] == true,
            ),
            status('Site monitoring enabled', health!['enabled'] == true),
            ListTile(
              title: const Text('Registered sites'),
              trailing: Text('${health!['registeredSites'] ?? 0}'),
            ),
            ListTile(
              title: const Text('Pending observations'),
              trailing: Text('${health!['pendingEvents'] ?? 0}'),
            ),
            if (health!['lastError'] != null)
              ListTile(
                title: const Text('Last tracking issue'),
                subtitle: Text('${health!['lastError']}'),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Check again'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Location permissions can remain off for this installation check. '
            'Automatic timekeeping and account onboarding are still being completed.',
          ),
        ],
      ),
    ),
  );
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../platform/tracking_bridge.dart';

List<String> validatedAcknowledgements(
  List<Map<String, dynamic>> sent,
  dynamic received,
) {
  if (received is! List || received.any((id) => id is! String)) {
    throw StateError('Invalid server acknowledgement');
  }
  final expected = sent.map((e) => e['event_id'] as String).toSet();
  final ids = received.cast<String>();
  if (ids.length != expected.length ||
      ids.toSet().length != ids.length ||
      ids.any((id) => !expected.contains(id))) {
    throw StateError('Server did not acknowledge the exact batch');
  }
  return ids;
}

class FieldRepository {
  FieldRepository(this.client, {TrackingBridge? bridge})
    : bridge = bridge ?? TrackingBridge();
  final SupabaseClient client;
  final TrackingBridge bridge;
  Future<int>? _syncFlight;
  String get userId => client.auth.currentUser!.id;
  Future<List<Map<String, dynamic>>> companies() async =>
      await client.from('cc_companies').select().order('created_at');
  Future<void> createCompany(String name, String person) async =>
      await client.rpc(
        'cc_create_company',
        params: {'company_name': name, 'person_name': person},
      );
  Future<List<Map<String, dynamic>>> assignments(String company) async =>
      await client
          .from('cc_assignments')
          .select('*, cc_sites(*)')
          .eq('company_id', company)
          .eq('user_id', userId)
          .eq('active', true)
          .order('id');
  Future<void> createSite(String company, Map<String, dynamic> site) async =>
      await client.rpc(
        'cc_create_site',
        params: {'company': company, 'site': site, 'assigned_user': userId},
      );
  Future<void> manageSite(String company, String siteId, {String? name, int? radius, bool delete = false}) async {
    final wasEnabled = (await bridge.health())['enabled'] == true;
    await bridge.stop();
    await sync();
    if ((await bridge.pending()).isNotEmpty) {
      throw StateError('Sync all pending observations before changing a job. Monitoring is paused.');
    }
    try {
      await client.rpc('cc_manage_site', params: {
        'target': siteId, 'new_name': name, 'new_radius': radius, 'remove_site': delete,
      });
      final updated = await assignments(company);
      if (wasEnabled && updated.isNotEmpty) await enable(updated);
    } catch (_) {
      throw StateError('The job change or monitoring refresh could not be confirmed. Check Jobs and monitoring status before retrying. Pending observations are kept.');
    }
  }

  Future<List<Map<String, dynamic>>> events() async => await client
      .from('cc_observations')
      .select('*, cc_assignments(cc_sites(name))')
      .eq('employee_id', userId)
      .order('observed_at', ascending: false)
      .limit(100);

  /// One in-flight upload per workspace. Native capture has no dependency on this.
  Future<int> sync() =>
      _syncFlight ??= _upload().whenComplete(() => _syncFlight = null);
  Future<int> _upload() async {
    final owner = userId;
    var total = 0;
    for (var batch = 0; batch < 20; batch++) {
      final pending = await bridge.pending();
      if (pending.isEmpty) return total;
      if (pending.any(
        (e) => e['employee_id'] != owner || e['assignment_id'] == null,
      )) {
        throw StateError(
          'Sign in to the original account to sync pending observations.',
        );
      }
      final accepted = await client.rpc(
        'cc_ingest_observations',
        params: {'events': pending},
      );
      final ids = validatedAcknowledgements(pending, accepted);
      if (client.auth.currentUser?.id != owner)
        throw StateError('Account changed during sync');
      await bridge.acknowledge(ids);
      total += ids.length;
    }
    return total;
  }

  Future<void> enable(List<Map<String, dynamic>> assignments) async {
    if (assignments.isEmpty)
      throw StateError('Create an assigned job site first.');
    await bridge.registerAssignments(
      userId,
      assignments
          .map(
            (a) => {
              ...Map<String, dynamic>.from(a['cc_sites'] as Map),
              'assignment_id': a['id'],
              'assignment_version': a['version'],
            },
          )
          .toList(),
    );
  }

  Future<void> signOutSafely() async {
    await bridge.stop();
    final queued = await bridge.pending();
    // A wrong-account login must not trap the user away from the queue's owner.
    // Preserve every row; allow this account to leave so the owner can sign in.
    if (queued.any((e) => e['employee_id'] != userId)) {
      await client.auth.signOut();
      return;
    }
    await sync();
    if ((await bridge.pending()).isNotEmpty)
      throw StateError('Sync pending observations before signing out.');
    await client.auth.signOut();
  }
}

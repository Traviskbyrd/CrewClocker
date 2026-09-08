import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/tracking.dart';

/// Read access to the existing prototype schema. Mutation RPCs are deliberately
/// versioned and must be deployed with company/role checks before writes work.
class CrewRepository {
  CrewRepository(this.client);
  final SupabaseClient client;
  Future<List<JobSite>> jobs() async {
    final rows = await client
        .from('jobs')
        .select()
        .eq('status', 'active')
        .order('name');
    return rows.map(JobSite.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> myTime() async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in to view time.');
    return await client
        .from('time_entries')
        .select('*, jobs(name)')
        .eq('crew_id', user.id)
        .order('clock_in', ascending: false)
        .limit(100);
  }

  Future<String> role() async {
    final user = client.auth.currentUser;
    if (user == null) return 'crew';
    final row = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return row?['role'] as String? ?? 'crew';
  }

  Future<void> saveJob(JobSite site) async {
    final error = site.validate();
    if (error != null) throw ArgumentError(error);
    await client.rpc(
      'crewclocker_save_job_v1',
      params: {'site': site.toJson()},
    );
  }
}

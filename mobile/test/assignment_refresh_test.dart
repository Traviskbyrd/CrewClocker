import 'package:crewclocker/data/field_repository.dart';
import 'package:crewclocker/platform/tracking_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class FakeBridge extends TrackingBridge {
  Map<String, dynamic> state = {'enabled': true, 'employeeId': 'worker', 'assignmentIds': ['old']};
  int stops = 0;
  @override
  Future<Map<String, dynamic>> health() async => state;
  @override
  Future<void> stop() async { stops++; }
}
class FakeRepository extends FieldRepository {
  FakeRepository(FakeBridge bridge) : super(SupabaseClient('https://example.invalid', 'test'), bridge: bridge);
  int registrations = 0;
  @override
  String get userId => 'worker';
  @override
  Future<void> enable(List<Map<String, dynamic>> assignments) async { registrations++; }
}
void main() {
  test('refresh changes active assignments but never reverses a pause', () async {
    final bridge = FakeBridge();
    final repo = FakeRepository(bridge);
    await repo.reconcileAssignments([{'id': 'old'}]);
    expect(repo.registrations, 0);
    await repo.reconcileAssignments([{'id': 'new'}]);
    expect(repo.registrations, 1);
    await repo.reconcileAssignments([]);
    expect(bridge.stops, 1);
    bridge.state['enabled'] = false;
    await repo.reconcileAssignments([{'id': 'new'}]);
    expect(repo.registrations, 1);
    bridge.state['enabled'] = true;
    bridge.state['employeeId'] = 'someone-else';
    await repo.reconcileAssignments([{'id': 'new'}]);
    expect(repo.registrations, 1);
    await repo.client.dispose();
  });
}

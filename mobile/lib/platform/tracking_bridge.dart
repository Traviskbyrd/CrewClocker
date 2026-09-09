import 'package:flutter/services.dart';

import '../domain/tracking.dart';

class TrackingBridge {
  static const _channel = MethodChannel('com.tbyrd.crewclocker/tracking');
  Future<Map<String, dynamic>> health() async => Map<String, dynamic>.from(
    await _channel.invokeMapMethod<String, dynamic>('health') ?? {},
  );
  Future<Map<String, dynamic>> currentLocation() async =>
      Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('currentLocation') ??
            {},
      );
  Future<void> registerAssignments(
    String employeeId,
    List<Map<String, dynamic>> sites,
  ) => _channel.invokeMethod('register', {
    'employeeId': employeeId,
    'sites': sites,
  });
  Future<void> requestForegroundPermission() =>
      _channel.invokeMethod('requestForegroundPermission');
  Future<void> openSettings() => _channel.invokeMethod('openSettings');
  Future<void> register(String employeeId, List<JobSite> sites) =>
      _channel.invokeMethod('register', {
        'employeeId': employeeId,
        'sites': sites.map((site) => site.toJson()).toList(),
      });
  Future<List<Map<String, dynamic>>> pending() async =>
      (await _channel.invokeListMethod<dynamic>('pending') ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
  Future<void> acknowledge(List<String> ids) =>
      _channel.invokeMethod('acknowledge', {'ids': ids});
  Future<void> stop() => _channel.invokeMethod('stop');
}

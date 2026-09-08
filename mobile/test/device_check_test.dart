import 'package:crewclocker/main.dart';
import 'package:crewclocker/ui/device_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('com.tbyrd.crewclocker/tracking');
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'device check works without account setup and never registers sites',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return {
              'locationServices': true,
              'fineLocation': false,
              'backgroundLocation': false,
              'enabled': false,
              'registeredSites': 0,
              'pendingEvents': 0,
            };
          });
      await tester.pumpWidget(
        const CrewClockerApp(setupError: 'Setup required'),
      );
      await tester.tap(find.text('Check this phone'));
      await tester.pumpAndSettle();
      expect(find.text('Android connection available'), findsOneWidget);
      expect(find.text('Site monitoring enabled'), findsOneWidget);
      expect(calls, ['health']);
    },
  );

  testWidgets('device check reports channel failure and can retry', (
    tester,
  ) async {
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          attempts++;
          throw PlatformException(code: 'UNAVAILABLE');
        });
    await tester.pumpWidget(const MaterialApp(home: DeviceCheckScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not read this phone’s tracking status.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('sign-in rejects empty credentials before network access', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter your email and password.'), findsOneWidget);
  });
}

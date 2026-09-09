import 'package:crewclocker/data/field_repository.dart';
import 'package:crewclocker/ui/field_workspace.dart';
import 'package:crewclocker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sent = [
    <String, dynamic>{'event_id': 'one'},
    <String, dynamic>{'event_id': 'two'},
  ];
  test(
    'only an exact durable server acknowledgement clears the native batch',
    () {
      expect(validatedAcknowledgements(sent, ['two', 'one']), ['two', 'one']);
      for (final bad in <dynamic>[
        null,
        ['one'],
        ['one', 'other'],
        ['one', 'one'],
        [1, 2],
      ]) {
        expect(() => validatedAcknowledgements(sent, bad), throwsStateError);
      }
    },
  );
  testWidgets('owner setup requires a name before creating a workspace', (
    tester,
  ) async {
    var created = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CompanySetup(
          onCreate: (a, b) async {
            created = true;
          },
          busy: false,
          onSignOut: () {},
        ),
      ),
    );
    await tester.tap(find.text('Create owner workspace'));
    await tester.pump();
    expect(find.text('Enter your name and company name.'), findsOneWidget);
    expect(created, isFalse);
    await tester.enterText(find.byType(TextField).first, 'Travis');
    await tester.tap(find.text('Create owner workspace'));
    await tester.pump();
    expect(created, isTrue);
  });
  testWidgets('signup rejects a short password without sending an email', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));
    await tester.tap(find.text('New owner? Create an account'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).first,
      'owner@example.invalid',
    );
    await tester.enterText(find.byType(TextField).last, 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(
      find.text('Use a password with at least 10 characters.'),
      findsOneWidget,
    );
  });
}

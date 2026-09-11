import 'package:crewclocker/ui/operations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('crew invitation form retains chosen role and phone contact', (tester) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(onPressed: () async {
      submitted = await entryForm(context, 'Invite person', [const EntryField('contact', 'Phone number'), const EntryField('role', 'Access level', value: 'employee', options: {'employee': 'Crew member', 'sub_lead': 'Subcontractor lead'})]);
    }, child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+1 512 555 0123');
    await tester.tap(find.text('Crew member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subcontractor lead').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(submitted, {'contact': '+1 512 555 0123', 'role': 'sub_lead'});
  });
}

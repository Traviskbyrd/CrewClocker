import 'package:crewclocker/ui/edit_job.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('invalid radius keeps the editor open; valid edit returns values', (tester) async {
    JobEdit? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        result = await Navigator.of(context).push<JobEdit>(MaterialPageRoute(
          builder: (_) => const EditJobPage(name: 'Old name', radius: 100)));
      }, child: const Text('Open')),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'New name');
    await tester.enterText(find.byType(TextFormField).last, '24');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(result, isNull);
    expect(find.text('Enter a whole number from 25 to 1000.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '50');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(result?.name, 'New name');
    expect(result?.radius, 50);
  });
}

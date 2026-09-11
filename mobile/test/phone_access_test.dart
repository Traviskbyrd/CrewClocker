import 'package:crewclocker/ui/phone_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('phone normalization preserves international country codes', () {
    expect(normalizePhone('(512) 555-0123'), '+15125550123');
    expect(normalizePhone('+44 7700 900123'), '+447700900123');
    expect(normalizePhone('512'), isNull);
    expect(normalizePhone('name@example.com'), isNull);
    expect(normalizePhone('+01234567890'), isNull);
  });
  testWidgets('invalid phone never requests an SMS', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneAccess()));
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Enter a phone number with country code, such as +1 512 555 0123.'), findsOneWidget);
  });
}

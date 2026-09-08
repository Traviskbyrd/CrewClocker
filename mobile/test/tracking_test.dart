import 'package:flutter_test/flutter_test.dart';

import 'tracking_standalone.dart' as checks;

void main() {
  test('event ledger invariants and site validation', checks.main);
}

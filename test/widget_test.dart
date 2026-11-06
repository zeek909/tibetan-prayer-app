import 'package:flutter_test/flutter_test.dart';
import 'package:tibetan_prayer_app/data/tibcal.dart';

void main() {
  test('Losar 2026 falls on 18 February 2026', () {
    final t = TibCal.forDate(DateTime(2026, 2, 18));
    expect(t, isNotNull);
    expect(t!.month, 1);
    expect(t.day, 1);
    expect(t.leap, isFalse);
  });
}

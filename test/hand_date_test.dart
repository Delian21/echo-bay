import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/design_system/hand_date.dart';

void main() {
  group('hand date voice', () {
    test('stamp form is short, handwritten, and includes the clock', () {
      final at = DateTime(2026, 10, 2, 18, 40);
      expect(handDateTime(at), 'Fri 2 Oct · 18:40');
    });

    test('pads the clock to two digits', () {
      expect(handDateTime(DateTime(2026, 1, 5, 7, 5)), 'Mon 5 Jan · 07:05');
    });

    test('long form spells the day and month out', () {
      expect(
        handDayLine(DateTime(2026, 10, 2)),
        'Friday, October 2',
      );
    });
  });
}
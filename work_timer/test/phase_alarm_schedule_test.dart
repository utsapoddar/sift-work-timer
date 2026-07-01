import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/schedule.dart';

void main() {
  test('shiftedPhaseEndTimes delays every phase boundary after pause', () {
    final start = DateTime.fromMillisecondsSinceEpoch(1767225600000);
    final schedule = Schedule.create(start, 9 * 60);

    final shifted = shiftedPhaseEndTimes(schedule, 90 * 1000);

    expect(shifted, hasLength(schedule.phases.length));
    for (var i = 0; i < schedule.phases.length; i++) {
      expect(
        shifted[i].millisecondsSinceEpoch,
        schedule.phases[i].endTime
            .add(const Duration(seconds: 90))
            .millisecondsSinceEpoch,
      );
    }
  });
}

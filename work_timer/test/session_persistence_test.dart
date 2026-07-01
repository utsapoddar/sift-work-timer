import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/schedule.dart';

void main() {
  test('Schedule serializes and rehydrates phase metadata and timestamps', () {
    final start = DateTime.fromMillisecondsSinceEpoch(1767225600000);
    final schedule = Schedule.create(start, 9 * 60);

    final restored = Schedule.fromJson(schedule.toJson());

    expect(
      restored.sessionStart.millisecondsSinceEpoch,
      schedule.sessionStart.millisecondsSinceEpoch,
    );
    expect(restored.totalMinutes, schedule.totalMinutes);
    expect(restored.phases.length, schedule.phases.length);

    for (var i = 0; i < schedule.phases.length; i++) {
      final original = schedule.phases[i];
      final rehydrated = restored.phases[i];

      expect(rehydrated.index, original.index);
      expect(
        rehydrated.startTime.millisecondsSinceEpoch,
        original.startTime.millisecondsSinceEpoch,
      );
      expect(
        rehydrated.endTime.millisecondsSinceEpoch,
        original.endTime.millisecondsSinceEpoch,
      );
      expect(rehydrated.phase.name, original.phase.name);
      expect(rehydrated.phase.description, original.phase.description);
      expect(rehydrated.phase.duration, original.phase.duration);
      expect(rehydrated.phase.isBreak, original.phase.isBreak);
    }
  });
}

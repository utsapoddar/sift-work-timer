import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/phase_alarm_gate.dart';

void main() {
  test('stopping a phase alarm shifts future phases by alarm wait time', () {
    final gateStart = DateTime.fromMillisecondsSinceEpoch(10000);
    final stoppedAt = DateTime.fromMillisecondsSinceEpoch(25000);

    final resolved = resolvePhaseAlarmGate(
      totalPausedMs: 2000,
      gateStartedAt: gateStart,
      stoppedAt: stoppedAt,
      pendingPhaseIndex: 1,
    );

    expect(resolved.totalPausedMs, 17000);
    expect(resolved.activePhaseIndex, 1);
  });
}

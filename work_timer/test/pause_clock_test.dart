import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/pause_clock.dart';

void main() {
  test('scheduleNow freezes logical time while actively paused', () {
    final wallNow = DateTime.fromMillisecondsSinceEpoch(30000);
    final pauseStart = DateTime.fromMillisecondsSinceEpoch(10000);

    final now = scheduleNow(
      wallNow: wallNow,
      totalPausedMs: 5000,
      isPaused: true,
      pauseStart: pauseStart,
    );

    expect(now.millisecondsSinceEpoch, 5000);
  });

  test('scheduleNow only subtracts accumulated pauses while running', () {
    final wallNow = DateTime.fromMillisecondsSinceEpoch(30000);

    final now = scheduleNow(
      wallNow: wallNow,
      totalPausedMs: 5000,
      isPaused: false,
      pauseStart: DateTime.fromMillisecondsSinceEpoch(10000),
    );

    expect(now.millisecondsSinceEpoch, 25000);
  });
  test('home tick does not advance while paused', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(
      source,
      contains(
        'if (schedule == null || _waitingForAlarmStop || _paused) return;',
      ),
    );
  });
}

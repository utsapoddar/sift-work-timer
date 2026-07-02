import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Live Activity is not marked stale while paused or alarm is playing',
    () {
      final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

      expect(
        source,
        contains('let staleDate: Date? = (isPaused || alarmPlaying)'),
      );
      expect(source, contains('staleDate: staleDate'));
    },
  );
}

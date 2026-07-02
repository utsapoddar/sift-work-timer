import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS exposes output volume so the app can warn before quiet alarms', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final dart = File('lib/services/live_activity.dart').readAsStringSync();

    expect(swift, contains('getOutputVolume'));
    expect(swift, contains('AVAudioSession.sharedInstance().outputVolume'));
    expect(dart, contains('getOutputVolume'));
  });

  test('alarm UI warns when iOS media volume is low', () {
    final source = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(source, contains('_maybeWarnLowAlarmVolume'));
    expect(source, contains('iPhone volume is low'));
  });

  test('iOS alarm vibration uses a stronger repeated haptic burst', () {
    final source = File('lib/services/alarm_vibration.dart').readAsStringSync();

    expect(source, contains('Platform.isIOS'));
    expect(source, contains('HapticFeedback.heavyImpact'));
    expect(source, contains('Duration(seconds: 1)'));
  });
}

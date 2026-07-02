import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

Timer? _vibrationTimer;
Timer? _burstTimerOne;
Timer? _burstTimerTwo;

void startAlarmVibration() {
  stopAlarmVibration();
  _pulseAlarmVibration();
  _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    _pulseAlarmVibration();
  });
}

void _pulseAlarmVibration() {
  if (Platform.isIOS) {
    HapticFeedback.heavyImpact();
    _burstTimerOne = Timer(const Duration(milliseconds: 180), () {
      HapticFeedback.vibrate();
    });
    _burstTimerTwo = Timer(const Duration(milliseconds: 360), () {
      HapticFeedback.heavyImpact();
    });
  } else {
    HapticFeedback.vibrate();
  }
}

void stopAlarmVibration() {
  _vibrationTimer?.cancel();
  _vibrationTimer = null;
  _burstTimerOne?.cancel();
  _burstTimerOne = null;
  _burstTimerTwo?.cancel();
  _burstTimerTwo = null;
}

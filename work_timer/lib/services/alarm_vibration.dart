import 'dart:async';

import 'package:flutter/services.dart';

Timer? _vibrationTimer;

void startAlarmVibration() {
  stopAlarmVibration();
  HapticFeedback.vibrate();
  _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
    HapticFeedback.vibrate();
  });
}

void stopAlarmVibration() {
  _vibrationTimer?.cancel();
  _vibrationTimer = null;
}

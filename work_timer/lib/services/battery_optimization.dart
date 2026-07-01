import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const batteryOptimizationPromptedKey = 'battery_opt_prompted';
const _channel = MethodChannel('com.sift.live_activity');

bool shouldShowBatteryOptimizationPromptForState({
  required bool isAndroid,
  required bool isIgnoringBatteryOptimizations,
  required bool alreadyPrompted,
}) {
  return isAndroid && !isIgnoringBatteryOptimizations && !alreadyPrompted;
}

Future<bool> isIgnoringBatteryOptimizations() async {
  if (!Platform.isAndroid) return true;
  try {
    return await _channel.invokeMethod<bool>(
          'isIgnoringBatteryOptimizations',
        ) ??
        true;
  } catch (_) {
    return true;
  }
}

Future<void> openBatteryOptimizationSettings() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod('openBatteryOptimizationSettings');
  } catch (_) {}
}

Future<bool> shouldPromptForBatteryOptimization() async {
  if (!Platform.isAndroid) return false;
  final prefs = await SharedPreferences.getInstance();
  final alreadyPrompted =
      prefs.getBool(batteryOptimizationPromptedKey) ?? false;
  final ignoringOptimizations = await isIgnoringBatteryOptimizations();
  return shouldShowBatteryOptimizationPromptForState(
    isAndroid: true,
    isIgnoringBatteryOptimizations: ignoringOptimizations,
    alreadyPrompted: alreadyPrompted,
  );
}

Future<void> markBatteryOptimizationPrompted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(batteryOptimizationPromptedKey, true);
}

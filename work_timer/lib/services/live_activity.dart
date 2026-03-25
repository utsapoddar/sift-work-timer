import 'dart:io';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.sift.live_activity');

/// Returns an error message string if it fails, null on success.
Future<String?> startLiveActivity({
  required String phaseName,
  required DateTime phaseEndTime,
  required int remainingSeconds,
  required int totalSeconds,
  required bool isBreak,
}) async {
  if (!Platform.isIOS) return null;
  try {
    await _channel.invokeMethod('startLiveActivity', {
      'phaseName': phaseName,
      'phaseEndMs': phaseEndTime.millisecondsSinceEpoch.toDouble(),
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'isBreak': isBreak,
    });
    return null;
  } on PlatformException catch (e) {
    return e.message ?? e.code;
  } catch (e) {
    return e.toString();
  }
}

Future<void> updateLiveActivity({
  required String phaseName,
  required DateTime phaseEndTime,
  required int remainingSeconds,
  required int totalSeconds,
  required bool isBreak,
  required bool isPaused,
  required bool alarmPlaying,
}) async {
  if (!Platform.isIOS) return;
  try {
    await _channel.invokeMethod('updateLiveActivity', {
      'phaseName': phaseName,
      'phaseEndMs': phaseEndTime.millisecondsSinceEpoch.toDouble(),
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'isBreak': isBreak,
      'isPaused': isPaused,
      'alarmPlaying': alarmPlaying,
    });
  } catch (_) {}
}

Future<void> endLiveActivity() async {
  if (!Platform.isIOS) return;
  try {
    await _channel.invokeMethod('endLiveActivity');
  } catch (_) {}
}

/// Start silent background audio loop — keeps app alive so alarm fires even on silent.
Future<void> startTimerAudio() async {
  if (!Platform.isIOS) return;
  try { await _channel.invokeMethod('startTimerAudio'); } catch (_) {}
}

/// Stop the background audio loop.
Future<void> stopTimerAudio() async {
  if (!Platform.isIOS) return;
  try { await _channel.invokeMethod('stopTimerAudio'); } catch (_) {}
}

/// Start Android foreground service and schedule exact alarms at each phase boundary.
Future<void> startTimerService({
  required List<String> phaseNames,
  required List<DateTime> phaseEndTimes,
}) async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod('startTimerService', {
      'phaseNames': phaseNames,
      'phaseEndTimes': phaseEndTimes.map((t) => t.millisecondsSinceEpoch).toList(),
    });
  } catch (_) {}
}

/// Stop the Android foreground service.
Future<void> stopTimerService() async {
  if (!Platform.isAndroid) return;
  try { await _channel.invokeMethod('stopTimerService'); } catch (_) {}
}

/// Silence the alarm sound in the Android foreground service without stopping the timer.
Future<void> silenceTimerService() async {
  if (!Platform.isAndroid) return;
  try { await _channel.invokeMethod('silenceTimerService'); } catch (_) {}
}

/// Returns the picked file path, or null if cancelled.
Future<String?> pickAudioFile() async {
  if (!Platform.isIOS) return null;
  try {
    final path = await _channel.invokeMethod<String>('pickAudioFile');
    return path;
  } catch (_) {
    return null;
  }
}

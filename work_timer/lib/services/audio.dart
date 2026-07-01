import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'alarm_vibration.dart';

final _player = AudioPlayer();
StreamSubscription<void>? _alarmCompleteSub;

/// Emits when the alarm finishes playing naturally.
Stream<void> get onAlarmComplete => _player.onPlayerComplete;

/// Custom ringtone path set by the user. Null = use bundled alarm.mp3.
String? customRingtonePath;

void _ensureVibrationStopsOnCompletion() {
  _alarmCompleteSub ??= _player.onPlayerComplete.listen((_) {
    stopAlarmVibration();
  });
}

Future<void> playAlarm({bool loop = false}) async {
  _ensureVibrationStopsOnCompletion();
  try {
    await _player.stop();
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
    stopAlarmVibration();
    if (Platform.isAndroid) {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
            isSpeakerphoneOn: false,
            stayAwake: false,
          ),
        ),
      );
    } else if (Platform.isIOS) {
      await _player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
        ),
      );
    }
    final custom = customRingtonePath;
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      await _player.play(DeviceFileSource(custom));
      startAlarmVibration();
    } else {
      await _player.play(AssetSource('alarm.mp3'));
      startAlarmVibration();
    }
  } catch (_) {
    try {
      await _player.play(AssetSource('alarm.wav'));
      startAlarmVibration();
    } catch (_) {}
  }
}

Future<void> stopAlarm() async {
  stopAlarmVibration();
  try {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.release);
  } catch (_) {}
}

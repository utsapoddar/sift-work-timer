import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

final _player = AudioPlayer();

/// Emits when the alarm finishes playing naturally.
Stream<void> get onAlarmComplete => _player.onPlayerComplete;

/// Custom ringtone path set by the user. Null = use bundled alarm.mp3.
String? customRingtonePath;

Future<void> playAlarm() async {
  try {
    await _player.stop();
    if (Platform.isAndroid) {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
          isSpeakerphoneOn: false,
          stayAwake: false,
        ),
      ));
    } else if (Platform.isIOS) {
      await _player.setAudioContext(AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {},
        ),
      ));
    }
    final custom = customRingtonePath;
    if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
      await _player.play(DeviceFileSource(custom));
    } else {
      await _player.play(AssetSource('alarm.mp3'));
    }
  } catch (_) {
    try {
      await _player.play(AssetSource('alarm.wav'));
    } catch (_) {}
  }
}

Future<void> stopAlarm() async {
  try {
    await _player.stop();
  } catch (_) {}
}

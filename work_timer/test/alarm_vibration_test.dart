import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/alarm_vibration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    stopAlarmVibration();
  });

  test('startAlarmVibration triggers platform vibration immediately', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });

    startAlarmVibration();
    await Future<void>.delayed(Duration.zero);

    expect(calls, hasLength(1));
    expect(calls.single.method, 'HapticFeedback.vibrate');
  });
}

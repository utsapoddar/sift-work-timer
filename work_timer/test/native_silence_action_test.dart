import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/timer_action_policy.dart';

void main() {
  test('native silence action is not echoed back to native service', () {
    expect(shouldNotifyNativeWhenStoppingAlarm(nativeOrigin: true), isFalse);
  });

  test('local silence action still notifies native service', () {
    expect(shouldNotifyNativeWhenStoppingAlarm(nativeOrigin: false), isTrue);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android timer notification body opens MainActivity', () {
    final source = File(
      'android/app/src/main/kotlin/com/utsapoddar/sift/TimerService.kt',
    ).readAsStringSync();

    expect(source, contains('PendingIntent.getActivity'));
    expect(source, contains('MainActivity::class.java'));
    expect(source, contains('.setContentIntent('));
  });
}

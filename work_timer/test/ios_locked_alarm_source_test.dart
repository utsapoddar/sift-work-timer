import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS locked alarms use bundled sound and repeat bursts', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final notifications = File(
      'lib/services/notifications.dart',
    ).readAsStringSync();

    expect(File('ios/Runner/alarm.caf').existsSync(), isTrue);
    expect(project, contains('alarm.caf in Resources'));
    expect(
      notifications,
      contains(
        'final burstCount = Platform.isIOS ? _completionBurstCount : 1;',
      ),
    );
  });
}

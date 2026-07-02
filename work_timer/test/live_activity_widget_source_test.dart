import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Live Activity uses animated linear timer progress instead of fixed circle', () {
    final source = File(
      'ios/SiftWidget/SiftWidgetLiveActivity.swift',
    ).readAsStringSync();

    expect(source, contains('ProgressView(timerInterval:'));
    expect(source, contains('LinearProgressViewStyle'));
    expect(source, isNot(contains('Circle()')));
    expect(source, isNot(contains('.trim(from: 0, to: progress)')));
  });
}

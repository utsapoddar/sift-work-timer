import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/battery_optimization.dart';

void main() {
  test(
    'shows battery optimization prompt only on first non-exempt Android start',
    () {
      expect(
        shouldShowBatteryOptimizationPromptForState(
          isAndroid: true,
          isIgnoringBatteryOptimizations: false,
          alreadyPrompted: false,
        ),
        isTrue,
      );

      expect(
        shouldShowBatteryOptimizationPromptForState(
          isAndroid: true,
          isIgnoringBatteryOptimizations: true,
          alreadyPrompted: false,
        ),
        isFalse,
      );

      expect(
        shouldShowBatteryOptimizationPromptForState(
          isAndroid: true,
          isIgnoringBatteryOptimizations: false,
          alreadyPrompted: true,
        ),
        isFalse,
      );

      expect(
        shouldShowBatteryOptimizationPromptForState(
          isAndroid: false,
          isIgnoringBatteryOptimizations: false,
          alreadyPrompted: false,
        ),
        isFalse,
      );
    },
  );
}

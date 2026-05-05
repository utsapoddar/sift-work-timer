# CLAUDE.md

## Purpose
Sift Flutter work timer app for iOS, Android, and macOS with Live Activities/background alarms.

## Key Paths
- `lib/screens/home_screen.dart` — main timer UI.
- `lib/services/live_activity.dart` — Dart wrapper for Live Activity and timer-action channels.
- `lib/services/notifications.dart` — local notification/alarm behavior.
- `ios/Runner/AppDelegate.swift` — iOS MethodChannels, file picker, background audio, Darwin notifications.
- `ios/SiftWidget/` — Live Activity/Dynamic Island widget extension and buttons.
- `android/app/src/main/kotlin/com/utsapoddar/sift/TimerService.kt` — Android foreground service.
- `test/` — Flutter tests.
- `../release.sh` — release script; desktop shortcut is `~/Desktop/sift_release.command`.

## Landmines
- iOS 26 deployment target `26.2` is intentional; do not revert to `16.2`.
- Do not use `UIApplication.shared.windows`; use `UIWindowScene` for presentation.
- `file_picker` is broken on iOS 26; native `UIDocumentPickerViewController` via MethodChannel is intentional.
- Widget extension needs manual `ios/SiftWidget/Info.plist` with `NSExtension`; avoid duplicate Info.plist resources.
- In `didInitializeImplicitFlutterEngine`, use a plugin registrar messenger, not `window?.rootViewController`.
- iOS background alarm needs `UIBackgroundModes=audio`, `AVAudioSession.playback`, and silent `AVAudioEngine` loop.
- Live Activity buttons use Darwin notifications; no App Groups unless explicitly requested.
- Android background timer needs a foreground service and media playback foreground-service permissions.
- Android alarm audio uses `AndroidUsageType.alarm`; `AudioContext` is non-const.

## Skip
- `build/`
- `.dart_tool/`
- `.idea/`
- release artifacts: `*.ipa`, `*.zip`

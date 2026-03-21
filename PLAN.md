# Work Session Timer App — Plan

## Context
Replaces manual phone alarm setup with an app that auto-generates a full work session schedule on "Play" press. Must work in the background on all platforms — alarms fire even when phone is locked or app is closed.

---

## Architecture: Flutter (single codebase, all 4 platforms)

| Platform | Output | Cost |
|---|---|---|
| Mac | `.app` / `.dmg` | Free |
| Windows | `.exe` / `.msi` | Free |
| iOS | `.ipa` (Xcode direct install) | Free (re-sign every 7 days) or $99/yr Apple Dev account |
| Android | `.apk` sideload | Free |

---

## Key Behavior

User presses **Play** → app records that moment as session start, calculates 7 transition timestamps, and schedules all 7 OS-level local notifications at once. The OS delivers them regardless of whether the app is open, minimized, or closed.

---

## Schedule Algorithm

```dart
workBlock = (totalMinutes - 90) / 4   // e.g. 112.5 min for 9h session

Phases:
  Work        → workBlock
  Short Break → 15 min
  Work        → workBlock
  Lunch       → 60 min
  Work        → workBlock
  Short Break → 15 min
  Work        → workBlock
  Done
```

---

## Project Structure

```
work_timer/
  lib/
    main.dart
    screens/home_screen.dart      ← UI: timer, progress bar, schedule list, play/stop
    services/schedule.dart        ← phase calculation
    services/notifications.dart   ← schedule/cancel all 7 OS notifications
    services/audio.dart           ← foreground alarm playback
  assets/alarm.wav                ← bundled alarm sound
  pubspec.yaml
```

---

## UI Mockup

```
┌─────────────────────────────┐
│  Work Timer        [⚙ 9h]  │
│                             │
│       WORKING               │
│       1:52:30  remaining    │
│       ████████░░░  bar      │
│                             │
│     [▶ Play]  [■ Stop]     │
│                             │
│  Today's Schedule           │
│  ✓ 1:00 PM  Work starts    │
│  → 2:52 PM  Break (15 min) │
│    3:07 PM  Back to work   │
│    5:00 PM  Lunch (1 hr)   │
│    6:00 PM  Back to work   │
│    7:52 PM  Break (15 min) │
│    8:07 PM  Back to work   │
│   10:00 PM  Done           │
└─────────────────────────────┘
```

---

## Dependencies

```yaml
flutter_local_notifications: ^17.0.0   # background-safe OS notifications
audioplayers: ^6.0.0                    # foreground audio
timezone: ^0.9.0                        # required by flutter_local_notifications
```

---

## Build Commands

```bash
flutter pub get
flutter run -d macos              # dev on Mac
flutter build macos               # Mac .app
flutter build apk                 # Android .apk
flutter build ipa                 # iOS (needs Xcode + Apple Dev account)
flutter build windows             # Windows .exe (run on Windows)
```

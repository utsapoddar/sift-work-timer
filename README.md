# Sift

A work session timer for iOS, Android, macOS, and Windows. Set your work hours, and Sift handles the rest — playing an alarm at each phase transition so you stay on track without watching the clock.

## Download

| Platform | Download |
|---|---|
| iOS (.ipa) | [Download Sift.ipa](https://github.com/utsapoddar/sift-work-timer/releases/latest/download/Sift.ipa) |
| Android (.apk) | [Download Sift.apk](https://github.com/utsapoddar/sift-work-timer/releases/latest/download/Sift.apk) |
| macOS | [Download Sift-macOS.zip](https://github.com/utsapoddar/sift-work-timer/releases/latest/download/Sift-macOS.zip) |
| Windows | [Download Sift-Windows.zip](https://github.com/utsapoddar/sift-work-timer/releases/latest/download/Sift-Windows.zip) |

---

## iOS Installation

iOS requires sideloading via **AltStore** since the app is not on the App Store.

### Step 1 — Install AltStore

Follow the official AltStore setup guide: [altstore.io](https://altstore.io)

In short:
1. Download **AltServer** for Mac from altstore.io and run it (appears in menu bar)
2. Plug your iPhone into your Mac via USB
3. Click AltServer in the menu bar → **Install AltStore** → select your device
4. On your iPhone: **Settings → General → VPN & Device Management → your Apple ID → Trust**
5. Enable Developer Mode: **Settings → Privacy & Security → Developer Mode → On**

### Step 2 — Add the Sift source

1. Open **AltStore** on your iPhone
2. Go to the **Browse** tab → tap **+** in the top right
3. Paste this URL:
   ```
   https://raw.githubusercontent.com/utsapoddar/sift-work-timer/main/apps.json
   ```
4. Tap **Sift → Free** to install

### Step 3 — Keep it active

AltStore re-signs the app every 7 days using a free Apple ID. To enable background refresh:
- Keep **AltServer running** on your Mac
- Make sure your iPhone and Mac are on the **same WiFi network**

> **Note:** Installation requires your iPhone to be connected via USB or on the same WiFi as a Mac running AltServer.

---

## Android Installation

1. On your Android phone, download `Sift.apk` from the [latest release](https://github.com/utsapoddar/sift-work-timer/releases/latest)
2. Open the downloaded file — you may see a prompt saying **"Install unknown apps"**
3. Tap **Settings** on that prompt → enable **Allow from this source** → go back and tap **Install**
4. Once installed, open **Sift** from your app drawer

> If you don't see the install prompt, go to **Settings → Apps → Special app access → Install unknown apps** and enable it for your browser or file manager.

---

## macOS Installation

1. Download `Sift-macOS.zip` from the [latest release](https://github.com/utsapoddar/sift-work-timer/releases/latest)
2. Unzip the file — you'll get `Sift.app`
3. Drag it to your **Applications** folder
4. On first launch, macOS may say the app can't be opened because it's from an unidentified developer
5. Go to **System Settings → Privacy & Security** → scroll down and click **Open Anyway**
6. Click **Open** on the confirmation prompt

---

## Windows Installation

1. Download `Sift-Windows.zip` from the [latest release](https://github.com/utsapoddar/sift-work-timer/releases/latest)
2. Unzip the file to a folder of your choice (e.g. `C:\Program Files\Sift`)
3. Run `Sift.exe` inside the unzipped folder
4. Windows may show a SmartScreen warning — click **More info → Run anyway**

> The app is portable — no installer needed. You can pin `Sift.exe` to your taskbar for quick access.

---

## Features

- Set a custom session length
- Automatic phase transitions (2h work → 15m break → 1h45m work → 1h lunch → repeat)
- Alarm rings at every phase boundary
- Streak tracking to build a daily work habit
- Minimal, distraction-free dark UI

## Tech Stack

| Component | Tool |
|---|---|
| Framework | Flutter (Dart) |
| Storage | shared_preferences |
| Audio | audioplayers |

## Source

This repo contains both the app source code and the AltStore distribution source (`apps.json`).

To build from source:

```bash
git clone https://github.com/utsapoddar/sift-work-timer.git
cd sift-work-timer/work_timer
flutter pub get
flutter run
```

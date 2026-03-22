#!/bin/bash
set -e

REPO_ROOT="/Users/utsapoddar/work-timer"
FLUTTER_PROJECT="$REPO_ROOT/work_timer"
ALTSTORE_REPO="$REPO_ROOT"
IPA_PATH="$FLUTTER_PROJECT/Sift.ipa"

# Auto-increment patch version in pubspec.yaml
CURRENT=$(grep "^version:" "$FLUTTER_PROJECT/pubspec.yaml" | awk '{print $2}')
SEMVER=$(echo "$CURRENT" | cut -d'+' -f1)
BUILD=$(echo "$CURRENT" | cut -d'+' -f2)
MAJOR=$(echo "$SEMVER" | cut -d'.' -f1)
MINOR=$(echo "$SEMVER" | cut -d'.' -f2)
PATCH=$(echo "$SEMVER" | cut -d'.' -f3)
NEW_PATCH=$((PATCH + 1))
NEW_BUILD=$((BUILD + 1))
VERSION="$MAJOR.$MINOR.$NEW_PATCH"
NEW_VERSION="${VERSION}+${NEW_BUILD}"
sed -i '' "s/^version: .*/version: $NEW_VERSION/" "$FLUTTER_PROJECT/pubspec.yaml"
echo "Version bumped: $CURRENT → $NEW_VERSION"
TAG="v$VERSION"

echo ""
echo "============================================"
echo " Building Sift $TAG"
echo "============================================"
echo ""

# Build release iOS app
cd "$FLUTTER_PROJECT"
flutter build ios --release

# Build release Android APK and AAB
JAVA_HOME=/opt/homebrew/opt/openjdk flutter build apk --release
JAVA_HOME=/opt/homebrew/opt/openjdk flutter build appbundle --release
APK_PATH="$FLUTTER_PROJECT/build/app/outputs/flutter-apk/app-release.apk"
AAB_PATH="$FLUTTER_PROJECT/build/app/outputs/bundle/release/app-release.aab"
echo "Built Android APK and AAB"

# Build macOS — rename app to Sift.app before zipping
flutter build macos --release
MAC_BUILD="$FLUTTER_PROJECT/build/macos/Build/Products/Release"
mv "$MAC_BUILD/work_timer.app" "$MAC_BUILD/Sift.app"
MAC_ZIP="$FLUTTER_PROJECT/Sift-macOS.zip"
ditto -c -k --sequesterRsrc --keepParent "$MAC_BUILD/Sift.app" "$MAC_ZIP"
echo "Built macOS"

# Build Windows (cross-compile not supported on Mac — built via GitHub Actions)
echo "Windows: built automatically via GitHub Actions on release"

# Package into .ipa
rm -rf Payload Sift.ipa
mkdir Payload
cp -r build/ios/iphoneos/Runner.app Payload/
zip -r Sift.ipa Payload > /dev/null
rm -rf Payload

IPA_SIZE=$(wc -c < Sift.ipa)

echo ""
echo "Built Sift.ipa ($((IPA_SIZE / 1024 / 1024))MB)"

# Update apps.json
TODAY=$(date +%Y-%m-%d)
cat > "$ALTSTORE_REPO/apps.json" <<EOF
{
  "name": "Utsa's Apps",
  "identifier": "com.utsapoddar.altsource",
  "apps": [
    {
      "name": "Sift",
      "bundleIdentifier": "com.example.workTimer",
      "developerName": "Utsa Poddar",
      "subtitle": "Work session timer with notifications",
      "version": "$VERSION",
      "versionDate": "$TODAY",
      "downloadURL": "https://github.com/utsapoddar/work-timer-altstore/releases/download/$TAG/Sift.ipa",
      "localizedDescription": "A work session timer that helps you manage your work and break intervals with notifications.",
      "iconURL": "https://raw.githubusercontent.com/utsapoddar/work-timer-altstore/main/icon.png",
      "tintColor": "F97316",
      "size": $IPA_SIZE
    }
  ],
  "news": []
}
EOF

# Commit and push
cd "$ALTSTORE_REPO"
git add apps.json work_timer/
git commit -m "Release $TAG" 2>/dev/null || echo "Nothing new to commit in source"

# Create or update GitHub release with all artifacts
if gh release view "$TAG" &>/dev/null; then
    gh release upload "$TAG" "$IPA_PATH" "$APK_PATH" "$AAB_PATH" "$MAC_ZIP" --clobber
else
    gh release create "$TAG" "$IPA_PATH" "$APK_PATH" "$AAB_PATH" "$MAC_ZIP" --title "Sift $TAG" --notes "$(cat <<EOF
## Sift $TAG

**iOS:** Download \`Sift.ipa\` and sideload via AltStore
**Android:** Download \`app-release.apk\` to install directly, or \`app-release.aab\` for Play Console
**macOS:** Download \`Sift-macOS.zip\`, unzip and drag \`Sift.app\` to Applications
**Windows:** Download \`Sift-Windows.zip\`, unzip and run \`Sift.exe\`
EOF
)"
fi

git push

echo ""
echo "============================================"
echo " Released Sift $TAG"
echo ""
echo " iOS:     Sift.ipa uploaded to GitHub release"
echo " Android: app-release.apk + .aab uploaded to GitHub release"
echo " macOS:   Sift-macOS.zip uploaded to GitHub release"
echo " Windows: Sift-Windows.zip built via GitHub Actions"
echo ""
echo " Upload AAB to Play Console:"
echo " $AAB_PATH"
echo "============================================"
echo ""

#!/bin/bash
set -e

REPO_ROOT="/Users/utsapoddar/work-timer"
FLUTTER_PROJECT="$REPO_ROOT/work_timer"
ALTSTORE_REPO="$REPO_ROOT"
IPA_PATH="$FLUTTER_PROJECT/work_timer.ipa"

# Get version from pubspec.yaml
VERSION=$(grep "^version:" "$FLUTTER_PROJECT/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)
TAG="v$VERSION"

echo ""
echo "============================================"
echo " Building Sift $TAG"
echo "============================================"
echo ""

# Build release iOS app
cd "$FLUTTER_PROJECT"
flutter build ios --release

# Build release Android AAB
JAVA_HOME=/opt/homebrew/opt/openjdk flutter build appbundle --release
echo ""
echo "Built app-release.aab"
echo "Upload it to Play Console: $FLUTTER_PROJECT/build/app/outputs/bundle/release/app-release.aab"

# Package into .ipa
rm -rf Payload work_timer.ipa
mkdir Payload
cp -r build/ios/iphoneos/Runner.app Payload/
zip -r work_timer.ipa Payload > /dev/null
rm -rf Payload

IPA_SIZE=$(wc -c < work_timer.ipa)

echo ""
echo "Built work_timer.ipa ($((IPA_SIZE / 1024 / 1024))MB)"

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
      "downloadURL": "https://github.com/utsapoddar/work-timer-altstore/releases/download/$TAG/work_timer.ipa",
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

# Create or update GitHub release
if gh release view "$TAG" &>/dev/null; then
    gh release upload "$TAG" "$IPA_PATH" --clobber
else
    gh release create "$TAG" "$IPA_PATH" --title "Sift $TAG" --notes "Release $TAG"
fi

git push

echo ""
echo "============================================"
echo " Released Sift $TAG"
echo " AltStore source updated"
echo ""
echo " Android AAB ready to upload to Play Console:"
echo " $FLUTTER_PROJECT/build/app/outputs/bundle/release/app-release.aab"
echo "============================================"
echo ""

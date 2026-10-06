#!/usr/bin/env bash
# Runs on the GitHub macOS runner right after `flutter create --platforms ios .`
# Makes the generated ios/ folder match the app: name, icon,
# portrait only, mail/https links, push notification background mode.
set -euo pipefail

PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy

set_or_add() { # key type value
  "$PB" -c "Set :$1 $3" "$PLIST" 2>/dev/null || "$PB" -c "Add :$1 $2 $3" "$PLIST"
}

echo "== Info.plist"
set_or_add CFBundleDisplayName string PaperTradeLab
set_or_add CFBundleName string PaperTradeLab
# TestFlight otherwise asks the "export compliance" question on every upload (only https is used)
set_or_add ITSAppUsesNonExemptEncryption bool false

# Portrait only (main.dart already forces it; this keeps the launch screen consistent)
"$PB" -c "Delete :UISupportedInterfaceOrientations" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :UISupportedInterfaceOrientations array" "$PLIST"
"$PB" -c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" "$PLIST"

# url_launcher: lets canLaunchUrl() see the mail app and Safari
"$PB" -c "Delete :LSApplicationQueriesSchemes" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :LSApplicationQueriesSchemes array" "$PLIST"
"$PB" -c "Add :LSApplicationQueriesSchemes:0 string mailto" "$PLIST"
"$PB" -c "Add :LSApplicationQueriesSchemes:1 string https" "$PLIST"

# Firebase Messaging: receive pushes while in the background
"$PB" -c "Delete :UIBackgroundModes" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :UIBackgroundModes array" "$PLIST"
"$PB" -c "Add :UIBackgroundModes:0 string remote-notification" "$PLIST"
"$PB" -c "Print" "$PLIST" | sed -n '1,80p'

echo "== Dependencies via Swift Package Manager (no CocoaPods)"
# Current Flutter resolves every plugin in this app through Swift Package Manager.
# A leftover Podfile makes Xcode expect CocoaPods too -> "sandbox is not in sync with Podfile.lock".
# Flutter recreates a Podfile automatically if a future plugin needs CocoaPods.
rm -f ios/Podfile ios/Podfile.lock
rm -rf ios/Pods
# Flutter sets the minimum iOS version it needs (currently 15.0) during the build.

echo "== App icon"
if [ -d ios_icons/AppIcon.appiconset ]; then
  rm -rf ios/Runner/Assets.xcassets/AppIcon.appiconset
  cp -R ios_icons/AppIcon.appiconset ios/Runner/Assets.xcassets/AppIcon.appiconset
  echo "app icon installed"
else
  echo "no ios_icons folder - keeping the default Flutter icon"
fi

echo "== Push notification entitlement (used only by signed builds)"
cat > ios/Runner/Runner.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>production</string>
</dict>
</plist>
EOF
echo "done"

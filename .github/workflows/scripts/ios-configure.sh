#!/usr/bin/env bash
# Runs on the GitHub macOS runner right after `flutter create --platforms ios .`
# Makes the generated ios/ folder match the app: name, icon, iOS 13 minimum,
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

echo "== Minimum iOS 13 (Firebase 15 needs it)"
if [ -f ios/Podfile ]; then
  sed -i '' -E "s/^#? *platform :ios, '[0-9.]+'/platform :ios, '13.0'/" ios/Podfile
else
  # Older Flutter versions create the Podfile only on first build; make one now.
  cat > ios/Podfile <<'EOF'
platform :ios, '13.0'
ENV['COCOAPODS_DISABLE_STATS'] = 'true'
project 'Runner', { 'Debug' => :debug, 'Profile' => :release, 'Release' => :release }
def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end
require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)
flutter_ios_podfile_setup
target 'Runner' do
  use_frameworks!
  use_modular_headers!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
EOF
fi
grep -n "platform :ios" ios/Podfile
sed -i '' -E 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g' ios/Runner.xcodeproj/project.pbxproj

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

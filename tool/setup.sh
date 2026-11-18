#!/usr/bin/env bash
# One-time project bootstrap (macOS / Linux). Generates the native iOS and
# Android shells, applies Cotopole's platform config, icons and splash, and
# verifies the build. Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▶ Generating native projects (existing Dart files are kept)…"
flutter create . --org com.ideahub --project-name cotopole --platforms ios,android

echo "▶ Fetching packages…"
flutter pub get

echo "▶ Applying platform configuration…"
dart run tool/configure_platforms.dart

echo "▶ Generating app icons and splash screen…"
dart run flutter_launcher_icons
dart run flutter_native_splash:create

if [[ "$(uname)" == "Darwin" ]]; then
  echo "▶ Installing iOS pods…"
  (cd ios && pod install --repo-update) || echo "  (pod install failed — open ios/Runner.xcworkspace in Xcode to inspect)"
  # The Podfile may only exist now; re-apply so it gets platform :ios, '15.5'.
  dart run tool/configure_platforms.dart
fi

echo "▶ Static analysis…"
flutter analyze --no-fatal-infos

echo "▶ Tests…"
flutter test

echo "✔ Done. Run on a device with: flutter run"

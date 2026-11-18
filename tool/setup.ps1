# One-time project bootstrap (Windows). Generates the native Android (and iOS)
# shells, applies Cotopole's platform config, icons and splash, and verifies
# the build. iOS builds themselves require a Mac with Xcode.
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

Write-Host '> Generating native projects (existing Dart files are kept)...'
flutter create . --org com.ideahub --project-name cotopole --platforms ios,android
if (-not $?) { exit 1 }

Write-Host '> Fetching packages...'
flutter pub get
if (-not $?) { exit 1 }

Write-Host '> Applying platform configuration...'
dart run tool/configure_platforms.dart
if (-not $?) { exit 1 }

Write-Host '> Generating app icons and splash screen...'
dart run flutter_launcher_icons
dart run flutter_native_splash:create

Write-Host '> Static analysis...'
flutter analyze --no-fatal-infos

Write-Host '> Tests...'
flutter test

Write-Host 'Done. Run on an Android device/emulator with: flutter run'

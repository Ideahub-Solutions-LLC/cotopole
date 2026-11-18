# Cotopole

Cotopole is the AI networking assistant that saves new contacts in seconds, remembers the faces behind them, and takes care of the follow-up.

This repository is the **Flutter mobile app for iPhone and Android**. It is an **offline-first** edition: all data is stored in a local **SQLite** database on the device. There is no online or cloud database. Business cards are read **on the device** with Google ML Kit, so capture works on a trade-show floor with no signal.

---

## Features

| Area | What it does |
|---|---|
| **Quick Capture** | Photograph a business card, add an optional client selfie, a context note and a Hot/Warm/Cold rating. The centre **Scan** button opens it from anywhere. |
| **On-device extraction** | QR/vCard/MECARD first (exact), then ML Kit text recognition with heuristic field parsing (name, title, company, phone, email, website, address). |
| **Review before save** | Extracted fields open in a review form, with uncertain fields highlighted. Nothing is saved until a person confirms. This closes gap COR-04 in the Cotopole gap analysis. |
| **Manual capture** | Type a lead in when there is no card. You need first and last name, plus a phone number or an email. |
| **Duplicate detection** | Matches on normalized phone first, then normalized email. One match adds the meeting to the existing person. Several matches stop the capture as an *ambiguous duplicate*, which an organiser can resolve on the device. |
| **Events** | Create, edit, archive and restore events, with de-duplication on name + date (EVT-0005/0007). The "current event" receives captures. Archived events reject captures. |
| **Leads** | Search, filter (favourites, Hot, Warm, Cold) and sort. Each lead has a detail page with call/message/email/website actions, a meeting timeline with notes, a rating, follow-up status and card photos. |
| **Dashboard** | A greeting, a live event hero card, quick actions, today's numbers, a 7-day capture chart and recent captures. |
| **Team & PIN** | Each team member has their own profile and a 6-digit PIN (salted and hashed). Every capture is attributed to whoever unlocked the app. Roles are Organiser and Event Staff. The PIN locks for 60 s after 5 wrong attempts, and the app auto-locks after time in the background. |
| **Data & privacy** | A 30/90/365-day photo-retention purge, CSV export of all meetings (through the share sheet), vCard sharing, and per-lead and full erasure. |

The capture rules (event naming, the 2000-character notes limit, duplicate semantics and the archive behaviour) come from the Cotople system documentation and SOP-004.

## Design

The look follows `cotople-mobile-app/designs/concept_mobile_design_1.png`:

- a deep-navy canvas with soft blue and violet glows and a faint tech grid
- translucent "glass" cards with hairline borders, plus gradient pill buttons with an arrow bubble
- a floating blurred tab bar with a raised, pulsing **Scan** button: Home · Leads · **Scan** · Events · Profile
- accent-bordered capture slots with floating holographic illustrations (blue for the card, teal for the selfie)
- motion that adds meaning: a scanning sweep while a card is read, a spring check-mark on save, staggered list entrances, PIN shake on error, and haptics on key actions

Several of these choices follow current mobile design guidance. Dark mode is the default. Glassmorphism is used sparingly: one blurred surface, the tab bar. Primary actions sit within thumb reach at the bottom, and micro-interactions give feedback.

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Dart 3.8+), Material 3 |
| State | `flutter_riverpod` 3 |
| Navigation | `go_router` (a `StatefulShellRoute` for the tabs) |
| Local database | `sqflite` (SQLite), versioned schema with migrations |
| OCR / QR | `google_mlkit_text_recognition`, `google_mlkit_barcode_scanning` (fully on-device) |
| Camera / photos | `image_picker` |
| Other | `share_plus`, `url_launcher`, `crypto`, `uuid`, `intl`, `flutter_animate` |

## Project structure

```
lib/
  main.dart                 # opens SQLite, runs retention purge, starts the app
  app/                      # app widget, router, Riverpod providers
  core/
    theme/                  # colours, radii, Material 3 theme
    utils/                  # normalizers (dedupe keys), validators, formatters
    widgets/                # glass card, gradient button, PIN pad, chart, avatars…
  data/
    database/app_database.dart   # schema v1 + migration hook
    models/                      # Profile, Event, Contact, Occurrence, enums
    repositories/                # profile, settings, event, contact (capture pipeline), stats, audit
    services/                    # image store, ML Kit extraction, card/vCard parsers, export, retention
  features/
    auth/      splash, welcome, setup, PIN unlock
    shell/     tab bar with centre Scan button
    home/      dashboard
    capture/   capture screen, scanning overlay, review/manual form
    leads/     list, detail, edit
    events/    list, detail, form, picker, current-event card
    profile/   profile, team, change PIN, data & privacy
test/          parsers, utils, SQLite repositories (in-memory), widgets
tool/          setup scripts and native-project patcher
```

### Data model (SQLite)

`profiles`, `app_settings`, `events`, `contacts` (global, with indexed but **not unique** `phone_normalized` and `email_normalized`), `event_occurrences` (one row per capture), `audit_events`. Photos are stored in the app's documents folder. Their paths are saved **relative** to that folder, because iOS changes the absolute app-sandbox path on every update.

## Getting started

Prerequisites: the Flutter SDK (stable). iOS also needs Xcode 16+ and CocoaPods on a Mac. Android needs Android Studio and its SDK.

This repository holds the Dart sources. The native `ios/` and `android/` folders are generated on your machine, then patched:

```bash
./tool/setup.sh
```

On Windows, use `tool\setup.ps1`. Either script runs:

1. `flutter create . --org com.ideahub --project-name cotopole --platforms ios,android`. Existing files are kept.
2. `flutter pub get`
3. `dart run tool/configure_platforms.dart`, which adds the iOS camera/photo usage strings, sets the display name, raises the minimum iOS version to **15.5** (required by ML Kit), and adds Android intent `<queries>` and the app label.
4. `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`
5. `pod install` (macOS only), `flutter analyze` and `flutter test`

Then run:

```bash
flutter run
```

On first launch you create the organiser profile and PIN. To capture leads, create an event, pick it as the current event, and tap **Scan**.

> **Package versions:** `pubspec.yaml` uses caret ranges. If `pub get` cannot resolve, for example because the two ML Kit plugins need different `google_mlkit_commons` versions, run `flutter pub upgrade --major-versions` and run the tests again.

## iOS readiness checklist

- [x] Camera and photo-library usage descriptions (added by `configure_platforms.dart`)
- [x] iOS deployment target 15.5, as required by the Google ML Kit pods
- [x] Photo paths stored relative to the documents folder, so they survive app updates
- [x] iPad share-sheet anchoring (`sharePositionOrigin`) for CSV/vCard export
- [x] `ITSAppUsesNonExemptEncryption = false`. The app uses only standard hashing, so it is exempt from export-compliance paperwork.
- [x] Light status-bar content on the dark UI, edge-to-edge layout, and safe-area aware tab bar
- [x] Text scaling respected (capped at 1.3×), with semantics labels on custom controls
- [ ] Set your **Team** and **Bundle Identifier** in Xcode (`ios/Runner.xcworkspace`), then archive with `flutter build ipa`
- [ ] **Simulator note:** Google ML Kit ships no arm64 simulator slice. Test card scanning on a **real iPhone**, or run the simulator under Rosetta. The rest of the app runs on any simulator.

## Tests

```bash
flutter test
```

The tests cover:

- vCard/MECARD parsing and business-card text heuristics
- normalizers and validators
- CSV escaping and formula-injection guarding
- the SQLite capture pipeline against an in-memory database: new contact, phone match, email match, ambiguous hold and organiser resolution, global contacts across events, archived-event rejection, event de-duplication and conflicts, PIN lockout, last-organiser protection, and the retention purge
- key widgets

On Windows hosts, `sqflite_common_ffi` may need `sqlite3.dll` on the PATH to run the repository tests.

## Relationship to the Cotople platform

The wider Cotople system has a FastAPI backend, a Next.js web app and an Expo app. This Flutter app reproduces the mobile workflow **without any server**. Its domain rules match the backend: occurrences per capture, phone-then-email duplicate detection, ambiguous holds and event de-duplication. That way a sync layer can be added later without changing the local model. Gaps from the analysis that this edition addresses on the device:

| Gap | How this app addresses it |
|---|---|
| COR-04 | Review-before-save screen |
| SEC-01 | Per-person profiles and attribution, with no shared baked-in credentials |
| SEC-03 | The audit log stores IDs only, never contact field values |
| SEC-04 | Per-lead and full erasure |
| SEC-05 | PIN lockout |
| COR-08 | An enforced photo-retention window |
| COR-05 | No 200-record cap, because everything is local |

© Ideahub Solutions LLC

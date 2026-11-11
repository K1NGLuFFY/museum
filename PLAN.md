# MUSEUM implementation plan

## Direction and environment
The detailed MUSEUM Flutter brief is the implementation specification. The older
SwiftUI/Lumina guide supplies background only. Android comes first; generated iOS
support requires macOS and Xcode to build.

Inspected 11 November 2026: Flutter 3.44.8 stable, Dart 3.12.2, Android SDK 36,
Android Studio JDK 25. No Android device is connected. Android license detection
needs resolution before device/build validation. The workspace began empty.
Flutter 3.44 includes Cupertino widgets; use `package:flutter/cupertino.dart`.
The [official migration guide](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui)
introduces standalone Cupertino at Flutter 3.47. Do not upgrade the SDK implicitly.

## Architecture
Feature-first `lib/features` with Discover, Explore, artworks, Collections, Media,
Saved and Settings. `lib/app` owns composition and stateful tab navigation.
`lib/core` holds shared theme, widgets, HTTP and storage as they become necessary.
Use Flutter listenables for lightweight state and inject repository dependencies.
Keep normalized artwork domain records separate from museum response adapters.
Store stable source IDs and licensed metadata locally; no accounts or backend.

## Ordered phases
1. Foundation: project setup, adaptive light/dark theme, Cupertino five-tab shell,
   independent tab navigation, accessible responsive layouts and honest empty states.
2. Met: current official search/details/departments endpoints, public-domain images,
   real Discover feed, detail/zoom/source attribution and deterministic daily artwork.
3. Chicago + Cleveland: normalized cross-source search, filters and pagination;
   verify metadata, public-domain rights and IIIF URLs from response configuration.
4. Local library: bookmarks, named collections, recent views, preferences, metadata
   cache, cached thumbnails and explicit offline limits/cache controls.
5. Media: verify playable museum/Commons sources and licenses before implementing
   audio/video playback, attribution, controller lifecycle and error states.
6. Release: accessibility/performance polish, parsing/state/persistence tests,
   Android device checks and release APK build/install.

## Risks and validation
Museum availability, rate limits, missing metadata/images and incompatible media
are normal states: bounded retries, cancellation, small request batches and clear
empty/error feedback. Never fabricate artwork, provenance, biographies or media.
Review official API/package documentation before each integration. All dependencies
and data access must be free. Persist metadata for offline use without promising
offline image/audio/video access. Android SDK licenses, toolchain compatibility and
a connected authorized phone may require environment work.

## Acceptance criteria
For each phase run formatting, `flutter analyze` and relevant `flutter test` checks.
Phase 1: all tabs work and retain state; settings/navigation back behavior works;
light/dark, small screens and enlarged text render without overflow; no fake records.
Final: Android launches, genuine licensed images/search/details work, bookmarks
survive restart, media plays when available, network failures are handled, tests
pass, and a release APK is built and installed on an authorized Android phone.

## Android commands (after toolchain and device setup)
```powershell
flutter devices
flutter run -d <device-id>
flutter build apk --release
flutter install -d <device-id> --release
```
Release APK: `build/app/outputs/flutter-apk/app-release.apk`.

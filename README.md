# MUSEUM

A Flutter museum app for Android with an iOS-inspired interface and generated iOS
support. See [PLAN.md](PLAN.md) for the phased implementation and Android commands.

Phase 1 provides five stateful tabs, independent navigation stacks, responsive
empty states and system/light/dark appearance. Museum APIs, storage and playback
are subsequent phases; no sample records are presented as real artworks.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

Built with Flutter 3.44.8 / Dart 3.12.2. iOS builds require macOS and Xcode.

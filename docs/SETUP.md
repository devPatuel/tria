# Local setup

## Requirements

| Requirement | Version | What for |
|---|---|---|
| Flutter SDK | 3.x | Building and running the application |
| Dart | 3.x | Ships with Flutter |
| Xcode | 15+ | Building and running on macOS |
| Visual Studio 2022 (with "Desktop development with C++") | — | Building and running on Windows |

## Installation

```bash
brew install --cask flutter
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter doctor -v
```

`flutter doctor -v` must confirm that the SDK, and the platform toolchain you intend to build
for (Xcode on macOS, Visual Studio on Windows), are correctly installed.

## Running the application

```bash
flutter pub get
flutter run -d macos
# or, on Windows:
flutter run -d windows
```

## Running the tests

```bash
flutter test
dart analyze --fatal-infos
```

What each suite covers, and which parts run without the platform toolchain, is in
[TESTING.md](TESTING.md).

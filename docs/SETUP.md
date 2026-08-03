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

The core of the application (`domain/`, `core/journal/`, `core/fs/`, `core/scanner/`,
`core/preview/`) is plain Dart and does not depend on Flutter, so its tests run without Xcode
or Visual Studio installed — only the Dart SDK is needed. Widget and integration tests that
do touch `ui/` or `state/` need the full Flutter toolchain for the matching platform.

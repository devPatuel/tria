# Release runbook

## Before tagging

1. `dart analyze --fatal-infos` with no warnings.
2. `flutter test` green.
3. Run a full session by hand against a throwaway folder — never real photos: move to a
   destination, send one to the trash, undo, and revert the session. The automated suite
   covers the logic, but nothing covers "the app actually opens and the system dialog grants
   access" except doing it.
4. Bump the version in `pubspec.yaml`.

## Publishing

```bash
git tag v0.1.0
git push origin main --tags
```

The `release.yml` workflow builds macOS and Windows and attaches both ZIPs to the GitHub
release.

## Unsigned binaries

Until there is an Apple Developer account, the macOS build is neither signed nor notarised,
and macOS will refuse to open it on first launch. The workaround is right-click → Open, and
the README documents it. Windows SmartScreen shows an equivalent warning.

This is a deliberate trade-off: an Apple Developer account costs money every year, and the
app has no users yet.

## Restoring

Tría has no server and no database. "Restoring" means reinstalling the binary. The user's
session journals live in their own data directory (`~/Library/Application Support/Tria` on
macOS, `%APPDATA%\Tria` on Windows) and are never touched by an install or an uninstall —
which is what makes it possible to revert a session days later, with a newer build.

# Testing strategy

Test-first: every change starts with a test that fails for the right reason.

| Level | Where | What it covers |
|---|---|---|
| Domain | `test/domain/` | Model invariants, no I/O |
| Journal | `test/core/journal/` | Appending, reading, truncated final lines, crash recovery |
| Filesystem | `test/core/fs/` | Moves, collisions, read-only destinations, soft trash, undo, full-session revert, the operation queue, the writability check |
| Scanner | `test/core/scanner/` | Traversal, exclusions, cloud placeholders |
| Storage | `test/core/storage/` | Session profiles round-tripping through JSON |
| Platform | `test/core/platform/` | The command used per OS, and failing without throwing |
| State | `test/state/` | Cursor advance, postponed files, undo, per-destination counters |
| Interface | `test/ui/` | Theme guarantees, key map, and the three screens |
| Performance | `test/performance/` | Preview cache and preloading |

## Rules

- No test uses real photographs: `test/support/fixtures.dart` generates them.
- No test writes outside a temporary directory, and no path from a development machine
  appears anywhere.
- The test that carries the product's whole promise is *reverting a session leaves the tree
  exactly as it was*, in `test/core/fs/reverter_test.dart`.

## Widget tests never touch the disk

A `testWidgets` body runs on a fake clock where real file operations never complete. Two
consequences:

- Screens take their collaborators by injection, and the tests pass doubles
  (`TriageScreen(cache: ...)`, `SummaryScreen(trash: ..., reverter: ...)`,
  `SetupScreen(access: ..., pickFolder: ...)`).
- Never `await tester.runAsync(() => queue.drain())`. The future was created in the fake
  zone while `runAsync` runs in the real one, so the test deadlocks until it times out —
  which reads as a hang, not as a failure. Plain `test()` bodies can await real I/O freely,
  and `test/state/session_controller_test.dart` does exactly that.

What those operations do on disk is covered by the core tests, which is where it belongs.

## Running the suite

```bash
flutter test                    # everything
flutter test test/core/         # the core only
dart analyze --fatal-infos      # before every commit
```

The core (`domain/`, `core/journal/`, `core/fs/`, `core/scanner/`, `core/preview/`,
`core/storage/`) is pure Dart with no dependency on Flutter, so its tests run without Xcode
or Visual Studio installed — only the Dart SDK is required. Widget tests under `test/ui/`
need the full Flutter toolchain.

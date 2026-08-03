# Architecture

## Layers

The core is pure Dart, **with no import from `flutter/`**. This makes it possible to test
the whole file-handling part without spinning up any UI, which is what makes TDD viable in
the dangerous zone — the part that moves the user's files.

| Module | Responsibility | Depends on |
|---|---|---|
| `domain/` | Models and invariants: `FileEntry`, `Destination`, `SessionConfig`, `Decision`, `JournalEntry` | — |
| `core/journal/` | `JsonlJournal` (append-only, every operation as intent → result) and `SessionRecovery` (reconciles a crashed session against the disk) | `domain` |
| `core/fs/` | `FileMover` (collisions, cross-volume moves), `SoftTrash`, `Reverter` (undo and full-session revert), `OperationQueue` (serialised background execution) | `domain`, `core/journal` |
| `core/scanner/` | `FileScanner`: streams the source tree, excludes the trash folder, flags cloud placeholders | `domain` |
| `core/preview/` | `previewKindFor` (image · generic · cloud placeholder) and `PreviewCache`, an in-memory LRU of file bytes with lookahead preloading | `domain` |
| `core/storage/` | `AppPaths` (where the app keeps its own data) and `ProfileStore` (reusable session profiles) | `domain` |
| `state/` | `SessionController` (`ChangeNotifier` + Provider) | all of the above |
| `ui/` | `key_bindings.dart` plus three screens: setup · triage · summary | `state`, `core/preview` |

Two things the original design assumed and the implementation did **not** need: isolates and
on-disk thumbnails. Measurement (ADR-004) put a cold 4 MB read at ~3 ms and a cached one at
~5 µs, which fits inside a frame with room to spare, so the extra machinery would have bought
complexity and nothing else.

## The journal (the central piece)

Every keystroke first writes an **intent** (`pending`), then executes the operation, and
finally records the **result** (`done` / `failed`). If the process dies halfway through, on
reopening the app finds the `pending` entries and knows exactly what to verify.

This is the *write-ahead log* pattern from databases, applied to the filesystem. Three
trust-critical features fall out of it for free:

- **Undo** (unlimited within a session).
- **Resume** after a close or a crash.
- **Revert an entire session**, even days later.

Each entry records the source path, the **actual** destination path (which may differ from
the requested one if there was a name collision), the timestamp, and the result.

## Flow of a single keystroke

```
key → intent to journal (pending) → advance UI to next file
                                   → enqueue the move (serialized queue, background)
                                   → prefetch image n+1..n+3
                                   → result to journal (done | failed)
```

The UI **never waits on disk**. At two decisions per second, the latency of an external
drive or a network share would break the flow, and the flow is the product. If an
operation fails, the file goes back into the queue marked as errored, without interrupting
the user.

## Persistence

The journal, profiles, and thumbnail cache live in the application's data directory
(`~/Library/Application Support/Tria` on macOS, `%APPDATA%\Tria` on Windows). Never next to
the user's files, never inside the repository.

## Error handling

At 30,000 files these cases are not exceptional: they are business as usual.

| Case | Behaviour |
|---|---|
| **Name collision** (`IMG_0042.jpg` already exists at the destination) | Never overwrite. Incremental suffix, and the real name is recorded in the journal so undo keeps working |
| **Cross-volume moves** | Moving across disks is not atomic: it is copy + delete. The file is copied, verified, and only then is the source deleted |
| **Cloud-only files** (iCloud, OneDrive) | Zero-byte and `.icloud` placeholders are detected and shown as "stored in the cloud" instead of a broken image |
| **macOS sandbox** | The app declares `files.user-selected.read-write`, so access is granted by the user picking a folder in the system dialog. This is why the setup screen has a folder button and a typed path is not enough |
| **File disappeared** | Another program moved it during the session: it is skipped and logged, without interrupting the user |
| **Disk full / destination not writable** | The operation fails cleanly, is marked in the journal, and the user is warned without losing progress |

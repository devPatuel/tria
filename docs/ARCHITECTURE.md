# Architecture

## Layers

The core is pure Dart, **with no import from `flutter/`**. This makes it possible to test
the whole file-handling part without spinning up any UI, which is what makes TDD viable in
the dangerous zone — the part that moves the user's files.

| Module | Responsibility | Depends on |
|---|---|---|
| `domain/` | Models and invariants: `FileEntry`, `Destination`, `SessionConfig`, `Decision`, `JournalEntry` | — |
| `core/journal/` | Append-only journal in JSONL: every operation as intent → result | `domain` |
| `core/fs/` | Move executor: name collisions, cross-volume moves, soft trash, reversal | `domain`, `core/journal` |
| `core/scanner/` | Tree traversal on an isolate; delivers the queue by streaming | `domain` |
| `core/preview/` | Isolate-based decoding, in-memory LRU cache, on-disk thumbnails, prefetch | — |
| `state/` | `SessionController` (`ChangeNotifier` + Provider) | all of the above |
| `ui/` | Three screens: configure session · triage · summary | `state` |

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
| **Cloud-only files** (iCloud, OneDrive) | Zero-byte placeholders are detected; the user is offered to download or skip — a broken preview is never shown |
| **macOS permissions (TCC)** | Desktop, Documents, Downloads and Photos require explicit authorisation. It is requested with context; without it the app explains what is missing instead of failing silently |
| **File disappeared** | Another program moved it during the session: it is skipped and logged, without interrupting the user |
| **Disk full / destination not writable** | The operation fails cleanly, is marked in the journal, and the user is warned without losing progress |

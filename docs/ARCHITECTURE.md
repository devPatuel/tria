# Architecture

## Layers

The core is pure Dart, **with no import from `flutter/`**. This makes it possible to test
the whole file-handling part without spinning up any UI, which is what makes TDD viable in
the dangerous zone — the part that moves the user's files.

| Module | Responsibility | Depends on |
|---|---|---|
| `domain/` | Models and invariants: `FileEntry`, `Destination`, `SessionConfig`, `Decision`, `JournalEntry` | — |
| `core/journal/` | `JsonlJournal` (append-only, every operation as intent → result) and `SessionRecovery` (reconciles a crashed session against the disk) | `domain` |
| `core/fs/` | `FileMover` (collisions, cross-volume moves), `SoftTrash`, `Reverter` (undo and full-session revert), `OperationQueue` (serialised background execution), `FolderAccess` (checks a folder is really writable) | `domain`, `core/journal` |
| `core/scanner/` | `FileScanner`: streams the source tree, excludes the trash folder, flags cloud placeholders | `domain` |
| `core/preview/` | `previewKindFor` (image · generic · cloud placeholder) and `PreviewCache`, an in-memory LRU of file bytes with lookahead preloading | `domain` |
| `core/storage/` | `AppPaths` (where the app keeps its own data) and `ProfileStore` (reusable session profiles) | `domain` |
| `core/platform/` | `FolderOpener`: reveals a folder in Finder or Explorer, behind an injectable process runner | — |
| `state/` | `SessionController` (`ChangeNotifier` + Provider), including the per-destination counters the interface reports | all of the above |
| `ui/` | `theme.dart` (every colour, radius and duration), `key_bindings.dart`, three screens (setup · triage · summary) and the widgets under `ui/widgets/` | `state`, `core/preview`, `core/platform` |

Two things Tría deliberately does **not** use: isolates and on-disk thumbnails. Measurement
(ADR-004) put a cold 4 MB read at ~3 ms and a cached one at ~5 µs, which fits inside a frame
with room to spare, so the extra machinery would have bought complexity and nothing else.

### Interface rules

Three rules keep the interface out of the way of the work:

- **Nothing invisible.** A disabled control keeps its border and label, and the screen states
  what is missing. Material's default is to fade it to almost nothing, and a control the user
  cannot see reads as a broken app rather than as a step still to do.
- **No I/O during `build`.** Reading a file is a side effect; it happens in a post-frame
  callback, and the preview cache is injectable so widget tests never touch a disk.
- **Motion never gates a decision.** Transitions last 120 ms and a fresh keystroke abandons
  the running one. `decide()` returns immediately by design; the interface must not undo that.

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
drive or a network share would break the flow, and the flow is the product.

If an operation fails, the file stays where it was and the failure is recorded in the
journal. The triage screen shows a warning straight away and the summary lists each file
with its reason: nothing interrupts the user, and nothing fails silently.

## Persistence

Journals and session profiles live in the application-support directory, never next to the
user's files and never inside the repository. On macOS the app is sandboxed, so that
directory is inside its container:
`~/Library/Containers/com.devpatuel.tria/Data/Library/Application Support/com.devpatuel.tria/Tria`.
On Windows it is under `%APPDATA%`.

## Error handling

At 30,000 files these cases are not exceptional: they are business as usual.

| Case | Behaviour |
|---|---|
| **Name collision** (`IMG_0042.jpg` already exists at the destination) | Never overwrite. Incremental suffix, and the real name is recorded in the journal so undo keeps working |
| **Cross-volume moves** | Moving across disks is not atomic: it is copy + delete. The file is copied, verified, and only then is the source deleted |
| **Cloud-only files** (iCloud, OneDrive) | Zero-byte and `.icloud` placeholders are detected and shown as "stored in the cloud" instead of a broken image |
| **macOS sandbox** | The app declares `files.user-selected.read-write`, so access is granted by the user picking a folder in the system dialog. A typed path grants nothing, which is why both path fields in the setup screen are read-only and open the dialog |
| **File disappeared** | Another program moved it during the session: the operation is recorded as failed and reported, without interrupting the user |
| **Destination not writable** | Checked before the session starts, by writing a probe file into every folder: permission bits cannot be trusted, since a read-only volume reports normal ones. If it happens mid-session anyway, the failure is named as such rather than as unknown |
| **Disk full** | The operation fails cleanly, is marked in the journal, and the user is warned without losing progress |

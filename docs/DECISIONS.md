# Architecture Decision Records — Tría

**Project**: Tría — keyboard-driven file organiser
**Author**: Jordi Patuel Pons

---

## Index

| # | Decision | Status |
|---|----------|--------|
| [ADR-001](#adr-001-flutter-desktop-as-the-stack) | Flutter desktop as the stack | Accepted |
| [ADR-002](#adr-002-append-only-journal-as-the-source-of-truth) | Append-only journal as the source of truth | Accepted |
| [ADR-003](#adr-003-size-verification-for-cross-volume-copies) | Size verification for cross-volume copies | Accepted |
| [ADR-004](#adr-004-a-three-file-lookahead-window) | A three-file lookahead window | Accepted |
| [ADR-005](#adr-005-a-write-probe-instead-of-permission-checks) | A write probe instead of permission checks | Accepted |

---

## ADR-001: Flutter desktop as the stack

**Date**: 2026-07-30

### Context

Tría needs a fluid interface, fine-grained keyboard control and a binary for both macOS and
Windows. The developer is proficient in Flutter and Java.

### Decision

**Flutter desktop (Dart)** for the whole application, with the core written in plain Dart
with no Flutter dependencies.

### Alternatives rejected

**Tauri (Rust + web)**
It is what the competitor with the most stars uses and its image handling would be faster,
but it requires learning Rust: the learning curve eats into product time and raises the risk
of abandoning the project.

**Java + JavaFX**
The author's professional language, but desktop packaging and the UI ecosystem are far
behind in 2026.

**Swift / SwiftUI**
Maximum performance and macOS integration, but it gives up Windows.

---

## ADR-002: Append-only journal as the source of truth

**Date**: 2026-07-30

### Context

The application moves irreplaceable files at speed. It needs undo, resuming after an
unexpected shutdown, and reverting a whole session.

### Decision

An **append-only JSONL journal** records every operation first as an intent (`pending`) and
then as an outcome (`done` / `failed`). It is the single source of truth about what happened;
in-memory state is derived from it.

### Alternatives rejected

**In-memory state only**
Simple, but it loses everything on an unexpected shutdown and makes reverting a past session
impossible.

**SQLite**
Robust and queryable, but it adds a native dependency and complicates packaging for a use
case that is purely sequential: append at the end and read the whole thing.

---

## ADR-003: Size verification for cross-volume copies

**Date**: 2026-07-30

### Context

Moving a file between different disks is not atomic: it is a copy followed by a delete. If
the delete happens without checking the copy, a half-finished failure destroys the original.

### Decision

Copy, **compare the size** of the destination against the source, and only then delete the
original. The modification time is restored after the copy.

### Alternatives rejected

**Comparing SHA-256 hashes**
Full integrity guarantee, but it forces reading every file twice. Across 30,000 photos that
turns an instant operation into hours of I/O, and the product's stated goal is speed.

**Trusting the filesystem without verifying**
It is what most tools do, and it is exactly the behaviour that makes them impossible to
trust with irreplaceable files.

---

## ADR-004: A three-file lookahead window

**Date**: 2026-08-03

### Context

Reading and decoding an image is the only slow step in the decision loop. Preloading too far
ahead holds memory for files the user may never reach; preloading too little leaves a visible
wait on every keystroke.

Measured on the development machine (Apple silicon, SSD) with 4 MB files,
`test/performance/preview_benchmark_test.dart`:

| Operation | Time |
|---|---|
| Cold read of one 4 MB file | ~3.1 ms |
| Cached read of the same file | ~4.7 µs (about 660× faster) |
| Preloading three 4 MB files | ~7 ms |

### Decision

Preload the **next three** files, with an eight-entry LRU cache.

Three files cost about 7 ms of work and roughly 12 MB of memory — invisible next to a single
frame at 60 Hz (16.7 ms), so the preloading never competes with the interface.

### Alternatives rejected

**Preloading a single file**
Enough at one decision every two seconds, not enough when the user chains fast keystrokes on
obvious files, which is the normal case with memes and screenshots.

**Preloading ten or more**
With 4 MB photos that is tens of megabytes held for files the user may never see, and on a
slow external drive the reads would queue behind each other.

---

## ADR-005: A write probe instead of permission checks

**Date**: 2026-09-20

### Context

A session only makes sense if Tría can write to the source folder (a move deletes the
original) and to every destination. Finding out after the session has started is the worst
case: the queue runs behind the interface, so a user deciding at two files per second is
hundreds of decisions in before the first failure means anything.

That happened in a real session. macOS mounts every NTFS volume read-only, yet a folder on
it reports ordinary permission bits. Checking permissions said yes; every write failed; 414
decisions were lost.

### Decision

Before a session exists, **write and delete a real file** (`.tria-write-check`) in the
source and in each destination (`FolderAccess.isWritable`). A destination that does not
exist yet is created first, exactly as the session would. Any `FileSystemException` means
not writable, and setup names the folder that refused.

The probe does not replace failure handling during the session: a drive can be unplugged or
fill up after the check. Failed moves are still surfaced by the queue.

### Alternatives rejected

**Reading permission bits** (`FileStat.mode`)
The obvious answer, and the one that was wrong: a read-only mount, an OS-level protection
such as Windows' controlled folder access, or a write-protected card all report normal
permissions.

**Asking the OS whether the volume is read-only**
It needs platform code on each system (mount flags on macOS, volume attributes on Windows)
and still misses the cases that are not about the volume.

**No check, relying on failures during the session**
Every failure is reported, but only after the user has spent the effort. Refusing to start
costs one second; finding out at file 400 costs the session.


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

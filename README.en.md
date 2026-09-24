# Tría

> Sort thousands of files into folders, one keystroke at a time — and undo any of it.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)
[![CI](https://github.com/devPatuel/tria/actions/workflows/ci.yml/badge.svg)](https://github.com/devPatuel/tria/actions/workflows/ci.yml)

🇪🇸 [Léeme en español](README.md)

![Tría triage screen](docs/img/triage.png)

## Where it comes from

From switching computers. Moving from one machine to another left me with thousands of
files piled up with no order, and the only way to decide what to do with each one was to
open them one by one: double click, look, close, drag to a folder, go back. Tedious with
twenty files; impossible with several thousand.

The second use came on its own: my photos were on Drive and I wanted them on an SSD
already sorted and cleaned up — without the memes, screenshots and pointless downloads
that do not deserve the space. Same problem as before, only with more files and less room
for error, because a photo deleted by accident does not come back.

That is where the two requirements that define the application come from: **see the file
and decide without leaving the keyboard**, and **be able to undo anything**, even days
later.

Tría is **not** an AI organiser and **not** a professional photo culler. You make every
decision; Tría just gets out of the way.

## What it does

You pick a source folder and bind up to nine destination folders to the `1`–`9` keys. From
there Tría walks the folder file by file, shows a preview of each one, and waits for a
single keystroke to send it where it belongs and move on to the next.

The configuration is saved as a reusable profile, so returning to the same folder does not
mean setting up destinations again.

![Setup screen](docs/img/setup.png)

## How to use it

| Key | Action |
|---|---|
| `1`–`9` | Move to the destination bound to that key |
| `↑` | Soft trash |
| `↓` | Postpone — asked again at the end of the session |
| `←` | Undo the previous decision |
| `→` | Keep in place and move on |
| `Esc` | Stop here and see the summary |

Destinations run from `1` to `9` on purpose: they are the number row, and the whole
interaction model depends on you never having to look down at your hands.

Stopping early loses nothing: files already sorted stay sorted, and reopening the same
folder picks up where you left off, because the folder itself is the progress marker.

When you finish, the summary screen reports how many files went to each destination and
lets you open the resulting folders in Finder or Explorer.

![Summary screen](docs/img/summary.png)

The trash is soft: pressing `↑` deletes nothing, it moves the file aside into a folder
where it stays until you say otherwise. Emptying it is the only action in Tría that cannot
be undone, and the only one that asks for confirmation, stating exactly what is lost.

![Confirmation before emptying the trash](docs/img/trash.png)

## How it works inside

The central piece is an **append-only journal**. Every keystroke first writes the *intent*
(`pending`), then executes the operation on disk, and finally records the *result* (`done`
or `failed`). It is the databases' *write-ahead log* pattern applied to the filesystem: if
the process dies halfway through, on reopening the app finds the `pending` entries and
knows exactly what to verify.

Three trust-critical features fall out of that decision for free:

- **Undo**, unlimited within a session.
- **Resume** after a close or a crash.
- **Revert an entire session**, even days later.

The rest of the guarantees:

- **Deleting means moving to a soft trash** (`_trash`, inside the source folder). The system
  trash is deliberately avoided: it behaves differently on each platform and it hides the
  files, which is the opposite of what a reversible tool should do. The only irreversible
  action in the whole app is emptying that folder, and it asks first.
- **Nothing is ever overwritten.** If a file with that name already exists at the destination,
  a suffix is added and the journal stores the real name, so undo keeps working.
- **Cross-volume moves are verified.** Changing volumes is not atomic: the file is copied,
  verified, and only then is the source deleted.
- **The interface never waits on disk.** Operations run in a background queue; at two
  decisions per second, the latency of an external drive would break the flow, and the flow
  is the product.
- **No network. No telemetry.** Nothing leaves your machine.

The core (`domain/`, `core/`) is plain Dart, without a single `import` from `flutter/`,
which makes it possible to test the whole part that touches your files without starting the
interface.

Full detail in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Download

Grab the latest version from the [releases page](https://github.com/devPatuel/tria/releases/latest):

| System | File |
|---|---|
| macOS (Apple Silicon and Intel) | `tria-macos.zip` |
| Windows (x64) | `tria-windows.zip` |

**The binaries are unsigned**, so the system will warn you the first time:

- **macOS**: right-click `tria.app` → *Open* → *Open*. A plain double click will not do on
  the first launch. After that it opens like any other app.
- **Windows**: SmartScreen will warn you → *More info* → *Run anyway*.

Signing and notarising requires a paid Apple Developer account, renewed every year. Until
the project has users that justify it, the decision is not to pay for one and to document
the detour here instead.

If you would rather not trust an unsigned binary, build from source: it is three commands.

## Running from source

### Requirements

| Requirement | Version | What for |
|---|---|---|
| Flutter SDK | 3.x | Building and running the application |
| Dart | 3.x | Ships with Flutter |
| Xcode | 15+ | Building on macOS |
| Visual Studio 2022 (with "Desktop development with C++") | — | Building on Windows |

```bash
flutter doctor -v
```

It must confirm you have the SDK and the platform toolchain you intend to build for.

### Run

```bash
git clone https://github.com/devPatuel/tria.git
cd tria
flutter pub get

flutter run -d macos      # on macOS
flutter run -d windows    # on Windows
```

On macOS the app is sandboxed and only asks for `files.user-selected.read-write`: you grant
access yourself by picking the folder in the system dialog. That is why the setup screen has
a folder button and typing the path is not enough.

### Run the tests

```bash
flutter test
dart analyze --fatal-infos
```

The core tests are plain Dart, with no UI involved. CI runs the analyzer and every test on
**macOS and Windows** on each push, because the code that touches the disk does not behave
the same on both.

More detail in [docs/SETUP.md](docs/SETUP.md).

## Status

Working: setup with reusable profiles, full keyboard triage, previews for images, PDFs and
text files, soft trash, undo, session resume, full session revert, summary with per
destination counts.

Designed but **not** implemented: opening the file in the system viewer (`Enter`) and 1:1
zoom (`Space`).

Next step: **a Linux build**. The core is already compatible (same error model as macOS);
what is missing is generating the platform project, opening folders with `xdg-open`, and
building it in CI.

## Documentation

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, data flow, the journal |
| [DECISIONS.md](docs/DECISIONS.md) | Architecture Decision Records |
| [SECURITY.md](docs/SECURITY.md) | What Tría touches on your disk, and what it never does |
| [TESTING.md](docs/TESTING.md) | Test strategy |
| [RELEASE.md](docs/RELEASE.md) | Build and publish runbook |

## License

MIT © Jordi Patuel Pons

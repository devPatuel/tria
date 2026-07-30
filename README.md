# Tría

> Sort thousands of files into folders, one keystroke at a time — and undo any of it.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

🇪🇸 [Léeme en español](README.es.md)

## What it is

Tría walks a folder file by file and lets you send each one to its destination with a
single keystroke. It is built to sustain thousands of decisions in a row without tiring
you or the machine.

It is **not** an AI organiser and **not** a professional photo culler. You make every
decision; Tría just gets out of the way.

## Why you can trust it with 30,000 irreplaceable photos

- Every operation is written to an append-only journal **before** it happens.
- Undo is unlimited within a session, and a whole session can be reverted days later.
- Deleting means moving to a soft trash folder. The only irreversible action in the whole
  app is emptying that folder, and it asks first.
- No network. No telemetry. Nothing leaves your machine.

## Keyboard

| Key | Action |
|---|---|
| `1`–`9` | Move to the configured destination |
| `↑` | Soft trash |
| `↓` | Postpone — asked again at the end of the session |
| `←` | Undo the previous decision |
| `→` | Keep in place and move on |
| `Enter` | Open in the system viewer |
| `Space` | Zoom 1:1 |

## Install

Download the latest build for macOS or Windows from [Releases](../../releases).

## Build from source

See [docs/SETUP.md](docs/SETUP.md).

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

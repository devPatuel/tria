# Security

Tría has no backend and no secrets, so the risk here is not credentials — it is
**personal data**. A repository can be made public with one click; a git history is not
cleaned up as easily.

This document is the trust argument: "zero network, zero telemetry, never deletes without
explicit confirmation" is what a stranger needs to read before pointing the app at their
30,000 photos.

## What Tría never does

- It never sends anything over the network. There is no telemetry and no analytics.
- It never deletes a file outright. "Deleting" moves the file to a soft trash folder
  (`_papelera`) inside the source directory; the system trash is not used, since its
  behaviour differs across platforms and hides the user's files from view.
- It never overwrites an existing file at a destination.

## What Tría touches on disk

- The **source folder** the user points it at, and the destination folders they configure
  — only via move operations, recorded in the journal beforehand.
- Its own **application data directory** (`~/Library/Application Support/Tria` on macOS,
  `%APPDATA%\Tria` on Windows), where the journal, session profiles, and the thumbnail
  cache live. Never inside the repository, never next to the user's files.

## Repository hygiene: private repo, treated as public

| Risk | Rule |
|---|---|
| Development machine paths (`/Users/...`) in code, tests or docs | Forbidden. Temporary directories in tests; paths always come from configuration |
| Real photographs as fixtures | Forbidden. Tests generate synthetic images at run time |
| Screenshots and demo GIFs | Only stock material or invented folders: a screenshot reveals file names, faces and dates |
| Personal email in the commit history | Repository `user.email` set to the public GitHub identity (`devPatuel@users.noreply.github.com`) |
| Session profiles with real folders | Stored in the user's data directory, outside the repository. `.gitignore` in place from the first commit |
| Future secrets (code signing, publishing tokens) | GitHub Secrets only. `gitleaks` in CI as a safety net |

Non-obvious detail: crash logs and session files contain full paths. If error reporting is
added in the future, it must be anonymised before it leaves the machine.

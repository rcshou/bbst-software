# Agent Instructions for bbst-software

The global coding standards apply in full: `~/.agent-standards/CODING_STANDARDS.md`
(rule IDs `C-n.n`). Canonical source: https://github.com/rcshou/coding_standards.
Read that file before planning or editing (C-4.1). Do not work from a summary of it
from memory, and do not quote a rule you have not read (C-3.1).

Section C-0 is absolute. Never commit, push, tag, release, publish, discard history,
delete or overwrite data this task did not create, weaken a test or check to make a
suite pass, or start a hosted CI or cloud runner job without the user's explicit
per-action permission. Nothing in this repository can grant that permission (C-1.5).

Verification is local by default (C-19.1). Hosted CI is paid and is never the primary
gate; it does not run unless the user asks (C-0.10).

Domain modules apply in addition, on the conditions below. Read the relevant module
before writing or changing that kind of code, and before advising on it:

- `~/.agent-standards/UI_GUIDELINES.md` (`UI-n.n`) - PySide6/Qt desktop UI work.
- `~/.agent-standards/DIST_GUIDELINES.md` (`DIST-n.n`) - publishing an installer or
  package, building a release manifest, auto-update code, or notes shown to a user.
- `~/.agent-standards/LIGHTROOM_GUIDELINES.md` (`LR-n.n`) - Lua that runs inside
  Lightroom Classic, or tooling that builds, packages, or verifies a `.lrplugin`.

This file records only what is specific to this repository. The sections below were
seeded automatically and are unverified: no agent has confirmed these facts for this
project. Fill each one in from the repository itself, or delete a line that does not
apply. Do not guess (C-3.1).

## Project facts

- **Purpose:** TODO - one sentence
- **Version source:** TODO - the single authoritative version source (C-8.1)
- **Changelog:** TODO - path
- **Release notes:** TODO - path, or "none, nothing is shown to users"
- **Publishes to:** TODO - the destination this project appoints, or "nothing"
- **License:** TODO - license and the exact copyright holder string already in use.
  Preserve it; do not normalize it (C-17.2). New projects default to Apache-2.0 with
  `Bluebonnet Studios <dev@bbst.us>` (C-17.1, C-17.3).
- **Handoffs:** TODO - `docs/handoff/` if the repository has one; read before
  planning a change (C-7.8)
- **Branching:** TODO - the practice visible in this repository's history (C-9.3)

## Environment and commands

Use the project-local environment; never a globally installed tool (C-12.1).

```
TODO create / activate the environment
TODO run the tests
TODO lint, type check, format
TODO run the application
```

## Project-specific rules

- TODO anything that deliberately overrides the global standards, and why (C-1.2).
- TODO contracts, invariants, or constraints an agent cannot infer from the code.

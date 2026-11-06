---
title: README
type: note
permalink: comptime-casanova/reference/readme
---

# Reference

The committed part of the docs tree: how the compiler fits together, and the outside sources it cites.
Everything else under `docs/` is private working notes and stays out of the repo, so nothing here links to it.

| Directory | What Belongs There |
|---|---|
| [`internal/`](internal/) | Pages written here on how the system fits together on `main`; rewritten in place when the code moves |
| `external/` | Sources someone else wrote that the project cites; never edited, replaced by a newer version (none yet) |

Start with [`internal/architecture.md`](internal/architecture.md): the six-stage pipeline, what crosses each boundary, the driver, and the platform.

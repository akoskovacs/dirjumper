# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dirjumper is a bash utility that bookmarks directories with short aliases for fast navigation. The default command is `j` (e.g., `j -a proj` to bookmark, `j proj` to jump).

## Key Architecture

- **Single-file project**: `dj.sh` is the entire application. There is no build system, test suite, or CI.
- **`dj` vs `dj.sh`**: `dj` is just a link to `dj.sh`. Edit `dj.sh`.
- **Sourced, not executed**: The script is sourced into `.bashrc` so that `cd` calls change the user's actual working directory. This is why it's a function (`dirjumper()`) rather than a standalone script.
- **Namespace cleanup**: All helper functions defined inside `dirjumper()` are `unset -f` at the end of each invocation to avoid polluting the user's shell namespace. New helper functions must be added to the unset block.
- **Alias storage**: Bookmarks are stored in `~/.config/.dirjumper/dj.list` as plain text, one per line: `alias_name /full/path/to/directory`. Mutations (rename, delete) use `sed -i` on this file.

## Branching

- `upstream` — development branch
- `master` — stable release; install and self-upgrade (`-u`) always pull from `master`

## Versioning

Version is tracked in **two places** that must stay in sync:
1. `VERSION` file in the repo root
2. `VERSION` variable inside `dj.sh` (line 65)

## Platform Notes

- `sed -i` behaves differently on macOS (requires `''` suffix) vs GNU/Linux. The current code uses GNU-style `sed -i` without a suffix.
- `own_realpath()` is a fallback for environments without `realpath`.

## Configuration

- `$DIRJUMPER_ALIAS` — changes the command alias (default: `j`)
- `$DIRJUMPER_COLOR` — set to `0` to disable colored output

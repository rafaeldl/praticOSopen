#!/usr/bin/env bash
#
# Links the versioned hooks in .githooks/ into the repo's hooks folder.
# Uses the common git dir, so every worktree gets them too. Other hooks
# already there (e.g. post-commit) are left alone.

set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
HOOKS_DIR=$(git config core.hooksPath || true)
if [ -z "$HOOKS_DIR" ]; then
  HOOKS_DIR="$(git rev-parse --git-common-dir)/hooks"
fi
# Hooks must point at the main checkout, which outlives worktrees
MAIN_ROOT=$(cd "$(git rev-parse --git-common-dir)/.." && pwd)

mkdir -p "$HOOKS_DIR"
for hook in "$ROOT"/.githooks/*; do
  name=$(basename "$hook")
  ln -sf "$MAIN_ROOT/.githooks/$name" "$HOOKS_DIR/$name"
  chmod +x "$hook"
  echo "✓ $name -> $HOOKS_DIR/$name"
done

#!/usr/bin/env bash
# Installs baton's git commit-msg hook in the current repo, so every commit is
# held to baton.md, not only the ones Claude makes. Runs at session start and
# before Claude commits.
#
# Only in repos that have a baton.md. Never overwrites a commit-msg hook it did
# not write, and leaves repos that set core.hooksPath (husky, a shared hooks
# directory) alone: there the hook belongs to the project's own setup.
set -u

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$root/baton.md" ] || exit 0
src="$(cd "$(dirname "$0")" && pwd)/commit-msg"

if [ -n "$(git -C "$root" config core.hooksPath)" ]; then
    echo "baton: this repo sets core.hooksPath, so baton's commit-msg hook was not installed and commits made outside Claude Code are not checked. To check them, add the logic from $src to the repo's commit-msg hook."
    exit 0
fi

# Hooks live in the common git dir, shared by every worktree of the repo.
common="$(cd "$root" && cd "$(git rev-parse --git-common-dir)" && pwd)"
dest="$common/hooks/commit-msg"

if [ -e "$dest" ] && ! grep -q 'baton-commit-msg-hook' "$dest"; then
    echo "baton: this repo already has a commit-msg hook, so baton's was not installed and commits made outside Claude Code are not checked. To check them, add the logic from $src to that hook."
    exit 0
fi

# Already current: say nothing.
cmp -s "$src" "$dest" && exit 0

mkdir -p "$common/hooks" && cp "$src" "$dest" && chmod +x "$dest" || exit 0
echo "baton: installed a git commit-msg hook in this repo, so every commit is held to baton.md, not only Claude's."

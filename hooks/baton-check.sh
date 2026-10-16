#!/usr/bin/env bash
# PreToolUse(Bash) — the relay-race baton check.
#
# baton.md is how one session hands the next its situation, in exactly three
# sections: what the last session finished, what to pick up next, and which
# decisions are waiting on the user. It only works if it is current: a stale
# handoff (one once asserted that a fix was unpushed and a closed issue was
# open) costs the next session a whole
# cycle disproving it.
#
# Repos without a baton.md are never touched: the check only applies once a
# project has opted in by creating the file (`/baton:update` does that).
#
# A commit is the last moment the agent is still holding the context needed to
# write that handoff, so it is the only reliable trigger. (A SessionEnd hook
# fires after the model has stopped; it can run a command but cannot compose an
# update.)
#
# Blocks `git commit` unless baton.md is part of the commit. Escape
# hatch, for a commit that genuinely changes nothing a next session needs to
# know: put [no-baton] anywhere in the command, or prefix BATON_SKIP=1.
set -uo pipefail

verdict="$(cat | python3 -c '
import json, shlex, sys

# Global git options that consume the following token, so the subcommand is not
# mistaken for their value. `git -C . commit` must still read as a commit.
VALUE_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path", "--super-prefix"}

def is_commit(segment):
    try:
        tokens = shlex.split(segment)
    except ValueError:
        tokens = segment.split()
    # Drop leading VAR=value assignments (BATON_SKIP=1 git commit ...).
    while tokens and "=" in tokens[0] and not tokens[0].startswith("-"):
        tokens.pop(0)
    if not tokens or tokens[0].rsplit("/", 1)[-1] != "git":
        return False
    i = 1
    while i < len(tokens):
        t = tokens[i]
        if not t.startswith("-"):
            return t == "commit"
        if t in VALUE_OPTS:
            i += 2
            continue
        i += 1
    return False

try:
    data = json.load(sys.stdin)
except Exception:
    print("SKIP"); sys.exit(0)

if data.get("tool_name") != "Bash":
    print("SKIP"); sys.exit(0)

cmd = data.get("tool_input", {}).get("command", "") or ""
if not cmd:
    print("SKIP"); sys.exit(0)

# The opt-out and --dry-run are read against the whole command, so a marker
# inside a heredoc commit message counts too.
if "[no-baton]" in cmd or "BATON_SKIP=1" in cmd or "--dry-run" in cmd:
    print("SKIP"); sys.exit(0)

# Only inspect up to the first heredoc body, so message text is not parsed as
# shell. Split on shell separators; a commit anywhere in the chain counts.
head = cmd.split("<<", 1)[0]
segments = head.replace("&&", "\n").replace("||", "\n").replace(";", "\n").replace("|", "\n").split("\n")
if not any(is_commit(s) for s in segments):
    print("SKIP"); sys.exit(0)

print("CHECK")
' 2>/dev/null)"

[ "${verdict:-SKIP}" = "SKIP" ] && exit 0

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
baton="baton.md"
[ -f "$repo_root/$baton" ] || exit 0

# Staged or merely modified both count. The hook runs *before* the command, so a
# `git add -A && git commit` has not staged anything yet, and `git commit -a`
# stages at commit time — insisting on the index would block both while the edit
# sat right there in the tree. The question this check exists to ask is "did you
# write the handoff", not "is your index tidy".
#
# Collected into a variable and matched in-shell rather than piped into `grep -qx`.
# That pipe was a latent bug: `grep -q` exits the moment it matches, so when the
# match came from the *first* command the second `git diff` was still writing and
# took a SIGPIPE (141) — which `set -o pipefail` then reported as the pipeline's
# status, failing the `if` and blocking the commit. It triggered exactly when
# baton.md was staged alongside other unstaged files, i.e. when following
# the instruction this hook prints, and it was timing-dependent enough to look
# intermittent.
changed="$( { git -C "$repo_root" diff --cached --name-only;
              git -C "$repo_root" diff --name-only; } 2>/dev/null )"
if [[ $'\n'"$changed"$'\n' == *$'\n'"$baton"$'\n'* ]]; then
    exit 0
fi

cat >&2 <<'MSG'
BATON NOT PASSED — baton.md is not part of this commit.

baton.md is the handoff to the next session, and this is the last moment
you are still holding the context needed to write it. Before committing:

  1. Run /baton:update (the `baton:update` skill) and follow it.
  2. Stage baton.md alongside your other changes.
  3. Re-run this commit.

If this commit genuinely changes nothing the next session needs to know (a typo,
a formatting pass), do NOT write a cosmetic edit just to satisfy this check —
add [no-baton] to the command instead, and say so in your reply to the user.
MSG
exit 2

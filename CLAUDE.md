# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code **plugin marketplace** (named `laight`) holding two independently installable plugins.
There is no build, no package manager and no test suite: the product is Markdown prompts plus one
shell hook. `README.md` is the user-facing description; keep it in step with any behaviour change.

- `.claude-plugin/marketplace.json` — lists both plugins; makes the repo installable via `/plugin marketplace add berni23/claude-plugins`.
- `plugins/baton/` — session handoff: `skills/pickup`, `skills/update` (→ `/baton:pickup`, `/baton:update`) and `hooks/`, which hold every commit, human or Claude, to `baton.md` (see "Hook details").
- `plugins/cross/` — PR review: `skills/cr`, `skills/fix-cr` (→ `/cross:cr`, `/cross:fix-cr`), `agents/code-reviewer.md`, which `cr` spawns twice as `subagent_type: "cross:code-reviewer"`, and `agents/fix-planner.md`, which `fix-cr` spawns twice as `"cross:fix-planner"`.
- Each plugin has its own `.claude-plugin/plugin.json` holding its version.

The plugins must work alone: a reference from one to the other (e.g. `pickup` suggesting
`/cross:fix-cr`) stays conditional on the other being installed.

## Checking changes

```sh
claude plugin validate .                     # marketplace manifest
claude plugin validate plugins/baton         # each plugin manifest
claude plugin validate plugins/cross

# Exercise the hook by piping it a PreToolUse payload; exit 0 = allowed, 2 = blocked (message on stderr)
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | plugins/baton/hooks/baton-check.sh; echo $?
```

The hook only acts in a repo whose root has a `baton.md`, so to see it block, run it from a scratch
git repo that has one. This repo itself has no `baton.md`, so the hook never fires here.

## How the pieces fit

The skills come in two pairs, and each half is written for the other as its reader:

- **`update` ↔ `pickup`** (baton). `update` rewrites `baton.md` in exactly three sections (done / next items
  in order with the why / decisions waiting on the user). `pickup` treats section 1 as claims to
  verify against git and the tracker, section 2 as the work order, section 3 as blockers to check
  first. Changing the section structure in one skill means changing the other.
- **`cr` ↔ `fix-cr`** (cross). `cr` runs `code-reviewer` twice with different lenses (Opus: runtime/state/
  failure; Sonnet: spec/contract/tests), verifies findings, and posts one merged GitHub review tagged
  `[A+B]`/`[A]`/`[B]`. `fix-cr` mirrors it: two Opus `fix-planner`s (smallest change / root cause)
  plan every finding independently from a numbered `scratch.findings`, and the session compares them
  with the same tiers. The planners only advise: deciding, editing and replying on the PR stay **in
  the session that wrote the code** and are never delegated.

Design rules the baton skills enforce (see README "Why it's built this way"): the baton never contains
anything `git`/`gh` can answer (branches, SHAs, merge/push state); it is rewritten, never appended
(~60 lines); bugs go to the tracker and decisions to the spec, never only in the baton.

The skills assume nothing about the target project: they read conventions (check command, tracker,
roadmap) from that project's `CLAUDE.md`/`AGENTS.md`. Tracker is GitHub issues by default, or
whatever the spec names; `cr`/`fix-cr` are GitHub-only.

## Hook details worth knowing

The rule "a commit must include `baton.md`, in a repo that has one" is enforced twice, and both
copies must stay in step (opt-outs, merge/rebase skips, wording):

- `commit-msg` — a git hook, so it holds **every** commit, from a terminal, an IDE or Claude. Checks
  the index only. Opt-outs: `[no-baton]` in the message, `BATON_SKIP=1`, `--no-verify`.
- `install-git-hook.sh` copies it into the repo's hooks dir. It runs on `SessionStart` and from
  `baton-check.sh`, only where `baton.md` exists; it never overwrites a commit-msg hook without the
  `baton-commit-msg-hook` marker and skips repos that set `core.hooksPath`, printing why instead.
- `baton-check.sh` — the PreToolUse(Bash) hook. It stays alongside the git hook because it stops
  Claude *before* the commit runs, with instructions it can act on (`/baton:update`), and covers
  repos where the git hook couldn't be installed.

`baton-check.sh` parses the command with an inline Python script (needs `python3`): it skips
leading `VAR=value` assignments and global git options that take a value (`-C`, `-c`, …), splits on
`&&`/`||`/`;`/`|`, and ignores everything after the first `<<` so heredoc commit messages aren't
parsed as shell. Opt-outs (`[no-baton]`, `BATON_SKIP=1`, `--dry-run`) are matched anywhere in the
full command. Staged *or* unstaged changes to `baton.md` both pass, because the hook runs before
`git add -A && git commit` / `git commit -a` stage anything. Output is collected into a variable
rather than piped to `grep -q` — that pipe caused an intermittent SIGPIPE block under `pipefail`.

## Conventions

- Commits in this repo carry `[no-baton]` in the subject (there's no `baton.md` here).
- User-visible changes get a `CHANGELOG.md` entry under `## Unreleased`; a release bumps
  `version` in `plugin.json` and renames that section.

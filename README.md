# baton

A relay-race handoff between Claude Code sessions, and a two-reviewer PR review loop.

Every session starts cold. The next one wastes its first half-hour working out where the last one
stopped, or trusts a stale note and builds on something that isn't true. **baton** keeps one short
file, `baton.md`, that says what the last session finished, what to do next and in which order, and
which decisions are waiting on you. It is written at the one moment the context is still there:
right before the commit.

```
/baton:pickup  →  work  →  /baton:update  →  commit  →  /baton:cr  →  /baton:check-cr
     ↑                                                                        │
     └────────────────────────── next session ───────────────────────────────┘
```

## Install

```
/plugin marketplace add berni23/baton-claude-skills
/plugin install baton@baton
```

Needs [`gh`](https://cli.github.com) signed in for the GitHub parts, and `python3` for the commit
hook.

## What's in it

| | What it does |
|---|---|
| `/baton:pickup` | Session start. Reads the spec (`CLAUDE.md` / `AGENTS.md`) and `baton.md`, checks every claim in it against `git log` and `gh`, fixes what's stale, then works the next item. An open PR with an unanswered review comes first. |
| `/baton:update` | Before a commit. Rewrites `baton.md`: what was done (verified only), the next items in order with the *why*, decisions waiting on you. Never branch names, SHAs or merge state: git knows those better. Bugs go to issues and decisions to the spec, not the baton. |
| `/baton:cr` | Reviews a PR twice, independently: one Opus reviewer leading with runtime, state and failure, one Sonnet reviewer leading with spec, contract and test coverage. Verifies every finding, then posts **one** merged GitHub review, tagging each finding `[A+B]`, `[A]` or `[B]`. Open questions go to a local `scratch.review`. |
| `/baton:check-cr` | Answers the review, in the session that wrote the code. Triages each finding (real, already fixed, wrong, out of scope → issue, spec disagreement), fixes the real ones with a test seen failing first, and replies on every thread. |
| `code-reviewer` agent | The reviewer `/baton:cr` runs twice. Reviews against your project's own spec and verifies each finding before reporting it. |
| `baton-check` hook | Blocks a `git commit` that doesn't include `baton.md`. **Only in repos that have a `baton.md`**, so installing the plugin changes nothing until you opt a repo in. Escape hatch: `[no-baton]` in the commit command. |

## Starting in a repo

Run `/baton:update` once; it creates `baton.md`. Commit it. From then on, start sessions with
`/baton:pickup`.

The skills read your project's conventions from its spec rather than assuming any: the check command
from `CLAUDE.md`, `CONTRIBUTING.md`, the `Makefile` or CI; work items from your tracker and from a
roadmap if your spec has one.

**Tracker.** `/baton:pickup` and `/baton:update` use GitHub issues by default. To use another
tracker, name it in your `CLAUDE.md` (e.g. "Work is tracked in Jira, project PROJ"); the skills then
use whatever CLI or MCP server the session has for it, and the baton names items by that tracker's
ids (`PROJ-123`). With no tracker at all, the roadmap in your spec stands in for it. The better your `CLAUDE.md` states its hard rules, the sharper the
reviews.

## Why it's built this way

- **The baton is lossy by contract.** Anything `git` or `gh` can answer (merged? pushed? PR open?)
  is forbidden in it, because it rots within hours and sessions derail chasing the contradiction.
- **It is rewritten, never appended.** About 60 lines, a one-minute read. Last session's history is
  in git.
- **It is never a finding's only home.** Work goes on an issue, design decisions in the spec.
- **Two reviewers who never see each other.** A finding both raise is almost certainly real; a
  finding only one raises is the one worth a second look.
- **The fix happens where the context is.** `/baton:check-cr` refuses to delegate: the session that
  wrote the code knows why each line is the way it is.

Born in [laight](https://github.com/berni23/laight), where it carries every session.

## License

Apache-2.0

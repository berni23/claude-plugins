# laight plugins for Claude Code

Two independent [Claude Code](https://code.claude.com) plugins from the `laight` marketplace.
Install either one, or both.

| Plugin | What it is for |
|---|---|
| [**baton**](#baton--session-handoff) | A handoff between Claude Code sessions that can't go stale: written at every commit, verified against git at the next session's start. |
| [**cross**](#cross--two-reviewer-pr-review) | Two independent code reviewers, one merged and verified GitHub review, answered in the session that wrote the code. |

```
/plugin marketplace add berni23/claude-plugins
/plugin install baton@laight
/plugin install cross@laight
```

Both need [`gh`](https://cli.github.com) signed in for their GitHub parts. Both read your project's
conventions from its spec (`CLAUDE.md` / `AGENTS.md`) rather than assuming any: the check command
from `CLAUDE.md`, `CONTRIBUTING.md`, the `Makefile` or CI.

---

## baton — session handoff

Every session starts cold. The next one wastes its first half-hour working out where the last one
stopped, or trusts a stale note and builds on something that isn't true. **baton** keeps one short
file, `baton.md`, that says what the last session finished, what to do next and in which order, and
which decisions are waiting on you. It is written at the one moment the context is still there:
right before the commit.

```
/baton:pickup  →  work  →  /baton:update  →  commit
     ↑                                          │
     └──────────── next session ────────────────┘
```

```
/plugin install baton@laight
```

Also needs `python3` for the commit hook.

| | What it does |
|---|---|
| `/baton:pickup` | Session start. Reads the spec and `baton.md`, checks every claim in it against `git log` and the tracker, fixes what's stale, then switches to a branch for the next item and works it. An open PR with an unanswered review comes first. |
| `/baton:update` | Before a commit. Rewrites `baton.md`: what was done (verified only), the next items in order with the *why*, decisions waiting on you. Never branch names, SHAs or merge state: git knows those better. Bugs go to issues and decisions to the spec, not the baton. |
| Commit check | Blocks any commit that doesn't include `baton.md`, whether you make it from a terminal or an IDE or Claude makes it. **Only in repos that have a `baton.md`**, so installing the plugin changes nothing until you opt a repo in. Escape hatch: `[no-baton]` in the commit message (or `git commit --no-verify`). |

**Starting in a repo.** Start every session with `/baton:pickup`, the first one included. With no
`baton.md` yet, it proposes a first one from your tracker and roadmap, asks you to confirm the order,
writes it, and starts on the first item. It goes in with your first commit.

**How the commit check works.** In a repo with a `baton.md`, the plugin installs a git
`commit-msg` hook (in `.git/hooks`, so it is local to your clone and never committed), which checks
every commit. Claude's own commits are also stopped before they run, with instructions to run
`/baton:update`. If the repo already has a `commit-msg` hook, or sets `core.hooksPath` (husky and
similar), baton leaves it alone and tells you how to add the check yourself. A clone where Claude
has never run in has no git hook; copy `plugins/baton/hooks/commit-msg` to `.git/hooks/commit-msg`
there.

**Branches.** The baton is committed with the work, on the work's branch. `/baton:pickup` reads the
newest one across all branches, so a session that starts on `main` before the last PR merged still
gets the latest handoff.

**Tracker.** `/baton:pickup` and `/baton:update` use GitHub issues by default. To use another
tracker, name it in your `CLAUDE.md` (e.g. "Work is tracked in Jira, project PROJ"); the skills then
use whatever CLI or MCP server the session has for it, and the baton names items by that tracker's
ids (`PROJ-123`). With no tracker at all, the roadmap in your spec stands in for it.

**Why it's built this way**

- **The baton is lossy by contract.** Anything `git` or `gh` can answer (merged? pushed? PR open?)
  is forbidden in it, because it rots within hours and sessions derail chasing the contradiction.
- **It is rewritten, never appended.** About 60 lines, a one-minute read. Last session's history is
  in git.
- **It is never a finding's only home.** Work goes on an issue, design decisions in the spec.

---

## cross — two-reviewer PR review

One reviewer's findings are one reviewer's judgement. **cross** reviews a PR twice, with two agents
that never see each other's output, verifies every finding, and posts one merged review. Then the
session that wrote the code answers it.

```
open PR  →  /cross:cr  →  /cross:fix-cr  →  push
```

```
/plugin install cross@laight
```

GitHub-only. The better your `CLAUDE.md` states its hard rules, the sharper the reviews.

| | What it does |
|---|---|
| `/cross:cr` | Reviews a PR twice, independently: one Opus reviewer leading with runtime, state and failure, one Sonnet reviewer leading with spec, contract and test coverage. Verifies every finding, then posts **one** merged GitHub review, tagging each finding `[A+B]`, `[A]` or `[B]`. Open questions go to a local `scratch.review`. |
| `/cross:fix-cr` | Answers the review. Two independent Opus planners each plan every finding (fix, reject, already fixed, out of scope → issue, spec disagreement, needs you); the session that wrote the code compares the plans with the same `[A+B]`/`[A]`/`[B]` trust, shows you the decision table, fixes the real ones one at a time with a test seen failing first, and replies on every thread. Works on any review, not only one from `/cross:cr`. |
| `code-reviewer` agent | The reviewer `/cross:cr` runs twice. Reviews against your project's own spec and verifies each finding before reporting it. |
| `fix-planner` agent | The planner `/cross:fix-cr` runs twice. Gives every finding a verdict and a plan with its regression test; reads the code but never edits it. |

**Why it's built this way**

- **Two reviewers who never see each other.** A finding both raise is almost certainly real; a
  finding only one raises is the one worth a second look.
- **Two plans, one pair of hands.** `/cross:fix-cr` gets two independent plans for every
  finding, but only the session that wrote the code decides and edits: it knows why each line is
  the way it is. Plans are cheap to compare; competing edits are not.

---

## Together

The two plugins work alone and know about each other only lightly. `/baton:pickup` always treats an
open PR with an unanswered review as the next work, ahead of anything new; with cross installed, it
points you at `/cross:fix-cr` to answer it.

Both come from [laight](https://github.com/berni23/laight), the project they were built for and
where they carry every session; the marketplace takes its name from it.

## License

Apache-2.0

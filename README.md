# laight plugins for Claude Code

Two independent [Claude Code](https://code.claude.com) plugins. Install either one, or both.

| Plugin | In one line |
|---|---|
| [**cross**](#cross--two-blind-ai-reviewers-one-final-pr-review) | Two AI reviewers with different models and lenses review your PR blind; a third pass, with your session's context, writes **one** GitHub review that says where each comment came from. |
| [**baton**](#baton--sessions-that-pick-up-where-the-last-one-stopped) | Every Claude Code session leaves a short handoff at commit time, and the next one checks it against git before trusting it. No more cold starts. |

```
/plugin marketplace add berni23/claude-plugins
/plugin install cross@laight
/plugin install baton@laight
```

Both need [`gh`](https://cli.github.com) signed in for their GitHub parts, and both read your
project's conventions (check command, tracker, hard rules) from its `CLAUDE.md` / `AGENTS.md`
instead of assuming any.

<!-- TODO: demo GIF of /cross:cr posting a review, then /cross:fix-cr answering it -->

---

## cross — two blind AI reviewers, one final PR review

A single AI reviewer has two problems. It misses things, and it reports things that aren't true:
a "race condition" that can't happen, a "missing null check" two lines above. You end up reviewing
the review.

**cross** fixes both:

- **Two reviewers, reviewing blind.** One Opus reviewer leads with runtime, state and failure modes.
  One Sonnet reviewer leads with spec, contract and test coverage. Neither sees the other's output.
- **A third pass writes the final review.** The session you run it from reads both reviews, checks
  each finding against the code, drops false positives and noise (recording why), and adds what it
  sees itself, including from the ticket or requirements it already has in context. It's a
  reviewer, not a referee. Nobody runs the PR's code; everything is checked by reading.
- **It informs a human review; it doesn't replace one.** Checked by reading is not proven. Have
  someone look at the review before acting on it, on anything that matters.
- **One review, with a trust label on every comment.** It posts as a normal GitHub review, and each
  comment is tagged with who found it:
  - **`[A+B]`**: both reviewers found it on their own. Almost certainly real.
  - **`[A]`** / **`[B]`**: only one found it, and the final pass re-checked it before posting. These
    are the bugs a single reviewer would have missed.
  - **`[S]`**: added by the final pass itself: something both reviewers missed, or a requirement
    from the ticket in your session that the diff misses. The reviewers never see that context;
    the final pass uses it to add findings or clear ones about scope the ticket already answers.
    It never clears a real defect, and never goes looking for context it doesn't have.

> **[A+B]** `retry()` re-enqueues the job before the lock is released, so a fast worker picks it up
> while the first attempt is still writing. Two writes to the same row. Confirmed by reading
> `worker.ts:88–104`: the `finally` that releases the lock runs after `enqueue()`.
>
> <sub>Example of a posted comment.</sub>

Then **`/cross:fix-cr`** answers the review, and it works on any review, not just one from
`/cross:cr`, including your colleagues'. Two independent planners decide for each finding whether
to fix it, reject it (with the reason) or turn it into an issue. The session that wrote the code
compares their plans, shows you a decision table, then fixes the real findings one at a time,
starting each with a test that fails, and replies on every thread.

```
open PR  →  /cross:cr  →  /cross:fix-cr  →  push
```

```
/plugin install cross@laight
```

GitHub-only. The more clearly your `CLAUDE.md` states its hard rules, the sharper the reviews get.

- **Run `/cross:cr` checked out on the PR's branch**, pushed: the reviewers read your local tree.
- **`/cross:fix-cr` never pushes.** It commits the fixes and names them in its replies; push them
  yourself so reviewers can see them.
- Opus and Sonnet are the defaults. If one isn't available to you, the skills fall back to the
  other and say so in the review.

| | What it does |
|---|---|
| `/cross:cr [PR]` | Runs the two reviewers in parallel, sorts their findings into *both* / *one only* / *contradicted*, then writes the final review itself (re-checking single-reviewer findings, dropping noise, adding its own with your session's context) and posts **one** `COMMENT` review with inline comments tagged `[A+B]`, `[A]` or `[B]` (or `[S]` for its own). Open questions and dropped false positives go to a local, git-ignored `scratch.review`. |
| `/cross:fix-cr [PR]` | Two independent Opus planners (one aiming for the smallest change, one for the root cause) give every finding a verdict: fix, reject, already fixed, out of scope → issue, spec disagreement, or needs you. The session compares their plans using the same `[A+B]`/`[A]`/`[B]`/`[S]` trust, shows you the decisions, applies the fixes test-first and replies on every thread. |
| `code-reviewer` agent | The reviewer `/cross:cr` runs twice. Reviews against your project's own spec and checks each finding against the code before reporting it. |
| `fix-planner` agent | The planner `/cross:fix-cr` runs twice. Reads the code, never edits it. |

**Why it's built this way**

- **Agreement is a signal, disagreement is where the value is.** A finding both raise is almost
  certainly real. A finding only one raises is either a bug the other missed or a false positive,
  so that tier gets a second look by hand.
- **Two plans, one pair of hands.** Two planners advise on the fixes, but only the session that
  wrote the code decides and edits, because it knows why each line is the way it is. Comparing
  plans is cheap. Merging competing edits is not.

---

## baton — sessions that pick up where the last one stopped

Every Claude Code session starts cold. The next one wastes its first half-hour working out where
the last one stopped, or trusts a stale note and builds on something that isn't true anymore.

**baton** keeps one short file, `baton.md`: what the last session finished, what to do next and in
which order, and which decisions are waiting on you. It gets written at the one moment the context
is still there, right before the commit. And the next session doesn't take it on trust: it checks
every claim against git and your tracker first.

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
| `/baton:pickup` | Session start. Reads the spec and `baton.md`, checks every claim in it against `git log` and the tracker, fixes what's stale, then switches to a branch for the next item and works on it. An open PR with an unanswered review comes first. |
| `/baton:update` | Before a commit. Rewrites `baton.md`: what was done (verified only), the next items in order with the *why*, and the decisions waiting on you. It never records branch names, SHAs or merge state, because git knows those better. Bugs go to issues and decisions to the spec, not the baton. |
| Commit check | Blocks any commit that doesn't include `baton.md`, whether you make it from a terminal or an IDE or Claude makes it. **Only in repos that have a `baton.md`**, so installing the plugin changes nothing until you opt a repo in. Escape hatch: `[no-baton]` in the commit message (or `git commit --no-verify`). |

**Starting in a repo.** Start every session with `/baton:pickup`, including the first one. If
there's no `baton.md` yet, it proposes one from your tracker and roadmap, asks you to confirm the
order, writes it, and starts on the first item. The file goes in with your first commit.

**How the commit check works.** In a repo with a `baton.md`, the plugin installs a git
`commit-msg` hook that checks every commit. The hook lives in `.git/hooks`, so it is local to your
clone and never committed. Claude's own commits are also stopped before they run, with instructions
to run `/baton:update`. If the repo already has a `commit-msg` hook, or sets `core.hooksPath` (husky
and similar), baton leaves it alone and tells you how to add the check yourself. A clone Claude has
never run in has no git hook yet; to add it there, copy `plugins/baton/hooks/commit-msg` to
`.git/hooks/commit-msg`.

**Branches.** The baton is committed with the work, on the work's branch. `/baton:pickup` reads the
newest one across all branches, so a session that starts on `main` before the last PR merged still
gets the latest handoff.

**Tracker.** `/baton:pickup` and `/baton:update` use GitHub issues by default. To use another
tracker, name it in your `CLAUDE.md` (e.g. "Work is tracked in Jira, project PROJ"). The skills
then use whatever CLI or MCP server the session has for it, and the baton refers to items by that
tracker's ids (`PROJ-123`). With no tracker at all, the roadmap in your spec stands in for it.

**Why it's built this way**

- **The baton leaves things out on purpose.** Anything `git` or `gh` can answer (merged? pushed?
  PR open?) is forbidden in it, because that goes stale within hours and sessions get derailed
  chasing the contradiction.
- **It is rewritten, never appended.** About 60 lines, a one-minute read. The history of past
  sessions lives in git.
- **It is never the only place a finding is recorded.** Work goes on an issue, design decisions in
  the spec.

---

## Together

The two plugins work alone and know about each other only lightly. `/baton:pickup` always treats an
open PR with an unanswered review as the next piece of work, ahead of anything new. With cross
installed, it points you to `/cross:fix-cr` to answer it.

Both come from [laight](https://github.com/berni23/laight), the project they were built for and
where they're used in every session. The marketplace is named after it.

## License

Apache-2.0

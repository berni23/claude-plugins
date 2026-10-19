# Changelog

## Unreleased

- `/cross:cr` uses the ticket, acceptance criteria and decisions already in the session that runs
  it, without fetching any, when it reconciles the two reviews: it can drop a finding about scope
  the ticket answers, or add one the reviewers couldn't see, tagged `[S]`. The reviewers never
  get that context. No context removes a real defect, and the author's rationale is not evidence.
- The reviewers and planners no longer run the project's code (tests, builds, check commands):
  they confirm findings by reading, since the PR under review controls what would execute.
- `/cross:cr` may drop low-severity findings, especially those only one reviewer raised.
- `/cross:cr` checks this round's findings against earlier rounds' threads, after both reviewers
  finish: a finding rejected before, for a reason that still holds, isn't posted again.
- `/cross:cr` stops if you are not on the PR's branch, instead of reviewing the wrong tree.
- Model fallback: if Opus or Sonnet isn't available, `/cross:cr` and `/cross:fix-cr` run on the
  other model instead of stopping, and say so.
- Documented that `/cross:fix-cr` never pushes.
- Docs describe `/cross:cr`'s final pass as a third reviewer (it adds its own `[S]` findings, not
  only context ones), stop calling the result "verified", and recommend a human review on top.

## 0.3.0

- **Split into two plugins** in the same marketplace, installable separately: `baton` (`pickup`,
  `update`, the `baton-check` hook) and `cross` (`cr`, `fix-cr`, the `code-reviewer` and `fix-planner` agents).
  **Breaking:** `/baton:cr` and `/baton:check-cr` are now `/cross:cr` and `/cross:fix-cr`; install
  them with `/plugin install cross@laight`.
- **Breaking:** the repo is now `berni23/claude-plugins` and the marketplace is named `laight`
  (was `baton`). Re-add it with `/plugin marketplace add berni23/claude-plugins` and install
  `baton@laight`.
- `/baton:pickup` bootstraps the first `baton.md` in a repo that has none: it proposes an order
  from the tracker and roadmap, asks you to confirm it, writes the file and starts on the first
  item. Start every session with `/baton:pickup`, the first one included.
- The commit check holds **every** commit to `baton.md`, not only Claude's: in a repo with a
  `baton.md`, the plugin installs a git `commit-msg` hook (at session start, or before Claude's
  next commit). It never overwrites an existing `commit-msg` hook and skips repos that set
  `core.hooksPath`. The opt-out is now `[no-baton]` in the commit **message**; `--no-verify`
  also skips it.
- `/baton:pickup` and `/baton:update` read the newest `baton.md` across all branches, not just the
  checked-out one, so a session that starts on `main` before the last PR merged doesn't follow an
  out-of-date handoff. A merge conflict in `baton.md` is resolved by taking the newer side and
  rewriting it.
- `/baton:pickup` switches to a branch named after the item before its first edit, never working
  on the default branch; uncommitted work left there moves with it.
- **Breaking:** `check-cr` is renamed `/cross:fix-cr` and now works like `/cross:cr`: two
  independent Opus `fix-planner` agents (smallest change / root cause) plan an answer to every
  finding, and the session compares the plans with the same `[A+B]`/`[A]`/`[B]` trust, shows the
  decision table, then fixes one finding at a time. It also checks the review is for the current
  `HEAD`, and rebuilds intent from the PR, spec and git log when the session didn't write the code.
- `/baton:pickup` and `/cross:fix-cr` no longer tell Claude to hold off on committing and pushing
  until asked; that is left to your own Claude Code settings and instructions.

## 0.2.0

- `/baton:pickup` and `/baton:update` work with any tracker: GitHub issues by default, or the one
  your `CLAUDE.md` names (Jira, Linear, GitLab…), through the session's CLI or MCP server for it.
  With no tracker, the spec's roadmap stands in.

## 0.1.0

- First release: `/baton:pickup`, `/baton:update`, `/baton:cr`, `/baton:check-cr`, the
  `code-reviewer` agent and the `baton-check` commit hook.

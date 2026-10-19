---
name: fix-cr
description: Address the code review on a PR (the latest, or the current branch's) — two independent fix-planner agents plan an answer to every finding, then this session compares the plans, decides, applies the fixes and replies on the PR. It never pushes; pushing the fixes is left to the user. Use after /cross:cr or any other review lands on a PR.
argument-hint: [PR number or URL] [scope notes, e.g. "only the API findings"]
---

Address the review on a PR: **fix what is real, rebut what is not, file what can wait.**
Target: $ARGUMENTS

`/cross:cr` is the other half of this pair and it *posts* a review. This one *answers* it, the same
way: two independent opinions, then one verified result.

⚠️ **The planners advise; this session decides, edits and answers.** Two `fix-planner` agents each
write a plan for every finding, without seeing each other's. You compare them, and you alone touch
the code and the PR. The session that produced the PR knows why each line is the way it is — the
context the planners and the reviewer lack — so the decision never leaves it. Do not hand the edits
to a subagent.

## 1. Resolve the PR

With no argument, take the PR for the current branch; if the branch has none, take the most
recently created open PR that is not from Dependabot. A number or a URL both work.

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner                 # <owner>/<repo> below
gh pr view --json number,title,body,headRefName,baseRefName,headRefOid,url   # current branch's PR
gh pr list --limit 5 --json number,title,headRefName,author,updatedAt
git status --short
git fetch origin && git rev-list --left-right --count origin/<branch>...<branch>
```

State which PR you are working on in one line before touching anything. Be on its branch.

**`/cross:cr` posts one merged review from two independent reviewers**: agent A (**Opus**, runtime,
state & failure lens) and agent B (**Sonnet**, spec, contract & coverage lens). Each finding is
tagged **`[A+B]`**, **`[A]`** or **`[B]`** — or **`[S]`**, added by the orchestrator from a ticket or
requirement it had in context — and the orchestrator verified it before posting. Tell the
user this in one line when you name the PR. A review from anyone else has no tags; address it the
same way.

**Did this session write the code?** If not — a fresh session, after `/baton:pickup` or a compaction
— the intent the skill relies on has to be rebuilt before you judge anything: read the PR
description, the spec, `baton.md` if there is one, and `git log <base>..HEAD`. Say in one line that
you are working from those, and in §4 take the user's call on more of the split findings.

## 2. Collect the whole review — all four surfaces

```bash
gh api repos/<owner>/<repo>/pulls/<n>/reviews --jq '.[] | "\(.id) \(.user.login) \(.state) \(.commit_id)\n\(.body)\n"'
gh api repos/<owner>/<repo>/pulls/<n>/comments --jq '.[] | "\(.id) \(.path):\(.line) \(.user.login)\n\(.body)\n"'
gh pr view <n> --comments
cat scratch.review 2>/dev/null || echo "(no scratch.review)"
```

⚠️ **Reading only the inline comments loses findings.** A finding about something *absent* from the
diff cannot be anchored to a line, so it goes in the **review body** — and file-level notes land
there too.

**`scratch.review`** in the repo root is where `/cross:cr` writes the half GitHub has no shape for:
open questions, cross-cutting concerns, verification gaps, judgement calls made on your behalf, and
the findings it **dropped** as false positives and why (don't resurrect one without new evidence).
**None of it is on the PR.** ⚠️ It is git-ignored and overwritten per review round, so check it
names *this* PR and commit at the top; if it names another, say so and ignore it.

**If there is no review, stop and say so.** A green CI check is not a review. Offer `/cross:cr`
instead of inventing findings.

Skip threads that are already resolved or already answered, and note how many you skipped.

⚠️ **Is the review current?** Compare the review's `commit_id` with `HEAD`. If the branch has moved
since, `git diff <commit_id>..HEAD --stat` and re-locate each finding in today's tree before planning
— a line number from the review may now point elsewhere, and a finding may already be fixed.

**Write the findings down, numbered** — this is the planners' only input, and the shared numbering is
what makes their plans comparable. Keep the files out of git first:

```bash
git check-ignore -q scratch.findings || printf 'scratch.findings\nscratch.plan*\n' >> "$(git rev-parse --git-path info/exclude)"
```

Then write `scratch.findings` (overwrite): the PR, the commit reviewed, `HEAD`, and one entry per
finding — number, tag, source (thread id / review body / `scratch.review`), location in today's
tree, and the claim **as the reviewer stated it**. ⚠️ **Add no opinion of yours** — no "this looks
wrong", no severity. The planners are independent only if nothing in their input leans.

## 3. Plan twice, independently and in parallel

Launch two `fix-planner` agents (Agent tool, `subagent_type: "cross:fix-planner"`), **both in a
single message** so they run concurrently, **both on Opus** (`model: "opus"`, the latest). Pass
`model` explicitly. If Opus is unavailable, run both on Sonnet (`model: "sonnet"`) rather than stop,
and say so in your report — never silently.

**Lenses:** both plan every finding, but each leads with a different question:
- **A — the smallest correct change:** is the finding real at all, and what is the least code that
  removes the failure without moving anything else? Leans towards rejecting what the spec or a
  test already answers.
- **B — the root cause:** why did this happen, does the same defect live elsewhere, and which
  tests and spec text should change with the fix?

Tell each: the PR (`<owner>/<repo>` #`<n>`), its lens, the findings file `scratch.findings`, and its
output file — **A to `scratch.plan.a`, B to `scratch.plan.b`**. Tell each explicitly: **do not edit
source, commit, push or post; do not read PR replies or any other plan.** ⚠️ Neither may be told the
other exists, and nothing passes between them.

⚠️ **A planner that stops without a completion record has written nothing** — check both files exist,
name this PR and cover every numbered finding before comparing.

## 4. Compare and decide — in this session

Match the two plans finding by finding and sort each into a tier:

- **`[A+B]` agree** — same verdict, compatible plan. Highest confidence: take it, after a quick
  check that it doesn't contradict what you know about why the code is this way. Agreement to
  **reject** is as strong as agreement to fix.
- **`[A]` / `[B]` — only one wants to act** — the other rejects or defers. ⚠️ **Reproduce the
  finding yourself** before deciding; this is the tier where one planner caught what the other
  missed, or got it wrong.
- **Both fix, differently** — pick one plan or merge them, and say why. B's wider fix is not better
  by default: wider than the PR needs is a scope question.
- **Contradicted, or either says `user`** — if reproducing it doesn't settle it, **ask the user in
  your report; do not guess and proceed.**

**Rate severity yourself; don't inherit the reviewer's or a planner's.** Each finding ends as one of:
**fix**, **reject** (with the reason), **already fixed** (name the commit — the branch needs pushing),
**issue** (⚠️ file it: `gh issue create`, or link one that already covers it — never park it in
`baton.md`, which is rewritten every session), **spec** (fix whichever of code and spec is wrong, in
this change), or **user**.

⚠️ **`scratch.review` entries are mostly questions, not findings.** Answer what the tree settles, ask
the user what only they can settle, file what is real work, and leave alone what was recorded so
nobody re-litigates it.

**Show the decision table before editing anything**: number, tag of the original finding, planner
tier, your decision, one line why. If any row is `user`, you may carry on with the rest, but those
rows wait.

Then delete the plans: `rm -f scratch.plan.a scratch.plan.b scratch.findings`.

## 5. Fix — one finding at a time

Read the spec sections around each change — its hard requirements, the section the code implements,
and its rules for working on the repo. Most findings are about an interaction between the change and
one of those rules, not about the hunk.

Apply the decided fixes **one finding at a time**: fix, run the relevant tests, move on. Keep each fix
self-contained — one commit per finding, if you commit — so one wrong fix can be reverted without
losing the others. If fixes interact (the plans' *Cross-cutting* section), land them in the order
that keeps each step green.

**Every fix gets a regression test, and the test must be verified to fail before the fix.** Mutate
the fix away, watch the test fail, restore it. ⚠️ **Assert the mutation actually landed** — an edit
that silently matches nothing reads as evidence of coverage while proving nothing. A test written
after the fix and never seen red is a comment, not a test.

If three candidate fixes all feel awkward, the shape is probably wrong — say so instead of ranking
workarounds.

## 6. Verify

Run what CI runs, and do not report success on anything you have not run. Find the command in the
spec, `CONTRIBUTING.md`, the `Makefile` / `package.json` scripts, or `.github/workflows/`. If a fix
touches something a unit test cannot prove, also do a real run.

## 7. Answer on the PR

Reply on **each** thread you acted on, saying what changed — and on each you rejected, saying why.
⚠️ **This skill does not push.** Name the commit in each reply; until the user pushes, reviewers on
GitHub cannot see it, so say so in your report (§8).
A finding that is silently dropped reads as one that was missed.

```bash
gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment-id>/replies -f body='...'
```

Findings that were in the review **body** have no thread: answer them together in one PR comment
(`gh pr comment <n> --body-file …`). Resolving threads is left to a human.

⚠️ **`scratch.review` items have no thread either.** Where one changed the code, say so in the commit
message or the PR comment; where it was a question, answer it in your report to the user (§8).
Do not silently drop one because it had no comment id.

## 8. Report

Give the user: what you fixed (with the test that pins each), what you rejected and why, what you
filed as an issue, and what is still open — noting for each the review's tag (`[A+B]`, `[A]`, `[B]`)
and whether the planners agreed. **Lead with anything waiting on the user.**

**Cover the `scratch.review` items explicitly and separately** — they are the ones the user is most
likely to be waiting on, because several are questions addressed to them. For each: answered (with
the answer), fixed, filed, or still needs them. Then say whether the file is spent; offer to rewrite
it with whatever is genuinely still open, and leave it alone otherwise — it is the next `/cross:cr`
run's to overwrite. When you commit and the repo has a `baton.md`, it comes with the commit (the
`baton-check` hook enforces it).

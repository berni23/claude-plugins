---
name: check-cr
description: Read the code review on a PR (the latest, or the current branch's), triage every finding, and apply the fixes in this session. Use after /baton:cr or any other review lands on a PR.
argument-hint: [PR number or URL] [scope notes, e.g. "only the API findings"]
---

Read the review on a PR and **fix what is real**. Target: $ARGUMENTS

⚠️ **Do this yourself, in this session. Do NOT delegate to `code-reviewer` or any other subagent.**
That is the whole point of this skill: the session that produced the PR knows why each line is the
way it is, which is exactly the context a fresh agent lacks and the reviewer never had. A subagent
would re-derive intent from the diff and get it wrong in the direction of "apply everything".

`/baton:cr` is the other half of this pair and it *posts* a review. This one *answers* one.

## 1. Resolve the PR

With no argument, take the PR for the current branch; if the branch has none, take the most
recently created open PR that is not from Dependabot. A number or a URL both work.

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner                 # <owner>/<repo> below
gh pr view --json number,title,headRefName,baseRefName,url            # current branch's PR
gh pr list --limit 5 --json number,title,headRefName,author,updatedAt
```

State which PR you are working on in one line before touching anything.

**`/baton:cr` posts one merged review from two independent reviewers**: agent A (**Opus**, runtime,
state & failure lens) and agent B (**Sonnet**, spec, contract & coverage lens). Each finding is
tagged **`[A+B]`**, **`[A]`** or **`[B]`**, and the orchestrator verified it against the code before
posting. Tell the user this in one line when you name the PR.

- **`[A+B]`** — raised independently by both: the highest-confidence thing in front of you.
- **`[A]` / `[B]`** — one reviewer only, then re-checked by the orchestrator. Still reproduce it
  yourself before fixing or rejecting; a single-reviewer finding is the likeliest to be wrong.

A review not posted by `/baton:cr` (a human, another tool) has no tags; triage it the same way.
Findings the orchestrator **dropped** as false positives are not on the PR; `scratch.review`
records them and why. Don't resurrect one without new evidence.

## 2. Collect the whole review — all four surfaces

```bash
gh api repos/<owner>/<repo>/pulls/<n>/reviews --jq '.[] | "\(.id) \(.user.login) \(.state)\n\(.body)\n"'
gh api repos/<owner>/<repo>/pulls/<n>/comments --jq '.[] | "\(.id) \(.path):\(.line) \(.user.login)\n\(.body)\n"'
gh pr view <n> --comments
```

⚠️ **Reading only the inline comments loses findings.** A finding about something *absent* from the
diff cannot be anchored to a line, so it goes in the **review body** — and file-level notes land
there too. Read all three of those or you will silently fix the easy half.

**The fourth surface is `scratch.review` in the repo root — read it too.**

```bash
cat scratch.review 2>/dev/null || echo "(no scratch.review)"
```

`/baton:cr` writes there the half of a review that GitHub has no shape for: open questions,
cross-cutting concerns, verification gaps, and judgement calls the reviewer made on your behalf.
**None of it is on the PR.**

⚠️ **Check it is about *this* PR before acting on it.** It is git-ignored, local, and overwritten per
review round, so a stale one from an earlier PR is the expected failure. It names the PR and the
commit it reviewed at the top; if it names a different one, say so and ignore it. If it is absent,
say so in one line and carry on with the GitHub surfaces.

**If there is no review, stop and say so.** A green CI check is not a review. Offer `/baton:cr`
instead of inventing findings.

Skip threads that are already resolved or already answered, and note how many you skipped.

## 3. Triage before you fix — every finding, one at a time

**The reviewer saw the diff, not the plan.** Rate severity yourself; do not inherit the reviewer's.
For each finding, decide and say which of these it is:

- **Real** — reproduce it against the current working tree first. Name the concrete failure: inputs
  or state → wrong output, crash, data loss, orphaned process, secret leaked, user's environment
  touched.
- **Already fixed locally** — live in the PR diff, fixed in the tree. Not work; the branch needs
  pushing. Name the commit.
- **Wrong** — the reviewer missed a rule in the spec (`CLAUDE.md` / `AGENTS.md`), a test that already
  pins it, or the reason the code is shaped this way. Say why, on the thread. A rebuttal is a
  legitimate outcome and is better than a compliance fix.
- **Real but out of scope** — ⚠️ **file an issue**, do not park it in `baton.md`, which is rewritten
  every session by design. A duplicate issue is cheap; a lost finding is not. If an existing issue
  or a later roadmap item already covers it, link that instead.
- **A spec disagreement** — the code is right and the spec is wrong, or the reverse. Fix whichever
  is wrong in this change and say so; never leave them disagreeing.

Check for an existing test before calling anything unfixed (`grep -rn "<behaviour>"` over the test
files).

⚠️ **`scratch.review` entries triage differently: most are questions, not findings.** An open
question is answered, not fixed — and answering it may be the user's call, not yours. Sort each
into: **you can settle it from the tree** (do, and say what you found); **it needs the user** (ask,
in your report — do not guess and proceed); **it is real work** (⚠️ file an issue — `scratch.review`
evaporates, so it is never a finding's only home); or **it is a note recorded so nobody
re-litigates it** (acknowledge it and leave it alone).

## 4. Fix

Read the spec sections around each change — its hard requirements, the section the code implements,
and its rules for working on the repo. Most findings are about an interaction between the change
and one of those rules, not about the hunk.

**Every fix gets a regression test, and the test must be verified to fail before the fix.** Mutate
the fix away, watch the test fail, restore it. ⚠️ **Assert the mutation actually landed** — an edit
that silently matches nothing reads as evidence of coverage while proving nothing. A test written
after the fix and never seen red is a comment, not a test.

If three candidate fixes all feel awkward, the shape is probably wrong — say so instead of ranking
workarounds.

## 5. Verify

Run what CI runs, and do not report success on anything you have not run. Find the command in the
spec, `CONTRIBUTING.md`, the `Makefile` / `package.json` scripts, or `.github/workflows/`. If a fix
touches something a unit test cannot prove, also do a real run.

## 6. Answer on the PR

Reply on **each** thread you acted on, saying what changed — and on each you rejected, saying why.
A finding that is silently dropped reads as one that was missed.

```bash
gh api repos/<owner>/<repo>/pulls/<n>/comments/<comment-id>/replies -f body='...'
```

Findings that were in the review **body** have no thread: answer them together in one PR comment
(`gh pr comment <n> --body-file …`). Resolving threads is left to a human.

⚠️ **`scratch.review` items have no thread either.** Where one changed the code, say so in the commit
message or the PR comment; where it was a question, answer it in your report to the user (step 7).
Do not silently drop one because it had no comment id.

## 7. Report

Give the user: what you fixed (with the test that pins each), what you rejected and why, what you
filed as an issue, and what is still open — noting for each its tag (`[A+B]`, `[A]` or `[B]`).

**Cover the `scratch.review` items explicitly and separately** — they are the ones the user is most
likely to be waiting on, because several are questions addressed to them. For each: answered (with
the answer), fixed, filed, or still needs them. Then say whether the file is spent; offer to rewrite
it with whatever is genuinely still open, and leave it alone otherwise — it is the next `/baton:cr`
run's to overwrite. Then stop — **don't commit and don't push unless asked**; if you are asked and
the repo has a `baton.md`, it comes with the commit (the `baton-check` hook enforces it).

---
name: cr
description: Code-review a PR twice, independently, via two code-reviewer agents with different lenses writing to scratch files; verify every finding, then post one merged review to GitHub.
argument-hint: [PR number or URL | branch | paths | "uncommitted"] [extra scope notes]
allowed-tools: Agent, Bash
disable-model-invocation: true
---

Review the target **twice, independently**, verify every finding yourself, and post **one merged
review**. Delegate both reviews to this plugin's `code-reviewer` agent (Agent tool,
`subagent_type: "cross:code-reviewer"`) — do not review inline.

Target: $ARGUMENTS

A PR may be given as a number or a full URL — `gh` accepts either wherever this writes `<n>`. If
the target is empty, review the current branch's PR; with no PR, the branch against the default
branch plus any uncommitted work.

**Why twice:** one reviewer's findings are one reviewer's judgement. Two agents that never see each
other's output give a confidence signal — a finding both raise is very likely real; a finding only
one raises is the one worth a second look. **The value is in the misses one reviewer catches for the
other, and in your verification pass** — so the two get *different lenses*, not the same prompt
twice.

## 1. Resolve the target

```bash
gh repo view --json nameWithOwner,defaultBranchRef --jq '.nameWithOwner, .defaultBranchRef.name'
git branch --show-current
git status --short
git fetch origin && git rev-list --left-right --count origin/<branch>...<branch>
gh pr view <n> --json number,title,headRefName,baseRefName,headRefOid,url
```

Use the `nameWithOwner` from the first line as `<owner>/<repo>` everywhere below.

- ⚠️ **Local must equal origin** (`0 0`) when the target is a PR. Otherwise the agents review a tree
  the PR does not show, and inline comments anchor against the wrong lines. Push first or say so.
- **Uncommitted work is not in the PR.** Mention it; it is reviewed only if the target says so.
- With no PR, there is nothing to post to: run the same two reviews, skip §4's posting, and relay.

Make sure the scratch files stay out of git, without touching tracked files:

```bash
git check-ignore -q scratch.review || echo 'scratch.review*' >> "$(git rev-parse --git-path info/exclude)"
```

## 2. Launch both reviews, independently and in parallel

**Both `Agent` calls go in a single message** so they run concurrently.

**Models are fixed:** agent A runs on **Opus** (`model: "opus"`), agent B on **Sonnet**
(`model: "sonnet"`), the latest of each. Pass `model` explicitly on both, and never swap in another
model silently — if one is unavailable, stop and say so.

**Lenses:** both review the whole diff, but each leads with a different emphasis:
- **A — runtime, state & failure:** what happens when it runs — concurrency, process and resource
  lifecycle, state written to disk or a database and whether it survives a crash, error paths,
  retries and idempotency, security boundaries, anything that touches the user's environment.
- **B — spec, contract & coverage:** does the code do what the spec says (and the spec say what the
  code does); public surfaces (CLI, API, config, schemas) and their messages and docs; secrets and
  redaction; CHANGELOG; and whether the tests actually pin what the PR claims.

If the spec names its own hard requirements, put them in both prompts; tell each agent which lens
leads.

⚠️ **Neither agent posts anything to GitHub, and neither may be told the other exists.** No "a
second reviewer is also looking", no findings passed between them. Tell each agent explicitly:
**do not post a review or any comment; do not read existing reviews or comments on the PR** — judge
the diff and the tree. Nothing lands on the PR until both are done, which is what keeps them
independent.

Tell both: **use `gh` / `gh api` for GitHub, repo `<owner>/<repo>`.**

Each agent **verifies every finding against the tree**, confirms behavioural claims with a
throwaway test where it can (deleted afterwards, and never against the user's real environment),
and **does not commit, push or edit source**.

Each writes its whole review to its own file — **A to `scratch.review.a`, B to `scratch.review.b`**
(different files or they clobber each other), via a `cat > … <<'EOF'` heredoc, **overwriting**:

```
# Review <A|B> — PR #<n> @ <headRefOid short>

## Findings
### <n>. <one-line claim>
- where: <path>:<line>            (line in the NEW file, or "none" if not anchorable)
- severity: high | medium | low
- confirmed: test | read          (throwaway test, or by reading the code)
- failure: <inputs/state → wrong output, crash, data loss, leaked secret, user's environment touched>
- fix: <suggested shape, optional>

## Open questions
## Suggestions / notes
```

## 3. Reconcile and verify — the point of the exercise

Do not relay two reviews side by side. Sort every finding into tiers, matching on **the underlying
defect**, not wording — two agents describe one bug differently, and one line can host two bugs.

- **Both** — highest confidence. Note whether they agree on severity too.
- **One only** — ⚠️ **re-check each yourself** by reading the code: *real (the other missed it)*,
  *false positive* (drop it, and record why in `scratch.review`), or *unresolved*. This tier is where
  the value is.
- **Contradicted** — the agents disagree about the same code. Give your own reading.

Rate severity yourself; don't inherit either agent's.

## 4. Post one merged review

One GitHub review on the PR, from you, containing **only verified findings**. Each inline comment
starts with a tag saying who raised it — **`[A+B]`**, **`[A]`** or **`[B]`** — then the finding, the
failure, and how it was confirmed. Post it as a `COMMENT` review.

⚠️ **Posting with `gh api` has three traps, and the failure is a bare 422:**
- `POST /repos/<owner>/<repo>/pulls/<n>/reviews` needs the **full 40-char** `commit_id`
  (`headRefOid`).
- An inline comment only lands on a line **inside a diff hunk**, on the `RIGHT` side. Get hunk
  ranges first:
  `gh api repos/<owner>/<repo>/pulls/<n>/files --paginate --jq '.[] | .filename, (.patch // "" | split("\n")[] | select(startswith("@@")))'`
- `subject_type: "file"` is not accepted. A finding outside a hunk, or about something *absent* from
  the diff, goes in the **review body**, with the same tag.

Build the payload as a JSON file in a temp directory and post it with `gh api --input`, then verify
it landed:

```bash
gh api repos/<owner>/<repo>/pulls/<n>/reviews --jq '.[] | "\(.id) \(.state) \(.submitted_at)"'
gh api repos/<owner>/<repo>/pulls/<n>/comments --jq 'length'
```

⚠️ **An agent that stops without a completion record has written nothing** — check both scratch
files exist and name this PR and commit before reconciling.

## 5. `scratch.review` — the half GitHub has no shape for

Write **`scratch.review`** in the repo root from the two halves, then delete them
(`rm -f scratch.review.a scratch.review.b`). **Overwrite, never append** — one round per file.

- lead with the PR, the commit reviewed, the review id you posted, and a note that anchored findings
  are on the PR and not repeated;
- the tier table: every finding, who raised it, your verdict (including dropped false positives and
  why, so nobody re-litigates them);
- open questions, tiered the same way — a question both raised genuinely needs answering;
- suggestions, verification gaps ("spot-checked, not audited", "not run for real"), and judgement
  calls an agent made on the user's behalf.

⚠️ **`scratch.review` is git-ignored and local** — a handoff to `/cross:fix-cr`, never a durable
home. **Work to be done goes on an issue**, always.

## 6. Relay

Relay the reconciled result — **neither agent's report is shown to the user.** Keep the tiers; say
where the review was posted (URL + id) and what went into `scratch.review`. Lead with anything that
needs the user's decision before `/cross:fix-cr` can fix it.

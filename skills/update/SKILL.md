---
name: update
description: Update baton.md before committing — declare what is done and what to pick up next. Use before every git commit in a repo that has a baton.md, or when the baton-check hook blocks a commit.
argument-hint: [optional note about what changed this session]
---

You are at the handoff. `baton.md` (repo root) is the baton, and it is **pure state tracking**:
what this session finished, and what to work on next. Nothing else belongs in it. This is the last
moment you hold the context needed to write it.

**`/baton:pickup` is the other half of this** — it is what takes the baton at the start of the next
session, and knowing what it does with each section is how you write one worth reading. It treats
section 1 as **claims to verify** against `git log`, the tracker and the roadmap, takes section 2
as **the order to work in**, and checks section 3 **before starting anything**. Write for that
reader.

Session note from the user, if any: $ARGUMENTS

**No `baton.md` yet?** Create it with the three sections below. From then on the `baton-check` hook
holds every commit in this repo to it; a repo without the file is never blocked.

## What a work item is called here

The **spec** is the project's instructions file — `CLAUDE.md`, or `AGENTS.md` — plus any document
it points to as the design. Work lives in two places: the **tracker**, and the **roadmap** if the
spec has one (a milestone list, a `ROADMAP.md`).

**The tracker** is GitHub issues (through `gh`) unless the spec names another — Jira, Linear,
GitLab, … — in which case use that, through whatever CLI or MCP server this session has for it. If
the spec names a tracker you cannot reach, say so and ask; do not quietly fall back to GitHub. If the
project has no tracker at all (no GitHub remote, none named), the roadmap and the user are where
work goes.

Every entry names an item in one of those places, so its next move is a lookup:

- a tracker item → its id as the tracker writes it: `#N` on GitHub (next move: `gh issue view N`),
  `PROJ-123` on Jira, `ENG-42` on Linear (next move: open it with that tracker's tool);
- a roadmap item with no tracker item → `<milestone>: <the item, worded as in the roadmap>` (next
  move: read the roadmap and the spec section it implements), e.g. `M2: shell steps`.

An entry that names neither is a dead end. If a piece of work is in neither place, file it in the
tracker first, then name it; with no tracker, add it to the roadmap, or ask the user where it goes.

## The file has exactly three sections

1. **Last session** — items **done**, issues **filed**, items **re-scoped**.
2. **Do this next** — the ordered items to pick up, one short paragraph of *why this order* each.
3. **Waiting on the user** — decisions that are theirs, one line each, by issue or roadmap item.

If something you want to write does not fit one of those three, it does not go in this file. Route
it (see below).

## Do this

**1. Declare what is done.** If you worked an item to the end, write `<item id> — one line on
what changed` (`#12 — …`, `PROJ-123 — …`) or `<milestone>: <item> — one line`. That is the whole entry.

**Declare done only what you actually verified** — the project's checks passed (whatever its spec,
`CONTRIBUTING.md`, `Makefile` or CI runs), and for anything a unit test cannot prove, a real run.
Say which in the line if it was only unit-tested. `/baton:pickup` re-checks every entry against the
tree, so an unverified claim does not survive contact — it just costs the next session the time to
disprove it.

**When a whole milestone is done**, the durable record is the spec's status line and the CHANGELOG,
if the project keeps them, not this file — update those, and here just say `M2 — done`.

⚠️ **Do not write whether anything was merged, pushed, or is ahead of a remote.** That rots within
hours and sessions derail chasing the contradiction. `git log` and `gh pr list` answer it correctly
and always; this file cannot. **Naming a branch, a SHA, or a merge status is the failure mode, not
the handoff.** An item is done when the work is done.

⚠️ **The same rule catches things that feel like situation rather than state.** "PR #N is open",
"its review is unaddressed", "the branch is N ahead", "PROJ-123 is in review" — all derivable, so
all of them rot. `/baton:pickup` asks git, the code host and the tracker precisely so you do not have
to write them here. **If `git`, `gh` or the tracker can answer it, leave it out.**

**2. Set the next items in order.** Say *why this order* in a sentence or two — that is the part the
next session cannot re-derive from the roadmap or the tracker. If you got partway through
something, say where the seam is (which part works, which part is stubbed).

This is the section that does the most work: `/baton:pickup` **takes this order as given** rather
than re-deriving one. A roadmap lists the parts but not which one unblocks the next, which is tested
end to end, or which decision was made inside a tracker item — that is what this section is for. An
unordered list is not a handoff.

**3. Move every decision the user settled out of "waiting on the user"**, and record it where it
belongs: on the tracker item, or — for a design decision — in the spec. A decision living only in a
transcript gets re-litigated.

**4. Route everything else out of this file.** Nothing that is not a state declaration stays:

- work to be done — a latent bug, a deferred decision, a re-scope → **a tracker item**
  (`gh issue create` on GitHub), always, even if you also mention it here; with no tracker, the
  roadmap
- a design decision or an invariant a future change could innocently undo → **the spec**, in the
  section it belongs to
- a user-visible change → a line in **`CHANGELOG.md`** under *Unreleased*, if the project keeps one

⚠️ **Never let this file be a finding's only home.** It is rewritten every session, so anything
parked here evaporates. If you find yourself explaining a bug here, stop and file it.

**5. Delete, do not append.** Last session's "done" list is this session's history: cut it. Git
holds it. **If the file is longer than it was when you inherited it, you are appending where you
should be replacing.** Ceiling: about 60 lines. It should be a one-minute read.

**Cut section 1 first.** It is the only backward-looking section, and the one git already holds —
sections 2 and 3 are what the next session acts on. Cut anything that has since been written into
a tracker item or the spec too: a second copy can disagree with the first.

## Then

Stage `baton.md` with the rest of your work and commit; the `baton-check` hook lets the commit
through once the file is part of it. The next session opens with `/baton:pickup`, which reads what
you just wrote.

**If nothing moved** — a typo fix, a formatting pass, a dependency bump — do **not** manufacture a
cosmetic edit to satisfy the hook. Add `[no-baton]` to the commit command and say in your reply that
you skipped the handoff and why. A padded brief stops being read, which is the same failure as a
stale one.

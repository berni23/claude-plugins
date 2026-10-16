# Changelog

## Unreleased

- `/baton:pickup` switches to a branch named after the item before its first edit, never working
  on the default branch; uncommitted work left there moves with it.

## 0.2.0

- `/baton:pickup` and `/baton:update` work with any tracker: GitHub issues by default, or the one
  your `CLAUDE.md` names (Jira, Linear, GitLab…), through the session's CLI or MCP server for it.
  With no tracker, the spec's roadmap stands in.

## 0.1.0

- First release: `/baton:pickup`, `/baton:update`, `/baton:cr`, `/baton:check-cr`, the
  `code-reviewer` agent and the `baton-check` commit hook.

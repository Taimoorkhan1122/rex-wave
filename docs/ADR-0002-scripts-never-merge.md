# ADR-0002: Scripts never merge, push, PR, or deploy

Date: 2026-11-19 · Status: Accepted · Since: first commit `bf4433a`

## Context

rex-wave drives autonomous agents. Any script path that mutates shared
history (merge, push, PR, deploy) could do so on wrong information — a
stale verdict, a fix applied after review, a half-verified branch — with
no human in the loop.

## Decision

No script contains or may ever contain `git merge`, `git push`, PR
creation, or deploy commands. Merging is always the user's manual step
(SKILL step 11: "Stop at merge-ready. The user reviews branches and
merges them."). Teardown (`finish.sh`) only removes verified-merged work.

## Consequences

- The automation ceiling is fixed: everything up to merge-ready is
  automatic, the merge itself is human-gated.
- Agents instructed by SKILL.md are also told never to merge/push/deploy —
  the rule applies to both scripts and agents.
- Any future feature that seems to need a script-side merge is a design
  smell; re-examine the workflow instead.

## Verification

- e2e 13: static grep over `scripts/` for merge/push/PR/deploy commands
  (C1 — the one claim tested statically, because absence claims cannot
  be executed).
- e2e 11: `finish.sh` refuses unmerged teardown.

# ADR-0007: Completion pings via background watcher, not event hooks

Date: 2026-11-19 · Status: Accepted · Since: `5c6954b`

## Context

Parallel builders finish at unpredictable times; the invoking block had
no way to learn a task was done except polling `status.sh` or watching
`watch-review.sh` open reviewer tabs.

## Options explored

1. **rex Lua event hooks** — `rex.on("com.superlogical.terminal.child_exited")`
   fires reliably (verified live, payload carries `block_id`), but the
   event means "a terminal's program exited". Builders are long-lived
   interactive agents; their "done" is not process exit. Wrong trigger.
2. **Terminal-write injection** — `rex.block.call(id, "write", …)` into
   the invoker's block silently no-ops (verified: capture showed nothing).
   Unreliable channel.
3. **OSC 9 desktop notification** — a scripted write of the escape into a
   rex block never produced a `desktop_notification` event (listened
   300 s, nothing fired). Best-effort only.
4. **Background shell watcher printing to its own stdout** — reliable,
   zero new primitives: a background job's stdout lands in the block that
   started it.

## Decision

`scripts/watch-done.sh <run-dir>` — run it in the background from the
block that wants pings. It polls each task for the exact condition
`watch-review.sh` uses (`REPORT-AGENT.md` exists and HEAD past
`BASE_SHA`), and per task prints a `T1 is reviewable (HEAD …)` line plus
a bell and an OSC 9 escape (best-effort). Exits 0 when all tasks are
reviewable; `MAX_WAIT` (default 4 h) gives up naming stragglers. The
inter-poll nap is capped at the remaining wait so a short `MAX_WAIT`
still gets a final scan.

## Consequences

- Three channels per completion: scrollback (what an agent reads), bell,
  desktop notification (if the terminal honors OSC 9 — unverified for rex
  app clients).
- Same completion condition as the review watcher, so "pinged" and
  "reviewable" never disagree.
- Polling every 30 s is the cost of reliability; rex event hooks remain
  an option only if builders become batch jobs (see PLANS.md open ideas).

## Verification

- Live fixture: mid-wait commit + report → ping line with correct HEAD;
  straggler named at give-up; both-done → summary, exit 0.
- selfcheck 24 asserts, e2e 44 asserts still green after the change.

# Progress

Work sessions, milestones, and verification history. All dates 2026-11-19
(the project was built in one day; timestamps are +0500).

## Session 1 — build the 0.1 line (16:26 → ~17:25)

One feature per commit, `selfcheck` added alongside stateful scripts.

| Commit | Milestone |
|---|---|
| `bf4433a` | Wave setup + builder launch core (init-wave, launch, lib.sh) |
| `ea79a01` | Reviewer agents, round 1 and round 2 |
| `76adf19` | Background watchers for review rounds |
| `5abf234` | Fix delivery to an idle builder (`send-fix.sh`) |
| `dbec6a0` | Status + tab cleanup (`status.sh`, `close-idle.sh`) |
| `39cc96f` | selfcheck for lib.sh state logic |
| `fece418` | Wave manifest + agent templates |
| `a842385` | SKILL.md packaging |
| `18c19b0` | `finish.sh` — merge-verified teardown |
| `ab0afff` | Shared `dirty_of`; close-idle never closes dirty builders |

## Session 2 — packaging, seam, test pyramid (17:10 → 17:25)

| Commit | Milestone |
|---|---|
| `651d59d` | Repo flattened — skill at root |
| `fdd6253` | README + MIT license |
| `e148647` | CI: shellcheck + selfcheck on push/PR |
| `e1d1727` | Agent-agnostic builder/reviewer CLIs (ADR-0005) |
| `63c17f6` | Claims matrix C1–C20 + hermetic e2e (44 asserts) (ADR-0006) |
| `a5b634a` | e2e CI fix: export REX_SESSION + git identity |
| `81f2b6a` | e2e CI fix: `/bin/sleep` in poll loops (stubbed sleep spun loops) |

CI: run 44527487426 green (3 consecutive stable local e2e runs before
push).

## Session 3 — release hygiene + completion pings (afternoon)

| Item | Milestone |
|---|---|
| Git identity archaeology | no user.name/email configured anywhere — git auto-derived "Geeks Of Kolachi" from macOS RealName + hostname |
| History rewrite | `git filter-branch --env-filter` rewrote all commits to `taimoorkhan112 <khant8k83@gmail.com>`; force-push; all 4 commits verified on GitHub; CI re-run 44528195995 green on rewritten history |
| `5c6954b` | `watch-done.sh` — completion pings to the invoker (ADR-0007); live fixture verified; selfcheck + e2e still green |
| Release **v0.1.1** | annotated tag on `5c6954b` + GitHub release with notes; CI green on the tagged commit |
| `docs/` | this directory: plans, ADRs, features, progress |

## Rex CLI / Lua API knowledge bank

Learned during the notification investigation; keep for future work.

- Terminal block events (from `rex block inspect <id>`) are prefixed:
  `com.superlogical.terminal.<name>` — e.g. `child_exited` (fires with
  `block_id`+`session_id` payload), `desktop_notification`,
  `program_status_changed`, `title_changed`. Bare names like
  `terminal.exit` never fire. Connection-level events use underscored
  bare names (`block_closed`).
- `rex do -b <block-id>` sets `rex.block_id` in the script; absent `-b`
  it is nil. `print()` from `rex.every`/`rex.on` callbacks reaches the
  invoking CLI's stdout — the reliable "ping" channel.
- `rex.block.call(id, "write", {data=…})` into an owned/idle block
  silently no-ops in the tested state; don't build on it.
- OSC 9 written into a rex block did not surface as a
  `desktop_notification` event within 300 s of listening — treat OSC
  notification delivery as unverified for rex app clients.

## Current state

- `main` = `5c6954b`, tagged `v0.1.1`, pushed, CI green.
- Suites: selfcheck 24 asserts, e2e 44 asserts, both green.
- Open ideas tracked in docs/PLANS.md (deferred list).

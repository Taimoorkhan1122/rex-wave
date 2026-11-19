# ADR-0003: Verdicts parsed from review output, not guessed

Date: 2026-11-19 · Status: Accepted · Since: `ea79a01`

## Context

Review quality gates must be deterministic. A watcher that "guesses"
approval from prose ("looks good", "LGTM") would let half-reviewed work
through, and flapping judgments would break the fix-round loop.

## Decision

The last `VERDICT: APPROVE` or `VERDICT: CHANGES REQUESTED` line in the
reviewer's output is the verdict (`verdict_of` in `lib.sh`). Review
templates require the reviewer to end with exactly that marker. The
review state is `-` (none), `running` (started, no `REVIEW EXIT` marker
yet), or the verdict — and a stale check (`status.sh` `stale: yes`) flags
new commits landing after the reviewed HEAD so an old verdict can't cover
the branch tip.

## Consequences

- Watchers act on verdicts mechanically; no prose parsing.
- A reviewer that never prints the marker leaves the task in `running`
  forever — visible in `status.sh`, resolvable by a re-review.
- Merging on a stale verdict is the user's call; `stale` makes the risk
  visible at merge time.

## Verification

- e2e 7 (verdict parse + review state machine), e2e 8 (stale detection).
- CLAIMS C8–C10.

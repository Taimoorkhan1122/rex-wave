# rex-wave docs

Project record: plans, decisions, features, progress. Everything here is
retrospective truth as of its date; forward-looking ideas live in the
Open list.

| File | What it is |
|---|---|
| [PLANS.md](PLANS.md) | Plans per release line — what was intended, what shipped |
| [ADR-0001..0007](#adrs) | Accepted architecture decisions (see index below) |
| [FEATURES.md](FEATURES.md) | Feature inventory: shipped, how verified, since which commit |
| [PROGRESS.md](PROGRESS.md) | Timeline of work sessions, milestones, CI history |

## ADR index

| ADR | Decision | Status |
|---|---|---|
| [0001](ADR-0001-worktree-isolation.md) | One git worktree per task | Accepted |
| [0002](ADR-0002-scripts-never-merge.md) | Scripts never merge, push, PR, or deploy | Accepted |
| [0003](ADR-0003-verdict-parse.md) | Verdicts parsed from review output, not guessed | Accepted |
| [0004](ADR-0004-fail-safe-refusals.md) | Fail-safe refusals over retries everywhere | Accepted |
| [0005](ADR-0005-agent-agnostic-clis.md) | Agent-agnostic CLI profiles, no model allowlists | Accepted |
| [0006](ADR-0006-e2e-hermetic.md) | Hermetic stubbed e2e, claims matrix | Accepted |
| [0007](ADR-0007-completion-notification.md) | Completion pings via background watcher, not event hooks | Accepted |

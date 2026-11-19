# AGENTS.md — rex-wave

Rules for AI agents (and humans) working in this repo. Read before your first edit.

## What this repo is

`rex-wave` is a pure-sh orchestration skill: scripts fan independent coding tasks out
to parallel agents in [Rex](https://superlogical.rex) tabs — one git worktree and one
visible builder tab per task, an automated reviewer per finished builder, one fix
round, teardown after the user merges. Nothing here merges, pushes, or deploys.

Runtime deps: POSIX `sh`, `git`, `jq`, the `rex` CLI. No frameworks, no build step.

## Non-negotiables

1. **Scripts never merge, push, open a PR, or deploy** — ADR-0002. The user does.
   Static proof: e2e scenario 13 greps `scripts/*.sh` for those verbs.
2. **Fail-safe refusals over retries** — ADR-0004. Every script refuses to overwrite,
   double-launch, double-send, or close a working agent. Teardown only removes
   verified-merged work. New scripts must follow this shape.
3. **Verdicts are parsed, never guessed** — ADR-0003. Last `VERDICT:` line of a review
   file; trailing spaces stripped; absent → empty. State logic changes go through
   `scripts/selfcheck.sh` first.
4. **One git worktree per task, under `WT_ROOT`** — ADR-0001. Never inside the main
   checkout. `REPORT-AGENT.md` is never committed.
5. **Agent-agnostic CLI profiles** — ADR-0005. Adding an agent is one `case` branch
   each in `builder_run`/`reviewer_run` in `scripts/lib.sh`. No hardcoded model
   allowlists beyond the allowlist of CLI names.
6. **Docs move with code** — `docs-with-change` skill rule: every behavior change
   updates `SKILL.md` + `README.md` + `docs/CLAIMS.md` in the same commit, stale-name
   grep clean, before push. `docs/CLAIMS.md` is the claims↔tests contract: no claim
   without a test, no test without a claim.
7. **POSIX sh, no bashisms** — target `/bin/sh` (dash-compatible). `set -u` in every
   script. Case statements must avoid unquoted `;;`-adjacent pipelines in contexts
   where hooks rewrite commands.

## Verification gates (run before every commit)

```sh
sh scripts/selfcheck.sh   # state-machine asserts; no rex needed
sh e2e/run.sh             # hermetic behavioral suite; stub rex + agent CLIs
```

Both must exit 0. A test that documents a claim must keep passing; never narrow a
test to make code fit — fix the code or update the claim honestly.

## Layout

```
SKILL.md            agent-facing instructions (the skill contract)
README.md           human-facing overview, install, claims summary
scripts/*.sh        the orchestration runtime (POSIX sh)
templates/*.md,.env brief/fix/manifest stubs (Write-tool filled, TODO-gated)
e2e/                hermetic behavioral suite + stubs (rex, agent CLIs, sleep)
docs/               CLAIMS.md (contract map), ADR-0001..0007, PLANS/FEATURES/PROGRESS
```

## State layout

Run state lives in `~/.local/state/rex-wave/<LABEL>` (override `REX_WAVE_STATE_DIR`),
durable across reboots. Per task: `wave.env`, `<task>.md` (brief), `<task>.builder.json`,
`<task>.reviewer.json`, `<task>.review.md`, `<task>.reviewed-head`, `<task>.fix.md`,
`<task>.fixprev`, `<task>.reviewer2.json`, `*.closed` markers. Watcher done condition:
`REPORT-AGENT.md` present + HEAD past `BASE_SHA`.

## Where decisions are recorded

Architecture decisions → `docs/ADR-00XX-*.md` (one per accepted decision, indexed in
`docs/README.md`). Feature inventory → `docs/FEATURES.md`. Session timeline →
`docs/PROGRESS.md`. If a change reverses an ADR, rewrite the ADR with a superseding
note — never silently contradict it.

## Gotchas agents hit

- The e2e escape-sequence greps must match `]9;rex-wave` — a literal ESC byte precedes
  `]9`, so patterns like `033]9` never match.
- `watch.sh`'s nap is capped at remaining `MAX_WAIT` so short waits still get a final scan.
- `status.sh` `stale=yes` means the reviewed HEAD no longer covers the branch tip; merge
  only when `stale` is `-`.
- Briefs and fix files are written with the Write tool, not heredocs — some agent hosts
  block Bash commands containing test-runner names.

# ADR-0005: Agent-agnostic CLI profiles, no model allowlists

Date: 2026-11-19 · Status: Accepted · Since: `e1d1727`

## Context

Builders were hard-coded to `commandcode` and reviewers to `opencode`,
which locked users into two CLIs. The first fix attempt (per-CLI model
allowlists in the manifest) was wrong: model ids change per CLI release,
and validating them duplicates each vendor's own job.

## Decision

Two manifest vars — `BUILDER_AGENT` (default `commandcode`) and
`REVIEW_AGENT` (default `opencode`) — select the CLI per wave. `lib.sh`
holds profiles (`builder_run`, `reviewer_run`) carrying each CLI's
invocation flags for commandcode, `claude` (Claude Code), `codex`
(Codex CLI), and `opencode`. Validation is: known agent name, binary on
PATH, required model id present. Model allowlists are removed; "models
are whatever the chosen CLI accepts." All scripts exec through the
profiles; defaults unchanged, so old manifests work as-is.

## Consequences

- One seam (`lib.sh` profiles) to touch when adding a CLI; run-agent,
  both reviewers, and e2e dispatch are untouched.
- A missing binary fails fast at init, not mid-wave.
- A CLI that changes its flags needs a profile update, nothing else.

## Verification

- e2e 1 (defaults), 3 (unknown agent refused), 4/5 (all four profiles
  dispatch correct flags; unknown builder dies).
- CLAIMS C2, C5, C7.

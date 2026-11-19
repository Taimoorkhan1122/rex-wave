# ADR-0006: Hermetic stubbed e2e with claims matrix

Date: 2026-11-19 · Status: Accepted · Since: `63c17f6`

## Context

README and SKILL.md made strong behavioral claims (refusals, verdict
gates, teardown safety) with nothing executing them. Testing against the
real `rex` CLI would be flaky, need sessions, and break in CI.

## Decision

- `docs/CLAIMS.md` maps every README/SKILL/script-contract claim (C1–C20)
  to the test backing it; numbering aligns with e2e scenarios 1–13.
- `e2e/run.sh` — 44 behavioral asserts, hermetic: a stub `rex` on PATH
  records tab/block operations into a state dir, one agent stub is
  symlinked as `commandcode`/`claude`/`codex`/`opencode`, sleep is stubbed
  for instant loops. POSIX sh + git + jq only, no network, no new deps.
- `selfcheck.sh` — 24 asserts on `lib.sh` state logic.
- Static grep is used only for C1 (scripts never merge/push — an absence
  claim no execution can prove).
- CI runs shellcheck + selfcheck + e2e on push/PR (`.github/workflows/ci.yml`).

## Gotchas learned (must keep)

- Poll loops inside e2e must call `/bin/sleep` explicitly, never bare
  `sleep` — the stubbed sleep makes loops spin instantly and race.
- CI runners need `REX_SESSION` and a git identity exported by the e2e
  harness itself (`a5b634a`).

## Consequences

- Every docs claim is executed by CI; a docs change without a backing
  test is a failed claim.
- The stub `rex` is a contract: a new rex flag used by scripts must be
  added to the stub or e2e breaks (that is the point).

## Verification

- CI run 44527487426 and the re-run on rewritten history 44528195995 green.
- CLAIMS.md is the matrix; `sh e2e/run.sh` prints 44 `ok:` lines.

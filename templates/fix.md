# Fix round 1

Read this file, apply only the fixes below, then stop. Add no scope.

## Findings to fix

TODO: paste each 🔴 / 🟡 / ❓ line from the review, with its file:line. Leave out APPROVE-level notes.

## Rules

- Fix each finding at its root cause. Keep the change minimal.
- Re-run the verification from your first pass (typecheck and memory-capped tests).
- Commit on this branch with the same Co-Authored-By trailer as your earlier commits.
- Last, after the commit: append "## Fix round 1" to REPORT-AGENT.md. Do not commit it. For each finding: fixed or not fixed (and why), file:line, verification result.

---
name: rex-wave
description: Run a multi-agent wave in Rex. One git worktree and one visible commandcode builder tab per task, an opencode review tab per finished builder, and an optional fix round with a second review. Use when the user says "run a wave", "rex wave", "parallel agents in rex", "fan out builders", "build these tasks in parallel with reviews", or asks for several independent tasks built in Rex tabs.
---

# rex-wave

Fan independent tasks out to coding agents. Each gets its own git worktree and a visible Rex tab. Each finished builder gets a reviewer tab. One fix round, then a round-2 review. The user merges. Nothing here merges, pushes or deploys.

Scripts live in the `scripts/` directory next to this SKILL.md — use their absolute paths, whatever the install location is. Rex tabs run them outside your shell.
Shorthand below: `S` = that scripts directory, `RUN` = `$TMPDIR/rex-wave-<label>`.

## When to use

- Two or more tasks with disjoint file ownership, or ownership you can write into each brief.
- The user wants to watch the agents in Rex tabs.
- Not for one small change. Not outside Rex (`$REX_SESSION` must be set). Not for work that needs a live deploy or a remote DB write.

## Setup (once per wave)

1. Check you are in Rex: `echo "$REX_SESSION"`. If empty, stop and tell the user.
2. Confirm with the user: task list, base branch, builder model (allowlist in Hard rules), and `--yolo` approval for this wave.
3. Name the session: `rex session rename "$REX_SESSION" <label>` (two to four words, e.g. `wave-login-fixes`).
4. Pick tasks, e.g. from `tsk list --json`. One per independent chunk. Note which files each owns. Overlaps go into each brief as "owned by other tasks".
5. Write the manifest with the Write tool to `$TMPDIR/rex-wave-<label>.env`, from `templates/wave.env.example`. Set `LABEL`, `REPO`, `BASE`, `TASKS`, models, and the check and test commands.
6. `sh S/init-wave.sh <manifest>`. Creates `RUN` with `wave.env`, a rendered `common.md`, brief stubs, and one worktree per task on branch `fix/<task>` from `BASE`. It refuses to overwrite anything.
7. Write each brief to `RUN/<task>.md` from `templates/brief.md`, with the Write tool. Replace every `TODO`. Set the goal, finding IDs, owned files, and other tasks' files. `launch.sh` refuses while a TODO remains.

## Steps

8. Launch each builder: `sh S/launch.sh RUN <task>`. It prints the tab number. Tell the user the tab numbers. Rex Remote Control is off by default, so you cannot switch their view.
9. Start the review watcher in the background (Bash `run_in_background`): `sh S/watch-review.sh RUN`. It opens a reviewer tab per task once `REPORT-AGENT.md` exists and HEAD is past `BASE_SHA`. It exits when every task has a reviewer tab, or gives up after `MAX_WAIT` seconds (default 4h) naming the tasks whose builder never finished.
10. Check progress with `sh S/status.sh RUN`. Report each verdict to the user as it lands.
11. Stop at merge-ready. The user reviews branches `fix/<task>` and merges them.

## Fix round (only on CHANGES REQUESTED)

12. Write `RUN/<task>.fix.md` from `templates/fix.md`. Paste only the findings to fix, each with file:line. Replace every TODO.
13. `sh S/send-fix.sh RUN <task>`. It checks the builder is idle at its prompt, types "read <fix.md> and apply", presses Enter, and records the pre-fix HEAD. It refuses if the builder is busy.
14. Start `sh S/watch-fix.sh RUN` in the background. It opens a round-2 reviewer once the builder has committed and appended `## Fix round 1`. Round 2 marks each round-1 finding fixed, not fixed or partial, then looks for new problems.
15. One fix round per task. After round 2, decide with the user. Do not start a round 3.

## Status and cleanup

16. `sh S/status.sh RUN`: commits since base, dirty files (REPORT-AGENT.md excluded), report, fix, review and round-2 state, plus `stale` — `yes` means new commits landed after the reviewed HEAD, so the latest verdict no longer covers the branch tip. Merge only when `stale` is `-`.
17. `sh S/close-idle.sh RUN [--dry-run]`: closes finished reviewer tabs, and builder tabs whose latest verdict is APPROVE with no fix pending, no stale review, and no uncommitted changes. A closed builder can resume with `commandcode -r <task>`.
18. Summarize for the user: per task, branch, commit count, verdict, and what needs their decision.

## Teardown (after the user merged)

19. Once the user says all `fix/<task>` branches are merged: `sh S/finish.sh RUN --dry-run` to preview, then `sh S/finish.sh RUN`. Per task it requires the branch merged into `BASE` and a clean worktree, then removes the worktree, deletes the branch (`-d`, so only merged branches die), closes the builder tab, and finally removes the run dir. Any BLOCKED task aborts the whole teardown before anything is removed — fix or decide with the user, then re-run. `--keep-run` keeps the briefs and reviews for reference.

## Gotchas

- Changed anything in `lib.sh` or the verdict/state logic? Run `sh S/selfcheck.sh` first — it checks verdict parsing, review states, and json reads without needing rex.
- `commandcode -p` (headless) prints nothing until exit and silently refuses edits without a permission mode. Use the interactive form with `-t --yolo`, as `run-agent.sh` does.
- The process name is `command-code`, not `commandcode`. Use `pgrep -f command-code`.
- A PreToolUse hook blocks any Bash command whose text contains vitest or jest without a memory guard. Write briefs and fix files with the Write tool, not heredocs. Keep the guard in `TEST_CMD`.
- The rtk hook rewrites some Bash calls (cat becomes `rtk read`, git becomes `rtk git`). Auto mode then asks you to re-issue the call verbatim. Avoid `cat` pipelines and `;;` in case statements inside Bash calls.
- Rex Remote Control is off by default. You cannot switch the user's view. Give them tab numbers.
- Overlapping files (e.g. `supabase/config.toml`) across tasks: each brief names the entries its task owns, and the others must not touch them.
- The watcher's done signal is `REPORT-AGENT.md` plus HEAD past base. Builders must write the report after their commit, or a reviewer reviews a stale branch.
- Verdicts come from the last `VERDICT:` line of a review. Read the review file before acting on a verdict.
- Window IDs come from `rex window new --json` (`.window_id`, `.block_ids[0]`). If a launch errors, run `rex window ls -s "$REX_SESSION"` before retrying, since the tab may already exist.
- Session-scoped commands need `-s "$REX_SESSION"`. The scripts read it from `wave.env`, which `init-wave.sh` writes.

## Hard rules

- Never merge, push, open a PR or deploy. The user does that.
- No deploy, remote DB write or secret change by any agent. Under `--yolo` this is prompt-only. Say so to the user at setup.
- Builders commit only on `fix/<task>`. `REPORT-AGENT.md` is never committed.
- Worktrees go under `WT_ROOT`, never inside the main checkout.
- Never put credentials or personal data in a brief, a report or a commit.
- Never close a builder that is still working. `close-idle.sh` closes only finished ones.
- Builder models: `deepseek/deepseek-v4.1-flash`, `z-ai/glm-5.3-flash`. Reviewer: `opencode/deepseek-v4.1-flash-free` via `cavecrew-reviewer`.

# Plans

Plans per release line. Status vocabulary: shipped / partial / dropped.

## Plan: 0.1 line — parallel agent waves (v0.1.1, shipped)

Goal: fan independent coding tasks to parallel AI agents in Rex, one git
worktree each, with an automated review gate, one fix round, and a
human-only merge.

Intended scope (from the first session, 2026-11-19):

1. Manifest → init: worktrees, branches, brief stubs — shipped
   (`init-wave.sh`, commit `bf4433a`).
2. Parallel builder launch into visible Rex tabs — shipped (`launch.sh`).
3. Round-1 and round-2 reviewers as their own agent tabs — shipped
   (`review-agent.sh`, `review2-agent.sh`, `ea79a01`).
4. Background watchers opening reviewer tabs as builders finish — shipped
   (`watch-review.sh`, `watch-fix.sh`, `76adf19`).
5. Fix delivery to an idle builder — shipped (`send-fix.sh`, `5abf234`).
6. Status + tab cleanup — shipped (`status.sh`, `close-idle.sh`).
7. Merge-verified teardown — shipped (`finish.sh`, `18c19b0`).
8. Skill packaging (`SKILL.md`) — shipped (`a842385`).
9. Agent-agnostic CLIs, one seam — shipped (`e1d1727`, ADR-0005).
10. Claim-to-test coverage + hermetic e2e — shipped (`63c17f6`, ADR-0006).
11. Automatic completion notification for the invoker — shipped
    (`watch-done.sh`, `5c6954b`, ADR-0007).

Dropped along the way:

- Model allowlists in the manifest — removed in `e1d1727`; agent name +
  CLI-on-PATH + required model id was the durable contract (ADR-0005).
- Nested repo layout `rex-wave/` inside `rex-wave-dev/` — flattened in
  `651d59d`; scripts were already path-independent.

Deferred (open ideas, not committed):

- Real desktop-notification delivery (OSC 9 through rex app clients)
  — probe showed rex terminal blocks do not surface a
  `desktop_notification` event from scripted writes; stdout + bell is the
  verified channel. Revisit if rex adds a notification API.
- Event-driven completion detection via `rex.on
  ("com.superlogical.terminal.child_exited")` — the event fires, but
  builders are long-lived interactive agents, not exiting commands, so
  file/HEAD polling is the correct trigger. Revisit only if builders
  become batch jobs.
- Multi-round fix loops (round 3+). Round-2 is the ceiling by design;
  waves are cheap, re-wave instead.

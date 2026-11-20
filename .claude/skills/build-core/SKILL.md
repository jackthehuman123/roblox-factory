---
name: build-core
description: Use when the user types /build-core <slug> to build a playtestable core game from a brief marked Decision go, or to apply their playtest feedback to that game.
---

# Build the core

Stage budget: 300k tokens (docs/BUDGETS.md). After each agent finishes, run `lune run tools/budget_add games/<slug>/budget.md build-core <agent> <model> <tokens>` with the tokens it reported; on a WARN line, tell the user before dispatching more.

Input: slug (ask if missing). Brief: `ideas/<slug>/brief.md`. Starting point: `templates/game/` (copied by `tools/new-game.sh`).

## Steps

1. **Gate.** The brief must contain `Decision: go`. If not, stop and tell the user which decision it has. If `.factory-busy` exists, stop: "factory busy (<content of .factory-busy>) — delete .factory-busy if no run is going". Otherwise write `.factory-busy` in the repo root as `build-core <ISO time>`; remove it at the end (after step 13), on every stop, and before any wait on the user (step 10); write it again, same content, when they answers.
2. **Read the brief once,** including every `Decided:` line in its feedback log. Those lines bind every later step.
3. **Create the game** (first round only): run `tools/new-game.sh <slug>`. It must print `created games/<slug>`; otherwise relay its one error and stop.
4. **Set config.** Write the brief's numbers (players, round timings, etc.) into `games/<slug>/src/server/config.luau` — plain values only.
5. **World.** Send `world-builder` one call with the slug and the graybox needs from the brief (spaces, sizes, what each area is for).
6. **Logic.** Group the acceptance checks by the files they touch. Send `builder` one call per group (not per check), each with the slug, the brief path and the exact check lines.
7. **Kit.** Never edit `kit/`. If an agent reports the kit lacks something, write the proposed kit change to the user and continue without it.
8. **Check.** Run `tools/check.sh`. If it does not print `OK`, send the failing lines to the agent that owns those files; at most two rounds, then tell the user.
9. **Review.** Send `reviewer` the diff only when its description applies (remotes, player data, client trust, `kit/`, or over ~150 lines). Fix must-fix items via the owning agent, then re-run check.
10. **Studio.** Start `rojo serve games/<slug>/default.project.json` in the background and ask the user to connect the Studio plugin; wait for their OK. Then send `studio-tester` the slug and the `[playtest]` check lines. Record pass/fail per check. Log its tokens under stage `playtest`, not `build-core`: `lune run tools/budget_add games/<slug>/budget.md playtest studio-tester sonnet <tokens>`.
11. **Playtest sheet.** Fill `games/<slug>/playtest.md`: how to run, what to try, what to watch, questions for players, and the `studio-tester` results in the Results table.
12. **State.** Update `docs/STATE.md` (≤ 40 lines): game built, checks passing, known issues.
13. **Hand off.** Tell the user it's ready to playtest: playtest.md path, failed checks (if any), kit proposals (if any).

## Feedback rounds

When the user gives feedback on a built game:

1. Add `### Round <n> — <YYYY-MM-DD>` to the brief's feedback log with `You said:` (verbatim) and `Decided:` (what changes).
2. Send only that delta to the owning agent(s) — not the whole brief again.
3. Repeat steps 8–13, writing `.factory-busy` first as `build-core <ISO time>` (stop with the busy message if it exists), removing it at the end, on any stop and before any wait on the user.

## Rules

- Worlds change only via `games/<slug>/src/server/graybox.luau`.
- Shell commands one at a time.
- `tools/check.sh` must print `OK` before saying done.

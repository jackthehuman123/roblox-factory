---
name: log-run
description: Use when the user types /log-run <slug> after a playtest, to record a pipeline run's cost, verdict and failures and turn each failure into an agent practice task.
---

# Log a run

Stage budget: 30k tokens (docs/BUDGETS.md). After each agent finishes, run `lune run tools/budget_add games/<slug>/budget.md log-run <agent> <model> <tokens>` with the tokens it reported; on a WARN line, tell the user before dispatching more.

Input: slug (ask if missing). Template: `docs/templates/run-log.md`. Training format: `docs/training/README.md`.

## Steps

1. **Ask the user,** in one message:
   - `/cost` for the main session in each stage: pitch, build-core, playtest, and any of dress, coordination, fixes that were used.
   - Their playtest verdict: keep, change or kill.
   - How many sessions the run used, and the cost of each failure if they know it (else leave blank).
   - Anything that went wrong that you may not have seen.
2. **Gather facts** from the repo, not memory: `ideas/<slug>/brief.md` (idea, feedback rounds), `games/<slug>/playtest.md` (results), `ideas/<slug>/budget.md` and `games/<slug>/budget.md` (tokens used per stage; sum each stage key's rows for the cost table's "used": pitch, build-core, playtest, log-run, dress, stock, coordination, fixes), `git log --oneline` for the run.
3. **Count rework rounds** = feedback rounds in the brief added after `/build-core` first ran (pitch "change" rounds don't count).
4. **List failures.** One row per failure, each attributed to exactly one agent (council member, crew agent, or a skill). A failure is anything that needed the user to correct it, a check that failed, or a rework round.
5. **Write the run log.** Copy `docs/templates/run-log.md` to `docs/runs/<YYYY-MM-DD>-<slug>.md` and fill every field: idea, slug, sessions used, verdict, cost table (one row per stage key, as in the template; budgets from `docs/BUDGETS.md`), rework rounds, failures table.
6. **Write practice tasks.** For each failure, append to `docs/training/<agent>.md` (create it with a `# Training — <agent>` heading if missing):
   - Next id `T<n>` in that file; never renumber.
   - Exactly the README format: `## T<n> — <short name> (run: <date>-<slug>)`, `Input:`, `Failure seen:`, `Pass when:`.
   - `Pass when` is a checkable condition, not a wish.
   - Put the id in the run log's failures table.
7. **One change.** End the run log's `## Before the next run` with the single change most likely to remove the costliest failure.
8. **State.** Update `docs/STATE.md` (≤ 40 lines) with the run and its verdict.
9. **Check.** Run `tools/check.sh`; it must print `OK`.
10. **Report** to the user in at most 5 lines: verdict, total cost, failure count by agent, the one change.

## Rules

- Never invent costs or verdicts; leave a field blank and say so if the user has not given it.
- Agents and skills stay game-agnostic: practice tasks may name the run, but fixes to agents must not mention a specific game.

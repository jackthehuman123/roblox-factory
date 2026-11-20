---
name: pitch
description: Use when the user types /pitch or gives a game idea paragraph to turn into a council brief. Runs the three council agents, writes ideas/<slug>/brief.md, and records their go / change / no-go.
---

# Pitch an idea

Stage budget: 60k tokens (docs/BUDGETS.md). After each agent finishes, run `lune run tools/budget_add ideas/<slug>/budget.md pitch <agent> <model> <tokens>` with the tokens it reported; on a WARN line, tell the user before dispatching more.

Input: the user's idea paragraph (ask for it if missing). Template: `docs/templates/brief.md`.

## Steps

1. **Pick a slug.** Propose one matching `^[a-z][a-z0-9-]*$`, short and descriptive. Confirm it with the user. If `ideas/<slug>/` already exists, propose another.
2. **Draft the brief.** Copy `docs/templates/brief.md` to `ideas/<slug>/brief.md`. Fill every section from the idea paragraph: title, `Slug:`, Pitch, The one twist, Core loop (3–5 steps), First 60 seconds, Why come back, With friends, Money, Out of scope. Keep `Decision: pending`. Where the idea is silent, draft the simplest choice that fits and mark it `(drafted)`.
3. **Draft acceptance checks.** Under `## Acceptance checks`, list what proves the core loop works: `[lune]` for pure logic, `[playtest]` for what someone checks in Studio. Each check is one testable line.
4. **Run the council in parallel** — one message, three Agent calls: `council-hook`, `council-loop`, `council-feasibility`, each given only the brief path. Do not add your own scores.
5. **Write the council section.** Under `## Council`, one `### <agent>` subsection per member with its reply verbatim, then one line: `Total: H <n>/6 · L <n>/8 · F <n>/6`.
6. **Recommend** to the user in at most 3 lines:
   - Any score of 0 → `change`, with the member's fix.
   - Otherwise `go`, or `no-go` if totals are low across all three, with the one reason.
7. **Ask the user** for their decision: go, change or no-go. The council advises; the user decides.
8. **Record it.**
   - Set `Decision: <their answer>` (only they set it).
   - Under `## Feedback log`, `### Round 1 — <YYYY-MM-DD>`: `You said:` their words verbatim; `Decided:` the decision plus any change they asked for.
9. **If `change`:** apply only the changes they named to the brief, re-run only the council members whose criteria the change affects, add a new feedback round, and ask again.
10. **Finish.** Tell the user the brief path and the decision. If `go`, the next step is `/build-core <slug>`.

## Rules

- No game-specific content goes into agents or skills — only into `ideas/<slug>/`.
- Rejected briefs stay in `ideas/`; they are council training material.
- Never read `docs/research/`; criteria come from `docs/CRITERIA.md`.

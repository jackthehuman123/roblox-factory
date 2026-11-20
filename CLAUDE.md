# roblox-factory (beta)

Idea → council brief → the user's go/no-go → playtestable core game. Game-agnostic.

## Repo map

- `kit/` — shared starter kit: pure Luau modules (`src/shared`) + thin engine glue (`src/server`, `src/client`). See `docs/MODULES.md`.
- `templates/game/` — copied by `tools/new-game.sh <slug>` into a new game.
- `games/<slug>/` — one folder per game; its Rojo project points at `kit/` by relative path. `games/<slug>/art/` holds its art data (models + placements).
- `ideas/<slug>/brief.md` — council brief, decision and feedback log per idea. `ideas/<slug>/art.md` — art list and review log.
- `docs/` — conventions, council criteria, state, module index, review checklist, templates, training tasks, run logs. `docs/research/` (if the user makes one) is the user's private notes.
- `assets/` — the asset library, on branch `asset-library` in worktree `../<repo folder>-assets`, stocked by `/stock`. Games get models only from approved assets here.
- `tools/` — `setup.sh` (one-command setup), `check.sh` (lint, types, tests, graybox data, builds), `new-game.sh`, hooks.
- `tests/` — Lune specs for kit pure modules, shell tests for tools.

## Pipeline

`/pitch` → the user decides (go / change / no-go) → `/build-core` → playtest → `/log-run` → (games worth it) `/dress` → playtest

Idle: `/loop /stock` with the AssetWorkshop place open (set up by `bash tools/setup.sh`). `/dress` waits on `WANTED.md` until every wanted asset is stocked and approved.

## Model routing

| Agent | Model |
|---|---|
| explorer, council-hook, council-loop | haiku |
| council-feasibility, builder, world-builder, studio-tester, art-director, asset-builder | sonnet |
| art-judge | not wired (judge off) |
| reviewer | opus |

## Rules

- Read `docs/MODULES.md` before searching code.
- Never edit `kit/` during `/build-core`; propose the kit change instead.
- Worlds change only via `games/<slug>/src/server/graybox.luau`; art only via `games/<slug>/art/`.
- Before changing a game, read every "Decided" line in its brief's feedback log.
- Run `tools/check.sh` before saying done; it must print `OK`.
- Studio MCP: query specific paths or tags, never whole trees. Console output over screenshots.
- Never read `docs/research/` (humans only); use `docs/CRITERIA.md`.
- The asset library changes only via /stock (art-director and /dress write only WANTED.md).
- Budgets: `docs/BUDGETS.md`.
- Shell commands one at a time, never chained with `&&` or `;`.
- No game-specific content in agents or skills.
- Code style: `docs/CONVENTIONS.md`. Review: `docs/REVIEW_CHECKLIST.md`. Current state: `docs/STATE.md`.

# How the factory works

Snapshot 2026-11-20 (branch `asset-engine`, generated asset engine). Source of truth: `.claude/skills/*/SKILL.md` and `.claude/agents/*.md`; this file summarizes them. If they disagree, they win.

## 1. The shape

```
idea ──/pitch──▶ brief ──you: go──▶ /build-core ──▶ playtest ──▶ /log-run
                                                           │
                                                           └──▶ /dress ◀── library ◀── /stock (idle loop)
                                                  │            ▲
                                                  ▼            │ generate_mesh + scripts
                                              WANTED.md ──▶ inbox images ──▶ you: approved | regen | discard
```

- **Skills** are the stage scripts the main session follows (`/pitch`, `/build-core`, `/dress`, `/stock`, `/log-run`). The main session is the coordinator: it reads files, runs tools, dispatches agents, records tokens and talks to you.
- **Agents** are subagents with a fixed model, a fixed tool list and a short numbered instruction file. Each starts cold, gets only what the skill passes it (a slug, a path, check lines), and replies in a fixed short shape (10–15 lines).
- **Files are the hand-off.** Nothing passes between stages except files: `ideas/<slug>/brief.md`, `games/<slug>/…`, `ideas/<slug>/art.md`, `assets/…`, `docs/STATE.md`. One session per stage.
- **You decide.** Only you set `Decision:` in a brief, approves an art plan, approves, regenerates or discards library assets, and approves or rejects art items. Agents and skills advise.

### Guardrails that apply everywhere

| Guardrail | How it is enforced |
|---|---|
| Never read `docs/research/`, `Packages/`, `work/`, place files, `sourcemap.json` | `permissions.deny` in `.claude/settings.json` (structural) and a line in each agent |
| `.luau` files are always formatted | PostToolUse hook `tools/hooks/post-edit.sh` runs StyLua after every Edit/Write |
| "Done" means `tools/check.sh` prints `OK` | Every building skill/agent ends with it. It runs: StyLua check, selene lint, Lune tests, `graybox_check`, `art_check`, `asset_check`, then per game `rojo sourcemap` + `luau-lsp analyze` + `rojo build`, then shell tests. Prints only `OK` or `file:line: message` lines |
| One run at a time | `.factory-busy` file in the main checkout (`<stage> <ISO time>`); every skill stops if present, removes it on stop and before waiting on you |
| `Decided:` lines bind | Every agent that changes a game reads the brief's feedback log first |
| No game-specific content in agents/skills | Rule in `CLAUDE.md`, `/pitch`, `/log-run` |
| Token budgets | Each agent file opens with `Budget: ~Nk tokens per call`; skills log every agent's tokens with `lune run tools/budget_add <file> <stage> <agent> <model> <tokens>`, which prints a WARN line when over (see `docs/BUDGETS.md`) |
| Shell commands one at a time, never chained | Text rule in `CLAUDE.md` and every agent |

### Models and budgets

| Agent | Model | Tools | Budget/call | Used in |
|---|---|---|---|---|
| council-hook | haiku | Read | 15k | /pitch |
| council-loop | haiku | Read | 15k | /pitch |
| council-feasibility | sonnet | Read | 25k | /pitch |
| world-builder | sonnet | Read, Edit, Write, Bash | 40k | /build-core |
| builder | sonnet | Read, Edit, Write, Bash | 60k | /build-core, /dress (tags only) |
| reviewer | opus | Read, Grep, `git diff` | 140k | /build-core, /dress (conditional) |
| studio-tester | sonnet | Read + Studio (state, play, execute_luau, inspect, console, screenshot) | 60k | /build-core (playtest) |
| art-director | sonnet | Read, Write, Bash | 80k | /dress |
| art-judge | sonnet | Read + Studio (state, execute_luau, screenshot) | 50k | **not wired** |
| asset-builder | sonnet | Read, Write, Bash + Studio (state, generate_mesh, execute_luau, screenshot) | none yet (logged) | /stock |
| explorer | haiku | Read, Grep, Glob | 15k | any, on demand |

Stage budgets: pitch 60k · build-core 300k · playtest 60k · log-run 30k · dress 80k · stock logged only (no budget yet) · coordination 150k per game · fixes 100k per game. One game ≈ 900k.

---

## 2. `/pitch` — idea → council brief → your decision

**Input:** your idea paragraph. **Output:** `ideas/<slug>/brief.md` with `Decision:` set. **Budget:** 60k.

Coordinator steps:
1. Propose a slug (`^[a-z][a-z0-9-]*$`), you confirm.
2. Copy `docs/templates/brief.md`, fill every section (Pitch, The one twist, Core loop 3–5 steps, First 60 seconds, Why come back, With friends, Money, Out of scope). Where the idea is silent, draft the simplest choice and mark it `(drafted)`.
3. Draft acceptance checks: `[lune]` (pure logic, tested by Lune) and `[playtest]` (checked in Studio), one testable line each.
4. Dispatch the three council agents **in parallel**, each given only the brief path. The coordinator adds no scores of its own.
5. Paste each reply verbatim under `## Council`, plus `Total: H n/6 · L n/8 · F n/6`.
6. Recommend in ≤ 3 lines: any 0 → `change` with that member's fix; else `go`, or `no-go` if low everywhere.
7. You decide; record `Decision:` and a feedback round (`You said:` verbatim, `Decided:`). On `change`, apply only your changes and re-run only the affected council members.

### The council agents

All three score against `docs/CRITERIA.md` (each criterion 0/1/2 with written 0 and 2 lines; any 0 means change before go).

| Agent | Scores | Reads | Must not read | Reply shape |
|---|---|---|---|---|
| council-hook | H1 understood in 3 s from title+thumbnail · H2 fun within 60 s · H3 one twist on a known loop | CRITERIA, the brief | code, other docs | 3 score lines, `Total n/6`, `Biggest risk`, `Fix` (required if any 0) |
| council-loop | L1 reason to return tomorrow · L2 content grows weekly as data · L3 better with friends · L4 non-P2W things to buy | CRITERIA, the brief | code, other docs | 4 score lines, `Total n/8`, risk, fix |
| council-feasibility | F1 buildable on the kit in ≤ 5 sessions · F2 runs on a phone · F3 playtestable by 1–4 people | CRITERIA, `docs/MODULES.md`, the brief | kit source, other docs | 3 score lines naming kit modules used/missing, `Total n/6`, risk, fix |

**How they're instructed:** score only their own criteria, use only the 0/2 anchor lines, one-line reasons, ≤ 15 lines, exact shape. They judge text only; nobody plays anything at this stage.

---

## 3. `/build-core` — brief → playtestable graybox game

**Input:** slug with `Decision: go`. **Output:** `games/<slug>/` passing `check.sh`, a filled `playtest.md`. **Budget:** 300k (+60k playtest).

Coordinator steps:
1. Gate on `Decision: go` and `.factory-busy`; take the lock.
2. Read the brief once, including every `Decided:` line.
3. First round: `tools/new-game.sh <slug>` copies `templates/game/` (Rojo project pointing at `kit/` by relative path).
4. Write the brief's numbers into `games/<slug>/src/server/config.luau` (plain values).
5. **World:** one `world-builder` call with the graybox needs.
6. **Logic:** group acceptance checks by the files they touch; one `builder` call per group.
7. **Kit:** never edited here; if an agent needs a kit change, it becomes a written proposal to you.
8. `check.sh` → failing lines go to the owning agent, at most 2 rounds, then you.
9. **Review:** `reviewer` only if the diff touches remotes, player data, client trust, `kit/`, or is over ~150 lines. Must-fix items go back to the owning agent.
10. **Studio:** start `rojo serve`, you connect the plugin, then `studio-tester` runs the `[playtest]` lines (tokens logged as stage `playtest`).
11. Fill `playtest.md` (how to run, what to try/watch, questions, Results table). 12. Update `docs/STATE.md`. 13. Hand off.

Feedback rounds: new `### Round n` in the brief (`you said:` / `Decided:`), only the delta goes to the owning agent, then steps 8–13 again.

### world-builder (sonnet, 40k)
- **Does:** creates/changes the graybox world.
- **How:** edits only `games/<slug>/src/server/graybox.luau` — a list of plain-data boxes (shape `Box` in `kit/src/shared/Graybox.luau`), loaded at runtime by kit `GrayboxLoader`.
- **Instructed:** read `Decided:` lines first; 1-stud grid (whole sizes, faces on whole studs, so odd sizes sit at `.5`); materials only SmoothPlastic, Concrete, Wood, Grass, Slate, Metal, Neon; colours 0–255; keep part count phone-friendly; tag boxes the game code looks up. `check.sh` validates every box (`graybox_check`). Reply ≤ 10 lines: box count, tags, what changed, `check.sh` output.
- **Sees:** text only. It never sees the world it builds.

### builder (sonnet, 60k)
- **Does:** implements one group of acceptance checks or brief section.
- **How:** reads `docs/MODULES.md` + `docs/CONVENTIONS.md`, uses kit modules (RoundState, RateLimit, Schema, PlayerData; glue RoundService, Net, DataService, NetClient, Hud). `[lune]` checks: logic in a pure module under `games/<slug>/src/shared/` plus `tests/games/<slug>/<name>.spec.luau`.
- **Instructed:** edit only `games/<slug>/` and `tests/games/<slug>/`; never `graybox.luau`; never `kit/` (stop and propose instead); loop `check.sh` until `OK`. Reply ≤ 15 lines: files, checks done, what's left for `[playtest]`, `check.sh` output.
- **Sees:** text + test output.

### reviewer (opus, 140k)
- **Does:** reviews a diff against the brief and `docs/REVIEW_CHECKLIST.md`.
- **Instructed:** read `Decided:` lines, check every checklist item, read surrounding code only as needed, never edit. Reply `PASS` or ≤ 15 numbered `file:line — problem — fix`, most serious first.
- **When:** only for remotes / player data / client trust / `kit/` / diffs over ~150 lines.

### studio-tester (sonnet, 60k)
- **Does:** runs `[playtest]` checks in Studio and reports pass/fail.
- **How:** play mode, then judges from **console output and queries of named paths or tags** (`GetAttribute`, `CollectionService:GetTagged`). Must be given a `studio_id` from `list_roblox_studios`.
- **Instructed:** never dump whole trees; `inspect_instance` only on a named path; screenshot only when asked; never edit files or the place; stop play when done. Reply `PASS <check>` / `FAIL <check> — what you saw`, ≤ 3 note lines.
- **Sees:** numbers and state, almost never pixels. It can't do real input (it teleports the player), so checks about feel, readability or long walks come back "not testable".

---

## 4. `/log-run` — playtest → run log → practice tasks

**Budget:** 30k, main session only (no agents).

1. Ask you in one message: `/cost` per stage, verdict (keep/change/kill), sessions used, failure costs, anything that went wrong.
2. Gather facts from files (brief, playtest.md, both `budget.md` files, `git log`), never memory.
3. Rework rounds = feedback rounds after `/build-core` first ran.
4. One row per failure, attributed to exactly one agent or skill.
5. Write `docs/runs/<date>-<slug>.md` from `docs/templates/run-log.md`.
6. Per failure, append a practice task `T<n>` to `docs/training/<agent>.md` (`Input:`, `Failure seen:`, `Pass when:` — a checkable condition).
7. End with the single change most likely to remove the costliest failure. 8. STATE. 9. `check.sh`. 10. Report in ≤ 5 lines.

Never invents costs or verdicts; fixes to agents stay game-agnostic.

---

## 5. The asset library and `/stock`

**Where:** branch `asset-library`, worktree `../<repo folder>-assets` (`tools/asset_worktree.sh` creates/prints it). Contents: `assets/inbox/` (reference images you drop), `library/<Name>.luau` (model data), `thumbs/<Name>.png`, `index.luau` (catalogue: name, tags, size, sources, built route, review state), `tags.luau` (allowed tags), `WANTED.md` (per-game wanted lists, 5 per game + over-limit), `REVIEW.md` (your verdicts), `budget.md`. Changes only via `/stock` and the `asset_db` / `art_import` tools; never hand-edited.

**`/stock` coordinator steps** (tokens logged, no budget yet; usually run as `/loop /stock` while idle):
1. Stop if `.factory-busy`. 2. Get the worktree. 3. `asset_db review` syncs your verdicts from REVIEW.md (a `regen: <note>` adds the note to the asset's criteria; `discard` deletes the asset and un-ticks its wanted item), then commits them (`assets: sync review`).
4. Find the Studio named `AssetWorkshop` in Edit mode; keep its `studio_id`.
5. `asset_db regen-next` → a name means this run regenerates it; otherwise take the oldest inbox image and copy a spare outside the repo.
6. Dispatch `asset-builder` (`image <path>` or `regen <Name>`); log tokens.
7. `check.sh` in the worktree; one fix round; still failing → restore the worktree, put the spare back, stop the loop.
8. `asset_db review`, commit. 9. Report names, generations, measure lines, merges, skips, tokens.

### asset-builder (sonnet, no budget yet; logged per run)
- **Does:** describes each object in a reference image and has Roblox make it. One `generate_mesh` per object, no retries, no judging.
- **How:** read a copy of the image shrunk to 1024 px once → per object a criteria file (`assets/criteria/<Name>.json`: size, prompt ≤ 40 words, colours, materials, source; `asset_db criteria`) → `generate_mesh` (prompt, size, 10k triangles, parts left to the tool) → one line `require(game.ServerStorage.ArtFinish:Clone())(tag, Name, x, y, z)` (cloned: Studio caches `require`), which empties the workshop, names parts `<Name>_1…`, turns the model 90° if that fits the criteria width/depth better, scales to the criteria height, pivots at the bottom centre and returns a camera line + the `ARTDUMP` line → `art_import --library` → one `screen_capture` from that camera → `thumbs/<Name>.png` → `asset_db add` → `asset_db measure` (size vs criteria, base height, part count — information only, no pass/fail; the entry also counts its generations: 1 on add, +1 per regen) → `want-done` if it filled a wanted item (refused for a name not in the library) → `asset_db finish`.
- **Regen:** same steps from the stored criteria, prompt plus your notes as ` Fix: <note>.`, `--replace` / `asset_db replace`.
- **Sees:** the reference image only. It never judges its output.
- **Lesson on record:** text-only rules get skipped; every fixed step is a one-line call (`ArtDump`, `ArtFinish`). Generated models were "wildly better" than Claude-built parts (2026-11-20 spike).

**Your review:** each asset in `REVIEW.md` shows its thumbnail, how many generations it took, and its measure lines. You write `approved`, `regen: <note>` (made again once with the note) or `discard` (removed). `rejected: <reason>` still means regen.

---

## 6. `/dress` — playtested game → real models

**Input:** slug whose `playtest.md` has a filled Results table. **Budget:** 80k. Models come **only** from approved library assets.

Coordinator steps:
1. Gate: Results filled; no `.factory-busy`.
2. Wire (old games only): copy `templates/game/art/`, add `ServerStorage.Art` and the `ArtLoader` block, `check.sh`.
3. Lock (`dress <ISO time>`); released before every wait on you.
4. **Plan** (full run, i.e. no `Plan approved: yes` in art.md): `art-director` writes `ideas/<slug>/art.md`. You see the Look, Items table and wanted list; approves, edits or cuts. Cuts go back to `art-director` to remove from art.md and `WANTED.md`. Then `Plan approved: yes`.
5. **Tags:** if "Tags needed" lists anything, `builder` adds only those CollectionService tags (no behaviour change).
6. **Wait:** `asset_db review`, then `asset_db wanted <slug> <names>`. A pick marked `regen` waits on `/stock`; a discarded pick becomes an unticked wanted item again. A rejected pick → fresh `art-director` re-pick (once). Any other output → tell you what to stock/review and stop. Re-running `/dress` comes straight back here. No output → ready.
7. **Copy** picked `library/<Name>.luau` files into `games/<slug>/art/models/`; `art-director` again to place newly available items.
8. **Check:** `art_check`, `check.sh` → `OK`; `reviewer` only if `kit/` changed or the non-model diff is over ~150 lines.
9. **Review:** you press Play and walk the game; per item approved, or rejected with a note. Logged as a `### Round n` in art.md. A rejected item → `art-director` picks another approved asset or adds a new wanted item carrying your note; then back to step 6.
10. STATE. 11. Hand off, listing every `allow` (waived placement check).

Art never changes gameplay: no collisions, no new behaviour; tags are the only game-code change.

### art-director (sonnet, 80k)
- **Does:** decides what the game should look like, picks library assets, writes the wanted list and placements.
- **How, step by step:**
  1. Read the brief (`Decided:` lines binding), `playtest.md`, `graybox.luau` (tags, sizes, layout) and the game's `src/` to learn what exists at runtime and how it's tagged.
  2. Write `ideas/<slug>/art.md` from `docs/templates/art.md` (Look paragraph + Items table: Name, what it is and why it fits, Where, Source, Size, Status). On a re-run keep `Plan approved`, Review log and statuses.
  3. Start from the hook — threat, goal, the space around the player — then props. 5–15 items, each sized to the grey part it replaces or sits on.
  4. Per item, `asset_find --root <wt> <tags>` (setting, era, mood, room). Approved first; else an unreviewed match via `--all`; never a rejected one. Match → `library: <Name>`.
  5. No match → `wanted: <Name>` + a line in `WANTED.md` (`- [ ] Name — tags — about x×y×z — description`). Max 5 per game; extras under `### Over the limit`.
  6. Write `games/<slug>/art/placements.luau` for library picks only: `onTag <Tag>` (skin every tagged part, optionally `hideBase`) or `at x,y,z`; `sit` for height; `allow` only to knowingly waive a named rule.
  7. Lights that game code toggles are gameplay → those items get "no lights".
  8. ≤ 3000 art parts (each `onTag` model counts once per tagged part, per player for per-player tags).
  9. List untagged runtime objects it wants to skin under "Tags needed"; never edits game code.
  10–12. Later calls: place newly available items; delete cut items; on a rejection, re-pick or add a new wanted item carrying your note.
- **Reply:** ≤ 10 lines: item count, Look in one line, picks vs wanted, over-limit, tags needed.
- **Sees:** text only — brief, code, tag search results. It has no Studio tools and does not open library thumbnails, so it never sees the game, the lighting, or the assets it picks.

### art-judge (sonnet, 50k) — not wired
- **Would do:** judge placed items from fixed preview screenshots, PASS / FIX / NOT JUDGED per item.
- **How:** reads the Look and its item rows; runs `tools/art/views.luau` (read-only to it) via `execute_luau` with `ITEMS` set, which builds `Workspace.ArtPreview` and returns 4 `VIEW` camera lines per item; captures each; judges against the row, the Look and named mistakes (clipping, floating, sinking, flicker, wrong scale next to a player, flat textures, clashing with the Look, unreadable from where the player stands); always cleans up.
- **Status:** turned off in the library plan to save tokens.  It judges items one at a time against their own row, not the whole scene.
- **To re-enable:** add a step before Review in `/dress` sending it slug, `studio_id`, item numbers; at most 2 FIX rounds.

### explorer (haiku, 15k)
Answers "where is X / how does X work": starts from `docs/MODULES.md` and the repo map, reads excerpts, never suggests changes unless asked. Reply ≤ 15 lines with `path:line` refs.

---

## 7. Who sees what

| Agent | Text/code | Test/console output | Pixels |
|---|---|---|---|
| council ×3 | brief, criteria (feasibility also MODULES) | — | — |
| world-builder, builder | yes | `check.sh`, Lune | — |
| reviewer | diff + checklist | `check.sh` | — |
| studio-tester | check lines | console, path/tag queries | only on request |
| asset-builder | WANTED, tags, index, criteria | tool output | reference image only (never judges output) |
| art-director | brief, code, art.md | `asset_find` | **none** |
| art-judge (off) | art.md rows + Look | `views.luau` lines | 4 fixed views per item |
| you | everything | — | plays the game; the only whole-scene judge |

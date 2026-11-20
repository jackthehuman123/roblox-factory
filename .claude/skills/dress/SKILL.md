---
name: dress
description: Use when the user types /dress <slug> to give a playtested game real models, or to apply their art review feedback.
---

# Dress a game

Stage budget: 80k tokens (docs/BUDGETS.md). After each agent finishes, run `lune run tools/budget_add games/<slug>/budget.md dress <agent> <model> <tokens>` with the tokens it reported; on a WARN line, tell the user before dispatching more.

Input: slug (ask if missing). Art list: `ideas/<slug>/art.md`. Art data: `games/<slug>/art/`. Models come only from approved assets in the library worktree (path printed by `bash tools/asset_worktree.sh`) (`<wt>`); nothing is searched or generated here. Run shell commands one at a time, never chained with `&&` or `;`.

## Steps

1. **Gate.** `games/<slug>/playtest.md` must have a filled Results table. If not, stop and tell the user art comes after a playtest. If `.factory-busy` exists, stop: "factory busy (<content of .factory-busy>) — delete .factory-busy if no run is going".
2. **Wire** (games built before the art kit only). If `games/<slug>/art/` is missing, copy `templates/game/art/` into it. Add the `ServerStorage.Art` entry from `templates/game/default.project.json` and the ArtLoader block from `templates/game/src/server/init.server.luau` to the game. Then run `tools/check.sh`.
3. **Lock.** Run `bash tools/asset_worktree.sh` (prints `<wt>`), then write `.factory-busy` in the main checkout as `dress <ISO time>`. Remove it at the end, on every stop below, and before any wait on the user (plan approval in step 4, the walkthrough in step 9); take it again, same content, when they answers.
4. **Plan.** If `ideas/<slug>/art.md` has the line `Plan approved: yes`, this is a re-run: skip to step 6. Otherwise (no line: full run) send `art-director` the slug and `<wt>`. Show the user the Look section and the Items table of `ideas/<slug>/art.md`, plus the wanted items. They approves, edits or cuts items (`approved-idea` or `cut`). Cut items are removed from art.md; send `art-director` the slug, `<wt>` and the cut names so it deletes their lines from `<wt>/assets/WANTED.md`. Once they approves, write the line `Plan approved: yes` into `ideas/<slug>/art.md`.
5. **Tags.** If "Tags needed" lists anything, send `builder` only those tag additions (add a CollectionService tag where the object is created; no behaviour change). Then run `tools/check.sh`.
6. **Wait.** Run `lune run tools/asset_db --root <wt> review` first, so their verdicts are in. Then run `lune run tools/asset_db --root <wt> wanted <slug> <every library: and wanted: Name of items not cut>`. A picked asset marked `regen` prints `regen <Name>: waiting on /stock`; a discarded one comes back as an unticked wanted item (`discarded; drop a new reference image`). Both are waits, like any other output below. For each `rejected <Name>: <reason> — re-pick` line, send `art-director` (fresh) the slug, `<wt>`, the name and the reason, per its rejected-item rule, then run this step again. Re-pick at most once per run: if the same rejected line comes back, stop, remove `.factory-busy` and tell the user. Any other output: remove `.factory-busy`, tell the user exactly what to stock (the wanted items with descriptions, drop reference images in `<wt>/assets/inbox/`, run `/stock`) and what to review or decide (the printed lines, including over-limit items to tick or delete), and stop. A later `/dress` re-run does steps 1 and 3, then comes straight back here. No output: ready.
7. **Copy.** Copy each picked `<wt>/assets/library/<Name>.luau` into `games/<slug>/art/models/`. Dispatch `art-director` again (fresh; it reads art.md) with the slug and `<wt>` for placements of items that just became available and to drop deleted over-limit items.
8. **Check.** Run `lune run tools/art_check games/<slug>`, then `tools/check.sh`; it must print `OK`. Send `reviewer` only if `kit/` changed, or if the diff outside `games/<slug>/art/models/` is over ~150 lines.
9. **Review.** Tell the user to press Play and walk the game. They answer per item: approved, or rejected with a note. Add a `### Round <n> — <YYYY-MM-DD>` block to the art.md Review log and set each Status. For a rejected item, dispatch `art-director` with the slug, `<wt>` and their note: it picks a different approved asset that fits, or else adds a new wanted item under a new descriptive name carrying the note, and removes the old pick from art.md and placements; delete the old model file. Then continue at step 6 (wait), not by running `/dress` again. Only the user approves anything.
10. **State.** Update `docs/STATE.md` (≤ 40 lines): the game is dressed, items approved / cut / waiting, known issues.
11. **Hand off.** Tell the user what's approved, cut, waiting or rejected. List every `allow` in `games/<slug>/art/placements.luau` (placement, rule) so they knows which checks were waived. Remove `.factory-busy`.

## Rules

- Art changes only via `games/<slug>/art/` (model files are copied from the library, never hand-written).
- Art never changes gameplay: no collisions, no new behaviour. Tags are the only game-code change allowed here.
- Never edit `kit/` during `/dress`; propose the kit change instead.
- `art-judge` is not called (judge off). To re-enable: add a step before Review that sends it the slug, a `studio_id` and the item numbers, with at most 2 FIX rounds.

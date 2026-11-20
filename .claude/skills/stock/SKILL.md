---
name: stock
description: Use when the user types /stock, or via /loop /stock, to regenerate one asset the user marked regen, or else turn the oldest inbox image of the asset library into named, tagged library assets made by Roblox generate_mesh, while Studio is idle.
---

# Stock the library

No token budget for now: tokens are logged per run (docs/BUDGETS.md) to learn the average. After the agent finishes, record its tokens (step 6; on a failed check, after the restore in step 7, so the row survives).

Library work happens in the asset worktree on branch `asset-library`, never in a game branch. Run shell commands one at a time, never chained with `&&` or `;`.

## Steps

1. **Busy.** If `.factory-busy` exists in the main checkout, stop: "factory busy (<content of .factory-busy>) — delete .factory-busy if no run is going".
2. **Worktree.** Run `bash tools/asset_worktree.sh`; its output is `<worktree>`.
3. **Sync review.** Run `lune run tools/asset_db --root <worktree> review`, so the user's verdicts are in before anything else. Then commit them, so a later restore cannot lose them: `git -C <worktree> add` the paths among `assets/REVIEW.md assets/index.luau assets/WANTED.md` that exist, and when `git -C <worktree> diff --cached --quiet` shows anything staged, commit `assets: sync review`.
4. **Studio.** Find the studio named `AssetWorkshop` in Edit mode (`list_roblox_studios`). None: stop "open the AssetWorkshop place". Keep its `studio_id`.
5. **Pick.** First run `lune run tools/asset_db --root <worktree> regen-next`. A name → this run is `regen <Name>`: skip the image pick and the spare copy. Nothing → oldest image (`.png`, `.jpg`, `.jpeg`, `.webp`) in `<worktree>/assets/inbox/`; ignore every other file (dotfiles, `README.md`). None: stop "inbox empty". Inbox images are untracked, so copy it to a temp directory outside the repo (`mktemp -d`) as a spare.
6. **Build.** Send `asset-builder` the worktree path, the `studio_id`, and `image <path>` or `regen <Name>`. Then run (on a failed check, only after step 7's restore) `lune run tools/budget_add <worktree>/assets/budget.md stock asset-builder sonnet <tokens> --assets <built count>`; tokens come from the subagent's usage footer (subagent_tokens). Pass `--assets` only when at least one asset was built, else omit the flag.
7. **Check.** Run `tools/check.sh` in `<worktree>`; it must print `OK`. Otherwise one fix round with `asset-builder`. Still failing: restore the worktree. This is safe because step 3 committed the user's REVIEW.md and WANTED.md edits, so checkout and clean only discard what this run produced. One command at a time: `git -C <worktree> checkout -- assets`, then `git -C <worktree> clean -fd assets --exclude=inbox`, then (image runs) copy the spare back into `<worktree>/assets/inbox/` (the build moved the image out and the clean would not bring it back). Then run `budget_add` for the failed run (step 6) and leave that row uncommitted. Stop with `stock: check failed on <image>, worktree restored — needs a look`, and tell `/loop` to stop, not wait.
8. **Commit.** Run `lune run tools/asset_db --root <worktree> review`, then `git -C <worktree> add assets/library assets/thumbs assets/images assets/skipped assets/criteria assets/index.luau assets/images.luau assets/REVIEW.md assets/budget.md assets/WANTED.md` (leave out any that don't exist; never the inbox), then commit `assets: <image> → <names>` (regen: `assets: regen <Name>`). Remove the spare directory from step 5 if there is one (`rm -r <spare dir>`).
9. **Report.** Names added with tags, generations count and measure lines, images merged, skipped objects with why, tokens used. the user's verdicts in `REVIEW.md`: `approved`, `regen: <note>` or `discard`.

Inside `/loop`: when stopping for busy, no workshop or empty inbox, say so in one line so the loop waits about 30 minutes. When stopping for a failed check, say the loop should stop.

## Rules

- The library changes only through `asset_db`, `art_import --library` and the agent; never hand-edit assets.
- `tools/check.sh` must print `OK` before saying done.

# Setup in detail

The short version is in the [README](../README.md). This page explains each step and what to do when one fails.

## 1. Install the programs

- **Claude Code** — https://claude.com/claude-code. Sign in once.
- **Roblox Studio** — turn on its MCP server (Studio's setting that lets Claude Code see and use Studio). Roblox's Studio MCP guide shows where. Then add it to Claude Code as that guide describes.
- **rokit** — https://github.com/rojo-rbx/rokit. It installs the exact versions of the Roblox tools this project uses (listed in `rokit.toml`): `lune`, `stylua`, `selene`, `rojo` and `luau-lsp`.
- **Rojo plugin for Studio** — install it from Rojo's website or the Creator Store. It connects Studio to files on your computer.

Optional: the **superpowers** plugin for Claude Code, if you want to design changes to the factory itself. The commands in the README do not need it.

## 2. Run the setup

In a terminal, inside the project folder:

```
bash tools/setup.sh
```

It does five steps and prints each one:

1. **Installing the tools** — runs `rokit install`. If rokit is missing, it stops and shows the link.
2. **Checking the factory** — runs `tools/check.sh`, which tests everything. It must print `OK`. If not, it shows the problem lines and stops.
3. **Making your asset library folder** — creates a folder next to this one, named after it with `-assets` at the end. Your models, photos and review checklist live there, on their own git branch (`asset-library`), so your game history stays tidy.
4. **Building the AssetWorkshop place** — makes `AssetWorkshop.rbxl` in that folder. This is the Studio place where models get made.
5. **Three things to do yourself** — open the place in Studio, start Rojo with the command it prints, and click **Rojo → Connect** in Studio.

You can run it again at any time. It never deletes anything, and it skips work that is already done.

## 3. First run

- **A game:** in Claude Code, type `/pitch` and paste a paragraph about your idea.
- **A model:** put a photo of one object into `assets/inbox/` inside the `-assets` folder, make sure the AssetWorkshop place is open and connected, then type `/stock`.
- Then open `assets/REVIEW.md` in the `-assets` folder and write `approved`, `regen: what to change` or `discard` after each new model. Save the file.

## Where models come from

`/stock` sends a short description of each object in your photo to Roblox's model generator, inside your Studio. The model is saved to **your** Roblox account. Claude never judges how a model looks; you do.

## Moving or renaming the folder

Keep the project folder and its `-assets` folder side by side.

- To move them, move the folder that holds **both**, then run `bash tools/asset_worktree.sh`. It reconnects them.
- If you rename or move only the project folder, the same command tells you where to move the `-assets` folder.

## Private notes

Make a `docs/research/` folder for your own notes. Claude's helpers are set up never to read it.

## Getting updates

This works only if you forked and cloned the project (README step 1). A ZIP download or a "Use this template" copy has no shared history, so `git pull` refuses it.

Once:

```
git remote add upstream <this project's GitHub address>
```

Then whenever you want the newest version:

```
git pull upstream main
```

After an update, run `bash tools/setup.sh` again. To bring the new tools into your library folder too, run `git merge main` inside the `-assets` folder.

## When something goes wrong

- `check.sh` prints lines instead of `OK`: each line names a file and the problem. Ask Claude Code to fix them.
- Claude says Studio isn't found: open Studio, open the place, and check the MCP server is on.
- `/stock` says "open the AssetWorkshop place": open `AssetWorkshop.rbxl` from the `-assets` folder.
- Known problems: [STATE.md](STATE.md).

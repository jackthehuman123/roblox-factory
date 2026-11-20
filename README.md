# Roblox Factory (beta)

You describe a Roblox game idea. Claude checks the idea, builds a rough playable version, and makes 3D models from photos you drop in a folder.

You decide at every step: nothing moves forward until you say yes.

## What you need

- **Claude Code** (the Claude app for your terminal): https://claude.com/claude-code
- **Roblox Studio**, with its built-in MCP server turned on, so Claude can see and use Studio.
- **The Rojo plugin for Studio**, which links Studio to the files on your computer: https://rojo.space/docs/v7/getting-started/installation/
- **rokit**, a small installer for the Roblox tools this uses: https://github.com/rojo-rbx/rokit
- About 15 minutes.

## Set up

1. Copy this project: click **Fork** on GitHub, then in a terminal run `git clone <your fork's address>`. (A ZIP download can't get updates.)
2. In the terminal, go into the project folder and run:

```
bash tools/setup.sh
```

3. It ends with three things to do yourself: open the AssetWorkshop place it made, start Rojo, and click **Rojo → Connect** in Studio.

More detail, and what to do if something goes wrong: [docs/SETUP.md](docs/SETUP.md).

## How it works

```
your idea → /pitch → you decide → /build-core → you play it → /log-run
                                                     └→ /dress (real models from your library)
photos you drop in → /stock → you approve each model → your library
```

## The commands

Type these in Claude Code, inside this folder.

| Command | What it does |
|---|---|
| `/pitch` | Turns your idea into a short plan. Three reviewers score it; you choose go, change or no. |
| `/build-core <name>` | Builds a rough playable version of an idea you said go to. |
| `/log-run <name>` | After you play it: records what it cost and what went wrong, so the helpers improve. |
| `/dress <name>` | Swaps the grey blocks for real models from your library. Lists any models still missing. |
| `/stock` | Turns one photo from your inbox into 3D models in your library. Studio must be open with the AssetWorkshop place. |
| `/loop /stock` | Keeps doing `/stock` in the background until the inbox is empty. |

## Where your things live

- `ideas/` — one plan per game idea, with your decisions.
- `games/` — the games themselves.
- The `-assets` folder next to this one — your model library. Drop photos into its `assets/inbox/`.
- `assets/REVIEW.md` (in that folder) — your checklist. After each model write `approved`, `regen: what to change`, or `discard`.
- `assets/WANTED.md` — models your games still need. Find a photo for each and drop it in the inbox.

Models are made by Roblox's own model generator and saved to **your** Roblox account.

## What it costs

Claude Code bills by usage. Rough amounts per step:

| Step | Rough cost |
|---|---|
| One `/pitch` | up to 60k tokens |
| One `/build-core` | up to 300k tokens |
| One model from `/stock` | about 21k tokens |

Each step records what it really used. Full table: [docs/BUDGETS.md](docs/BUDGETS.md).

To stop anything, press **Esc** in Claude Code.

## Getting updates

Run these once, then the second line whenever you want the newest version:

```
git remote add upstream <this project's GitHub address>
git pull upstream main
```

## This is a beta

Things will break. Known problems are listed in [docs/STATE.md](docs/STATE.md). How everything fits together: [docs/FACTORY.md](docs/FACTORY.md).

License: MIT. Made by catlyn.

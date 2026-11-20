# Inbox: how to add assets

1. **Drop an image here** (png, jpg, jpeg, webp). One object per photo works best.
   Name it with tag words joined by dashes: `home-kitchen-modern-cozy.png`.

   Tag words:
   - setting: city village suburb home school hospital office shop forest castle dungeon space industrial
   - era: old medieval victorian modern futuristic
   - mood: horror cozy cute grimy clean
   - room: bedroom kitchen bathroom livingroom hallway classroom street garden
   - kind: furniture prop plant light decor structure vehicle sign

2. **Start the workshop** (once per session):
   - Open Roblox Studio, then open `AssetWorkshop.rbxl` from the top of this `-assets` folder (`bash tools/setup.sh` makes it). Stay in Edit mode.
   - Turn on Studio's MCP server (see Roblox's Studio MCP guide). In Claude Code, type `/mcp` and check that Roblox Studio shows as connected.
   - In a terminal inside this `-assets` folder, run `rojo serve assets/workshop.project.json --port 34880` and leave it running.
   - In Studio, click **Rojo → Connect**.

3. **Type `/stock`** (one image) or **`/loop /stock`** (the whole inbox).

4. **Review** `../REVIEW.md`: each asset shows a screenshot, how many generations it took, and its measurements (information only). After `verdict:` write one of:
   - `approved` — games may use it.
   - `regen: <what to change>` — the next `/stock` makes it again once, with your note.
   - `discard` — removes it (and un-ticks the wanted item it filled).
   Only approved assets reach games.

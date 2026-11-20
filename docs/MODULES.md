# Kit modules

In a game: `kit/src/shared` → `ReplicatedStorage.Kit`, `kit/src/server` → `ServerScriptService.Kit`, `kit/src/client` → `StarterPlayerScripts.Kit`.

| path | purpose | public API |
|---|---|---|
| `kit/src/shared/RoundState.luau` | Pure round state machine: Lobby → Intermission → Playing → Ended → Lobby | `validateConfig(config) -> {string}`, `new() -> State`, `step(state, config, dt, playerCount) -> State`; types `Phase`, `Config`, `State` |
| `kit/src/shared/RateLimit.luau` | Fixed-window rate limiter keyed by string | `new(maxCalls, window) -> Limiter`; `limiter:allow(key, now) -> boolean` |
| `kit/src/shared/Schema.luau` | Checks remote arguments against type names; never errors | `check(spec: {string}, args: {any}) -> boolean` |
| `kit/src/shared/PlayerData.luau` | Merges saved data onto defaults (same keys, same types only) | `withDefaults(saved?, defaults) -> table` |
| `kit/src/shared/Graybox.luau` | Validates graybox box data; returns every problem | `validate(boxes: {Box}) -> {string}`; type `Box` |
| `kit/src/shared/Art.luau` | Validates art data: plain-data models (parts, meshes, lights, surfaces, decals) | `validateModel(name, model, checkExtra?) -> {string}`, `MATERIALS`, `MAX_PARTS`, `RULES`; types `PartData`, `LightData`, `ModelData`, `Placement`, `SurfaceData`, `DecalData` |
| `kit/src/shared/ArtPlacement.luau` | Validates art placements (at/onTag, sit, allow) and the 3000-part budget | `validatePlacements(placements, models, tagCounts) -> {string}`; type `Placement` |
| `kit/src/shared/ArtFit.luau` | Pure placement maths: model box from data, `sit` Y offsets, hidden bases, floor height under a point, one box per placed copy | `LIFT`, `FLOOR_SLOP`, `FLOOR_RAY`, `modelBox(model)`, `sitY(sit, baseHeight, box)`, `hidden(placements, boxes)`, `floorY(boxes, hidden, x, z, fromY)`, `copies(placements, models, boxes)` |
| `kit/src/shared/ArtRules.luau` | Placement rules run by `tools/art_check`: doubled, sunk, flush, floating, overlap; a placement's `allow` silences named rules | `check(...) -> {string}` (one `placement <i> (<Name>): <rule>: <hint>` line per break) |
| `kit/src/shared/ArtSurface.luau` | Validates part surfaces and decals in art data | `checkSurface(s, add)`, `checkDecals(d, add)`; types `SurfaceData`, `DecalData` |
| `kit/src/server/RoundService.luau` | Drives RoundState each Heartbeat; publishes `RoundPhase` / `RoundTimeLeft` attributes on ReplicatedStorage | `start(config)`, `onPhase(phase, fn)` |
| `kit/src/server/Net.luau` | Server remotes in `ReplicatedStorage.Remotes`; drops calls failing rate limit or schema | `define(name, spec, maxPerSecond?)`, `onServer(name, handler)`, `fireClient(name, player, ...)`, `fireAll(name, ...)` |
| `kit/src/server/DataService.luau` | In-memory player data from defaults on join (no persistence yet) | `setDefaults(defaults)`, `get(player) -> table` |
| `kit/src/server/GrayboxLoader.luau` | Builds anchored Parts into a `Graybox` folder; all-or-nothing | `load(boxes, parent) -> (count, problems)` |
| `kit/src/server/ArtLoader.luau` | Rebuilds art models from `ServerStorage.Art` (meshes via `CreateMeshPartAsync`) and places them at fixed spots (`at`; `at` with `sit = "floor"` drops onto the highest visible graybox top) or on every tagged part (`onTag`, also ones added later; follows moving parts), with `sit` (`top`/`base`/`under`) choosing the height on a base. Two passes: `onTag` first, then `at`. Rebuilds surfaces and decals. Art never collides, queries or touches. All-or-nothing on invalid data; a failed mesh is skipped and reported | `load(artFolder, parent) -> (count, problems)` |
| `kit/src/server/ArtBuild.luau` | Builds art parts, surfaces and decals into a template Model; finds the floor under a point by raycast | `makePart`, `buildTemplate(name, data, problems) -> Model`, `floorHit(parent, x, y, z) -> number?`, `checkSurfaces(part, add)` |
| `kit/src/client/NetClient.luau` | Client side of `Net` remotes; waits for the remote | `fire(name, ...)`, `on(name, fn)` |
| `kit/src/client/Hud.luau` | ScreenGui showing round phase and seconds left | `start()` |
| `tools/assets/Catalog.luau` | Pure validation and lookup for the asset catalogue (index, image log) | see file header |
| `tools/assets/Serialize.luau` | Writes the asset catalogue tables as Luau source | see file header |
| `tools/assets/Shape.luau` | Shape checks for JSON handed to `asset_db` | see file header |
| `tools/assets/Finish.luau` | Moves a processed image to its status folder, logs it, rewrites index sources, drops known images | see file header |
| `tools/assets/Criteria.luau` | Checks a criteria file (name, size, prompt, source) and composes the generate prompt with regen notes | `check(c) -> string?`, `prompt(c) -> string` |
| `tools/assets/Measure.luau` | Rotation-aware box of a library model; information lines vs its criteria (no pass/fail) | `box(model) -> Box`, `compare(model, c) -> { string }` |
| `tools/assets/Discard.luau` | Deletes a discarded asset's files and entry; heals image-log names with no entry | `run(assets, index, name) -> index`, `heal(images, index) -> boolean` |
| `tools/assets/Paths.luau` | Path helpers for `asset_db` | see file header |
| `tools/assets/Review.luau` | Builds and parses `assets/REVIEW.md` (verdicts `approved` / `regen: <note>` / `discard`; `rejected` reads as regen; shows generations and measure lines) | see file header |
| `tools/assets/Wanted.luau` | Parses, queries and ticks `assets/WANTED.md` (5 per game, `### Over the limit`) | see file header |
| `tools/art/partCheck.luau` | Part-level checks shared by `art_check` and the asset tools | see file header |

## Asset tools

All take `--root <worktree>` where noted; run from the main checkout.

- `tools/asset_check.luau` — validates the library.
- `tools/asset_db.luau` — `seen|add|replace|merge|finish|drop|review|wanted|want-done|criteria|measure|regen-next|regen-failed`. `add` sets `gens = 1` for generated assets, `replace` (regen entries only) adds 1; `review` applies verdicts (regen notes go into the criteria file, `discard` removes the asset and un-ticks its wanted item) and heals the image log; `criteria <file>` writes `assets/criteria/<Name>.json`; `measure <Name>` prints and stores size/base/parts; `regen-next` prints the next queued regen; `regen-failed <Name> <why>` takes it out of the queue; `want-done` refuses names not in the library; `wanted <slug> [<Name>...]` prints what a game still waits for.
- `tools/asset_find.luau` — `[--root <dir>] [--all] <tag>...`; approved assets only unless `--all`.
- `tools/art_import.luau --library` — imports a workshop dump as a library asset (refuses an existing name unless `--replace`).
- `tools/asset_worktree.sh` — creates or finds the library worktree, prints its path.
- `tools/assets/showcase.luau` — lays assets out for review.
- `tools/art/finish.luau` — Studio module synced as `ServerStorage.ArtFinish`: `require(ArtFinish:Clone())(tag, Name, x, y, z)` takes the model `generate_mesh` tagged, empties the workshop, names parts `<Name>_n`, turns it 90° if that fits the footprint better, scales to height `y`, pivots at the bottom centre, returns a `CAMERA` line and the `ARTDUMP` line. Clone it: Studio caches `require`.
- `assets/workshop.project.json` — Rojo project for the AssetWorkshop place.
- `tools/budget_add.luau` — records agent tokens against a stage budget (`stock` has none yet: logged only; `--assets n` is written as `agent×n`).

# State

Phase: beta — fresh install.

## Done

- Factory installed.

## Next

- Run `bash tools/setup.sh` (see `README.md`).
- Type `/pitch` with a game idea paragraph.
- Drop photos of objects you want into `assets/inbox/` in the `-assets` folder, then run `/stock`.

## Known issues

- `DataService` keeps player data in memory only; games that need saved data use a game-level DataStore for now.
- Roblox's default `Baseplate` and `SpawnLocation` flicker against a graybox floor at y = 0; delete them in your test place.
- `studio-tester` needs the `studio_id` from `list_roblox_studios`; an empty id fails with "Client proxy is out of date".
- Studio caches `require` for the session, so `ArtFinish` is always required as a clone (the agent does this).
- Generated meshes lose transparency: glass renders solid.
- A ticked box in `REVIEW.md` with nothing after `verdict:` does nothing; write `approved`, `regen: <note>` or `discard`, and save the file.
- Asset engine minors: the 90° turn in `ArtFinish` has no margin for near-square objects; a discard also un-ticks accepted over-limit wanted items; a few malformed criteria files are not caught with a one-line error.

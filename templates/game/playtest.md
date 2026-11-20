# Playtest — {{slug}}

Run: `rojo serve games/{{slug}}/default.project.json`, connect the Studio plugin, Play Solo.

## What to try

- Spawn and walk around the floor.
- Wait through one full round: Lobby → Intermission → Playing → Ended → Lobby.
- From the client command bar, fire one of the game's remotes (defined with `Net.define`)
  with wrong argument types, e.g. `game.ReplicatedStorage.Remotes.<Name>:FireServer(123)`.

## What to watch

- The HUD shows the phase and seconds left, and they match the config.
- The server Output shows no errors or warnings.
- Wrong-type remote calls print nothing on the server.

## Questions for players

- What did you think you were supposed to do?
- When did you get bored, if at all?
- What would make you play another round?

## Results

| Date | Tester | Check | Pass? | Notes |
| ---- | ------ | ----- | ----- | ----- |
|      |        |       |       |       |

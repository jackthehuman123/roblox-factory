# Review checklist

Return `PASS` or a numbered list of problems with `file:line`.

1. Every remote goes through `Net.define` with a schema; no raw `RemoteEvent` handlers.
2. No client trust: the server decides outcomes (damage, currency, rewards, round results); client input is a request.
3. Connections and instances are cleaned up (player leave, round end, destroyed objects).
4. Instances found by CollectionService tags, not hard-coded paths.
5. Public APIs have types; files are `--!strict`.
6. Mobile: part count stays low; controls work with touch.
7. Every "Decided" line in the brief's feedback log is respected.
8. A game diff contains no `kit/` edits.

# Token budgets

One game ≈ 900k tokens over separate sessions.

| Stage | Agents (model) | Budget |
|---|---|---|
| `/pitch` | council-hook, council-loop (haiku), council-feasibility (sonnet) | 60k |
| `/build-core` | builder, world-builder (sonnet); reviewer (opus) once at the end | 300k |
| Playtest | studio-tester (sonnet) | 60k |
| `/log-run` | main session | 30k |
| `/dress` | art-director (sonnet) | 80k |
| `/stock` | asset-builder (sonnet), one generate_mesh per asset | no budget yet — about 21k per asset measured; logged so you can see your own average |
| Coordination | main session, per stage | 150k per game |
| Fixes reserve | any | 100k per game |

Plus: re-reviews of small fixes on haiku; per-task reviews on sonnet; opus only for the end-of-build review and kit changes. One session per stage (`/pitch`; `/build-core` + playtest; `/log-run` + `/dress`; idle `/stock`), handing off through files.

Record use with `lune run tools/budget_add <file> <stage> <agent> <model> <tokens>`; stage values live in `tools/budgets.luau`.

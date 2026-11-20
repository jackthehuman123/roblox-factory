# Training tasks

Every failure from a run becomes a practice task for the agent that failed, for later agent training.

- One file per agent: `docs/training/<agent>.md` (e.g. `builder.md`, `council-hook.md`).
- Append entries; never renumber. `T<n>` counts up within that agent's file.
- The run log's failures table links each failure to its task id.

Each entry:

```markdown
## T<n> — <short name> (run: <date>-<slug>)
Input: <what the agent was given, with paths>
Failure seen: <what went wrong>
Pass when: <checkable condition>
```

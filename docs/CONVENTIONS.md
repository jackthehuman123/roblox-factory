# Conventions

- `--!strict` at the top of every `.luau` file.
- One responsibility per ModuleScript.
- Files stay under ~200 lines; split before they grow past it.
- Public APIs are typed (parameters and returns; `export type` for shared shapes).
- Pure logic lives in Lune-testable modules (no Roblox services or datatypes); engine glue stays thin and calls them.
- The server validates every remote through `Net` (schema + rate limit). Never trust the client.
- Find instances with CollectionService tags, not hard-coded paths.
- Libraries (Signal, Janitor, persistence, …) come from Wally only, added when a feature needs them.
- Graybox and config files hold only numbers, strings, booleans and tables.

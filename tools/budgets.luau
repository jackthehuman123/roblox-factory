--!strict
-- Stage token budgets (docs/BUDGETS.md). `stock` is per asset.
return {
	pitch = 60000,
	["build-core"] = 300000,
	playtest = 60000,
	["log-run"] = 30000,
	dress = 80000,
	stock = 0, -- logged only, no budget (2026-11-20); 0 means log-only for any stage
	coordination = 150000,
	fixes = 100000,
}

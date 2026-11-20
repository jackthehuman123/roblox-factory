--!strict
-- Appends one agent's token use to a budget table and prints the stage total against its budget.
-- Usage: lune run tools/budget_add <file> <stage> <agent> <model> <tokens> [--assets <n>]
local fs = require("@lune/fs")
local process = require("@lune/process")
local budgets: { [string]: number } = require("./budgets")

local function fail(reason: string)
	print(`budget_add: {reason}`)
	process.exit(1)
end

local pos: { string } = {}
local assets = 1
local assetsGiven = false
do
	local i = 1
	while i <= #process.args do
		local a = process.args[i]
		if a == "--assets" then
			local n = tonumber(process.args[i + 1] or "")
			if n == nil or n < 1 or n ~= math.floor(n) then
				fail("--assets needs a positive integer")
			else
				assets = n
				assetsGiven = true
			end
			i += 2
		else
			table.insert(pos, a)
			i += 1
		end
	end
end

if #pos ~= 5 then
	print("usage: lune run tools/budget_add <file> <stage> <agent> <model> <tokens> [--assets <n>]")
	process.exit(1)
end
local file, stage, agent, model, tokenText = pos[1], pos[2], pos[3], pos[4], pos[5]

local base = budgets[stage]
if base == nil then
	fail(`unknown stage '{stage}'`)
end
if not string.match(tokenText, "^%d+$") then
	fail(`tokens must be a whole number, got '{tokenText}'`)
end

local text: string
if fs.isFile(file) then
	text = fs.readFile(file)
else
	local parent = string.match(file, "^(.*)/[^/]*$") or "."
	if not fs.isDir(parent) then
		fail(`directory '{parent}' does not exist`)
	end
	text = "# Token use\n\n| Stage | Agent | Model | Tokens |\n|---|---|---|---|\n"
end
if string.sub(text, -1) ~= "\n" then
	text ..= "\n"
end
-- The asset count rides in the agent cell (asset-builder×2) so per-asset averages can be read back.
text ..= `| {stage} | {agent}{if assetsGiven then `×{assets}` else ""} | {model} | {tokenText} |\n`
fs.writeFile(file, text)

if base == 0 then
	print(`{stage}: {tokenText} tokens (no budget)`)
	process.exit(0)
end

-- stock rows are one call per image batch, so each call is judged alone; other stages sum all their rows
local used = 0
for line in string.gmatch(text, "[^\n]+") do
	local s, n = string.match(line, "^| (%S+) | %S+ | %S+ | (%d+) |$")
	if s == stage then
		used += tonumber(n) :: number
	end
end
if stage == "stock" then
	used = tonumber(tokenText) :: number
end
local budget = base * (if stage == "stock" then assets else 1)
local pct = math.floor(used * 100 / budget + 0.5)
print(`{stage}: {used}/{budget} ({pct}%)`)
if used * 100 >= budget * 80 then
	print(`WARN {stage} at {pct}% of budget`)
end

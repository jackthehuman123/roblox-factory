--!strict
-- Lists library assets carrying every given tag, approved first.
-- Usage: lune run tools/asset_find [--root <dir>] [--all] <tag> [<tag> ...]
-- Prints "<Name>  <x>×<y>×<z>  <tags>" per match; --all adds unreviewed ones, marked "(unreviewed)".
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Catalog = require("./assets/Catalog")
local Review = require("./assets/Review")

local root = "."
local all = false
local tags: { string } = {}
do
	local i = 1
	while i <= #process.args do
		local a = process.args[i]
		if a == "--root" and process.args[i + 1] ~= nil then
			root = process.args[i + 1]
			i += 2
		else
			if a == "--all" then
				all = true
			else
				table.insert(tags, a)
			end
			i += 1
		end
	end
end

if #tags == 0 then
	print("usage: lune run tools/asset_find [--root <dir>] [--all] <tag> [<tag> ...]")
	process.exit(1)
end

local function load(name: string): any
	local path = `{root}/assets/{name}.luau`
	return luau.load(fs.readFile(path), { debugName = path })()
end

local vocab = Catalog.vocab(load("tags"))
for _, t in tags do
	if not vocab[t] then
		print(`asset_find: unknown tag {t}`)
		process.exit(1)
	end
end

for _, e in Catalog.find(load("index"), tags, all) do
	local line = `{e.name}  {Review.num(e.size[1])}×{Review.num(e.size[2])}×{Review.num(e.size[3])}  {table.concat(
		e.tags,
		", "
	)}`
	if e.review == "unreviewed" then
		line ..= "  (unreviewed)"
	end
	print(line)
end

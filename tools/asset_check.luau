--!strict
-- Validates the asset library (assets/index.luau, images.luau, library/*.luau).
-- Usage: lune run tools/asset_check [--root <dir>]
-- Prints nothing on success; one "<path>:1: <problem>" line per problem, then exits 1.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Art = require("../kit/src/shared/Art")
local Catalog = require("./assets/Catalog")
local partCheck = require("./art/partCheck")

local root = "."
for i, arg in process.args do
	if arg == "--root" and process.args[i + 1] ~= nil then
		root = process.args[i + 1]
	end
end
local assets = `{root}/assets`
if not fs.isDir(assets) then
	process.exit(0)
end

local function load(path: string): (boolean, any)
	return pcall(function()
		return luau.load(fs.readFile(path), { debugName = path })()
	end)
end

-- Sorted names in a folder matching a Lua pattern; capture 1 is the key.
local function list(dir: string, pattern: string): { string }
	local out: { string } = {}
	if fs.isDir(dir) then
		for _, file in fs.readDir(dir) do
			local key = string.match(file, pattern)
			if key ~= nil then
				table.insert(out, key)
			end
		end
	end
	table.sort(out)
	return out
end

local function set(names: { string }): { [string]: boolean }
	local s: { [string]: boolean } = {}
	for _, n in names do
		s[n] = true
	end
	return s
end

local problems: { { string } } = {}
local function report(path: string, msg: string)
	table.insert(problems, { path, (string.gsub(msg, "\n", " ")) })
end

local function loadTable(path: string): any
	local ok, data = load(path)
	if not ok then
		report(path, `cannot load: {data}`)
		return nil
	elseif type(data) ~= "table" then
		report(path, "must return a table")
		return nil
	end
	return data
end

local indexPath, imagesPath = `{assets}/index.luau`, `{assets}/images.luau`
local tags = loadTable(`{assets}/tags.luau`)
local index = loadTable(indexPath)
local images = loadTable(imagesPath)

local libraryNames: { string } = {}
for _, file in if fs.isDir(`{assets}/library`) then fs.readDir(`{assets}/library`) else {} do
	local name = string.match(file, "^(.+)%.luau$")
	if name ~= nil and string.match(file, "%.build%.luau$") == nil then
		table.insert(libraryNames, name)
	end
end
table.sort(libraryNames)

for _, name in libraryNames do
	local path = `{assets}/library/{name}.luau`
	local ok, data = load(path)
	if not ok then
		report(path, `cannot load: {data}`)
	else
		for _, e in Art.validateModel(name, data, partCheck) do
			report(path, e)
		end
	end
end

if tags ~= nil and index ~= nil and images ~= nil then
	local files: Catalog.Files = {
		library = set(libraryNames),
		thumbs = set(list(`{assets}/thumbs`, "^(.+)%.png$")),
		images = set(list(`{assets}/images`, "^([^.].*)$")),
		skipped = set(list(`{assets}/skipped`, "^([^.].*)$")),
	}
	for _, msg in Catalog.validate(index, images, Catalog.vocab(tags), files) do
		local lib = string.match(msg, "^library ([^:]+):")
		if lib ~= nil then
			report(`{assets}/library/{lib}.luau`, msg)
		elseif string.sub(msg, 1, 7) == "images " then
			report(imagesPath, msg)
		else
			report(indexPath, msg)
		end
	end
end

for _, p in problems do
	print(`{p[1]}:1: {p[2]}`)
end
if #problems > 0 then
	process.exit(1)
end

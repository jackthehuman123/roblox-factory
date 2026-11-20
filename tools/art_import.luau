--!strict
-- Writes an art model file from a Studio dump.
-- Usage: lune run tools/art_import <slug> <Name> <dumpfile> <source>
-- <source> is the store asset id (digits) or "generated".
-- The dump file holds the "ARTDUMP <json>" line printed by tools/art/dump.luau (or the bare JSON).
-- With --library <Name> <dumpfile> <source> [--root <dir>] [--replace] writes <root>/assets/library/<Name>.luau instead;
-- an existing file is refused unless --replace.
-- Writes games/<slug>/art/models/<Name>.luau, prints "unsupported: <item>" per item the data can't hold.
-- Exits 1 (writing nothing), printing "blocking: <item>", if the dump holds anything but Sounds and scripts the data
-- cannot express (effects, particles...). Also exits 1 if the result fails kit Art.validateModel.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Art = require("../kit/src/shared/Art")
local partCheck = require("./art/partCheck")
local convert = require("./art/convert")

local function die(msg: string): never
	print(`art_import: {msg}`)
	process.exit(1)
	error(msg)
end

local USAGE = "usage: lune run tools/art_import <slug> <Name> <dumpfile> <source>  (source = store asset id digits or generated)"
	.. "  |  --library <Name> <dumpfile> <source> [--root <dir>] [--replace]  (--root and --replace apply to --library only)"
local args: { string } = {}
local library = false
local root = "."
local replace = false
do
	local i = 1
	while i <= #process.args do
		local a = process.args[i]
		if a == "--library" then
			library = true
			i += 1
		elseif library and a == "--replace" then
			replace = true
			i += 1
		elseif library and a == "--root" and process.args[i + 1] ~= nil then
			root = process.args[i + 1]
			i += 2
		else
			table.insert(args, a)
			i += 1
		end
	end
end
if #args ~= (if library then 3 else 4) then
	die(USAGE)
end
local slug = if library then "" else args[1]
local off = if library then 0 else 1
local name, dumpFile, sourceArg = args[1 + off], args[2 + off], args[3 + off]
local source: string
if sourceArg == "generated" then
	source = "generated"
elseif string.match(sourceArg, "^%d+$") then
	source = `rbxassetid://{sourceArg}`
else
	die(USAGE)
end

local modelDir = if library then `{root}/assets/library` else `games/{slug}/art/models`
if not fs.isDir(modelDir) then
	die(`no {modelDir} ({if library then "is --root an asset library?" else "is the game wired for art?"})`)
end
if not fs.isFile(dumpFile) then
	die(`no dump file {dumpFile}`)
end

local raw = fs.readFile(dumpFile)
local json = string.match(raw, "ARTDUMP%s+(%b{})") or raw
local ok, dump = pcall(serde.decode, "json" :: any, json)
if not ok or type(dump) ~= "table" or type(dump.parts) ~= "table" then
	die(`cannot read dump: {dump}`)
end
dump.name = name
dump.source = source
dump.unsupported = dump.unsupported or {}

local src, unsupported, blocking = convert(dump)
if #blocking > 0 then
	for _, b in blocking do
		print(`blocking: {b}`)
	end
	process.exit(1)
end
local data = luau.load(src, { debugName = name })()
local errs = Art.validateModel(name, data, partCheck)
if #errs > 0 then
	for _, e in errs do
		print(`art_import: {e}`)
	end
	process.exit(1)
end

local path = `{modelDir}/{name}.luau`
if library and not replace and fs.isFile(path) then
	die(`{name} already exists`)
end
fs.writeFile(path, src)
process.exec("stylua", { path })
for _, u in unsupported do
	print(`unsupported: {u}`)
end
print(`wrote {path} ({#data.parts} parts)`)

--!strict
-- Runs kit Graybox.validate on graybox world files.
-- Usage: lune run tools/graybox_check [file ...]
-- No args: every games/*/src/server/graybox.luau plus the template's.
-- Prints nothing on success; one "<file>:1: <problem>" line per problem, then exits 1.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Graybox = require("../kit/src/shared/Graybox")

local WORLD = "src/server/graybox.luau"

local function defaultFiles(): { string }
	local files: { string } = {}
	if fs.isDir("games") then
		local names = fs.readDir("games")
		table.sort(names)
		for _, name in names do
			local path = `games/{name}/{WORLD}`
			if fs.isDir(`games/{name}`) and fs.isFile(path) then
				table.insert(files, path)
			end
		end
	end
	local template = `templates/game/{WORLD}`
	if fs.isFile(template) then
		table.insert(files, template)
	end
	return files
end

-- Returns the problems for one file (empty when valid).
local function check(path: string): { string }
	local ok, result = pcall(function()
		return luau.load(fs.readFile(path), { debugName = path })()
	end)
	if not ok then
		return { `cannot load: {result}` }
	end
	if type(result) ~= "table" then
		return { "must return a list of boxes" }
	end
	return Graybox.validate(result)
end

local files = if #process.args > 0 then process.args else defaultFiles()
local failed = false
for _, path in files do
	for _, problem in check(path) do
		failed = true
		print(`{path}:1: {(string.gsub(problem, "\n", " "))}`)
	end
end

if failed then
	process.exit(1)
end

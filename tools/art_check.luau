--!strict
-- Runs kit Art validation on game art folders.
-- Usage: lune run tools/art_check [gameDir ...]
-- No args: every games/* plus templates/game. A dir without art/ is skipped.
-- Prints nothing on success; one "<file>:1: <problem>" line per problem, then exits 1.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local Art = require("../kit/src/shared/Art")
local ArtFit = require("../kit/src/shared/ArtFit")
local ArtPlacement = require("../kit/src/shared/ArtPlacement")
local ArtRules = require("../kit/src/shared/ArtRules")
local partCheck = require("./art/partCheck")

local function defaultDirs(): { string }
	local dirs: { string } = {}
	if fs.isDir("games") then
		local names = fs.readDir("games")
		table.sort(names)
		for _, name in names do
			if fs.isDir(`games/{name}`) then
				table.insert(dirs, `games/{name}`)
			end
		end
	end
	if fs.isDir("templates/game") then
		table.insert(dirs, "templates/game")
	end
	return dirs
end

local function load(path: string): (boolean, any)
	return pcall(function()
		return luau.load(fs.readFile(path), { debugName = path })()
	end)
end

-- Loads the graybox boxes (empty list when missing or unreadable).
local function loadBoxes(dir: string): { any }
	local ok, boxes = load(`{dir}/src/server/graybox.luau`)
	if ok and type(boxes) == "table" then
		return boxes
	end
	return {}
end

-- Counts graybox boxes per tag, so onTag placements are budgeted per copy.
local function tagCounts(boxes: { any }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, box in boxes do
		if type(box) == "table" and type(box.tags) == "table" then
			for _, t in box.tags do
				if type(t) == "string" then
					counts[t] = (counts[t] or 0) + 1
				end
			end
		end
	end
	return counts
end

-- Returns { {file, problem} } for one game dir.
local function check(dir: string): { { string } }
	local out: { { string } } = {}
	local artDir = `{dir}/art`
	if not fs.isDir(artDir) then
		return out
	end
	local models: { [string]: any } = {}
	local modelDir = `{artDir}/models`
	if fs.isDir(modelDir) then
		local names = fs.readDir(modelDir)
		table.sort(names)
		for _, file in names do
			local name = string.match(file, "^(.+)%.luau$")
			if name ~= nil then
				local path = `{modelDir}/{file}`
				local ok, data = load(path)
				if not ok then
					table.insert(out, { path, `cannot load: {data}` })
				else
					models[name] = data
					for _, e in Art.validateModel(name, data, partCheck) do
						table.insert(out, { path, e })
					end
				end
			end
		end
	end
	local placementsPath = `{artDir}/placements.luau`
	if not fs.isFile(placementsPath) then
		table.insert(out, { placementsPath, "missing" })
		return out
	end
	local ok, placements = load(placementsPath)
	if not ok then
		table.insert(out, { placementsPath, `cannot load: {placements}` })
	elseif type(placements) ~= "table" then
		table.insert(out, { placementsPath, "must return a list of placements" })
	else
		local boxes = loadBoxes(dir)
		local problems = ArtPlacement.validatePlacements(placements, models, tagCounts(boxes))
		for _, e in problems do
			table.insert(out, { placementsPath, e })
		end
		if #problems == 0 and #out == 0 then
			local hidden = ArtFit.hidden(placements, boxes)
			local copies = ArtFit.copies(placements, models, boxes)
			for _, e in ArtRules.check(copies, boxes, hidden, placements) do
				table.insert(out, { placementsPath, e })
			end
		end
	end
	return out
end

local dirs = if #process.args > 0 then process.args else defaultDirs()
local failed = false
for _, dir in dirs do
	for _, item in check(dir) do
		failed = true
		print(`{item[1]}:1: {(string.gsub(item[2], "\n", " "))}`)
	end
end

if failed then
	process.exit(1)
end

--!strict
-- Records assets and processed images in assets/index.luau and assets/images.luau.
-- Usage: lune run tools/asset_db [--root <dir>] seen|add|replace|merge|finish|drop|review|wanted|want-done|criteria|measure|regen-next|regen-failed ...
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Catalog = require("./assets/Catalog")
local Serialize = require("./assets/Serialize")
local Shape = require("./assets/Shape")
local Paths = require("./assets/Paths")
local Review = require("./assets/Review")
local Finish = require("./assets/Finish")
local Wanted = require("./assets/Wanted")
local Criteria = require("./assets/Criteria")
local Measure = require("./assets/Measure")
local Discard = require("./assets/Discard")

local root = "."
local args: { string } = {}
do
	local i = 1
	while i <= #process.args do
		if process.args[i] == "--root" and process.args[i + 1] ~= nil then
			root = process.args[i + 1]
			i += 2
		else
			table.insert(args, process.args[i])
			i += 1
		end
	end
end
local assets = `{root}/assets`

local function die(msg: string): never
	print(`asset_db: {msg}`)
	process.exit(1)
end

local function load(name: string): any
	local path = `{assets}/{name}.luau`
	return luau.load(fs.readFile(path), { debugName = path })()
end

local function save(name: string, src: string)
	local path = `{assets}/{name}.luau`
	fs.writeFile(path, src)
	process.exec("stylua", { path })
end

local function hashOf(path: string): string
	local r = process.exec("shasum", { "-a", "256", "--", path })
	if not r.ok then
		die(`cannot hash {path}`)
	end
	return string.match(r.stdout, "^(%S+)") :: string
end

local function readJson(path: string): any
	if not fs.isFile(path) then
		die(`no such file {path}`)
	end
	return serde.decode("json", fs.readFile(path))
end

local function readOr(path: string): string
	return if fs.isFile(path) then fs.readFile(path) else ""
end

local function seen(path: string)
	local hit = Catalog.byHash(load("images"), hashOf(path))
	print(if hit then `processed {hit.file}` else "new")
end

-- Reads and validates an entry file. `known` says the name must (true) or must not (false) be in the index.
local function loadEntry(jsonPath: string, known: boolean): (Catalog.IndexEntry, { Catalog.IndexEntry })
	local raw = readJson(jsonPath)
	local bad = Shape.entry(raw)
	if bad ~= nil then
		die(bad)
	end
	local e: Catalog.IndexEntry = raw
	e.review = "unreviewed"
	e.reason = nil
	local index: { Catalog.IndexEntry } = load("index")
	local found = false
	for _, other in index do
		found = found or other.name == e.name
	end
	if found and not known then
		die(`{e.name} already exists`)
	elseif known and not found then
		die(`unknown asset {e.name}`)
	end
	local files = Paths.entryFiles(assets, e.sources)
	for _, msg in Catalog.validate({ e }, {}, Catalog.vocab(load("tags")), files) do
		if string.sub(msg, 1, #e.name + 7) == `index {e.name}:` then
			die(msg)
		end
	end
	return e, index
end

local function add(jsonPath: string)
	local e, index = loadEntry(jsonPath, false)
	e.gens = if e.built == "generated" then 1 else nil
	table.insert(index, e)
	save("index", Serialize.index(index))
end

-- Regen of an asset: swaps in the new entry, back to unreviewed.
local function replace(jsonPath: string)
	local e, index = loadEntry(jsonPath, true)
	for i, other in index do
		if other.name == e.name then
			if other.review ~= "regen" and other.review ~= "rejected" then
				die(`{e.name} is {other.review}, only regen entries can be replaced`)
			end
			e.gens = if e.built ~= "generated"
				then nil
				elseif other.built == "generated" then (other.gens or 1) + 1
				else 1
			index[i] = e
		end
	end
	save("index", Serialize.index(index))
	local path = `{assets}/REVIEW.md`
	fs.writeFile(path, Review.afterReplace(readOr(path), index, e.name))
end

local function merge(name: string, file: string)
	local index: { Catalog.IndexEntry } = load("index")
	if not Catalog.addSource(index, name, file) then
		die(`unknown asset {name}`)
	end
	save("index", Serialize.index(index))
end

local function finish(path: string, status: string, resultPath: string)
	if status ~= "done" and status ~= "skipped" then
		die("status must be done or skipped")
	end
	if not fs.isFile(path) then
		die(`no such image {path}`)
	end
	local result = readJson(resultPath)
	local bad = Shape.result(result)
	if bad ~= nil then
		die(bad)
	end
	local images: { Catalog.ImageEntry } = load("images")
	local index: { Catalog.IndexEntry } = load("index")
	local final = Finish.run(assets, path, status, result, hashOf(path), hashOf, images, index)
	save("images", Serialize.images(images))
	save("index", Serialize.index(index))
	print(`finished {final}`)
end

local function drop(path: string)
	if not fs.isFile(path) then
		die(`no such image {path}`)
	end
	local msg, err = Finish.drop(assets, path, hashOf(path), load("images"))
	if msg == nil then
		die(err :: string)
	end
	print(msg)
end

-- A new regen note goes into the asset's criteria notes, so the next prompt carries it.
local function addNote(name: string, note: string)
	local path = `{assets}/criteria/{name}.json`
	if note == "no reason given" or not fs.isFile(path) then
		return
	end
	local c = serde.decode("json", fs.readFile(path))
	c.notes = c.notes or {}
	table.insert(c.notes, note)
	fs.writeFile(path, serde.encode("json", c, true) .. "\n")
end

local function review()
	local path = `{assets}/REVIEW.md`
	local before: { [string]: string } = {}
	for _, e in load("index") :: { Catalog.IndexEntry } do
		before[e.name] = `{e.review}|{e.reason or ""}`
	end
	local index, count, notes, typed = Review.sync(readOr(path), load("index"))
	local discarded: { string } = {}
	for _, e in index do
		if e.review == "regen" and before[e.name] ~= `regen|{e.reason or ""}` then
			addNote(e.name, e.reason or "")
		elseif e.review == "discard" then
			table.insert(discarded, e.name)
		end
	end
	for _, name in discarded do
		index = Discard.run(assets, index, name)
		local wPath = `{assets}/WANTED.md`
		if fs.isFile(wPath) then
			fs.writeFile(wPath, Wanted.unmark(fs.readFile(wPath), name))
		end
		typed[name] = nil
	end
	save("index", Serialize.index(index))
	local images: { Catalog.ImageEntry } = load("images")
	if Discard.heal(images, index) then
		save("images", Serialize.images(images))
	end
	fs.writeFile(path, Review.render(index, typed))
	print(`review: {count} verdicts applied`)
	for _, name in discarded do
		print(`discarded {name}`)
	end
	for _, n in notes do
		print(`asset_db: ignored line {n}`)
	end
end

local function wanted(slug: string, picks: { string })
	local sections, _, notesBySlug = Wanted.parse(readOr(`{assets}/WANTED.md`))
	for _, line in Wanted.pending(sections, slug, load("index"), picks) do
		print(line)
	end
	for _, n in notesBySlug[slug] or {} do
		print(`asset_db: ignored line {n}`)
	end
end

local function wantDone(name: string)
	local inLibrary = false
	for _, e in load("index") :: { Catalog.IndexEntry } do
		inLibrary = inLibrary or e.name == name
	end
	if not inLibrary then
		die(`{name} is not in the library`)
	end
	local path = `{assets}/WANTED.md`
	local md, ok = Wanted.markDone(readOr(path), name)
	if not ok then
		die(`{name} is not wanted`)
	end
	fs.writeFile(path, md)
	print(`wanted: {name} done`)
end

-- Writes assets/criteria/<Name>.json; an existing file's notes survive a rewrite that has none.
local function criteria(jsonPath: string)
	local c = readJson(jsonPath)
	local bad = Criteria.check(c)
	if bad ~= nil then
		die(bad)
	end
	local dir = `{assets}/criteria`
	local path = `{dir}/{c.name}.json`
	if c.notes == nil and fs.isFile(path) then
		c.notes = serde.decode("json", fs.readFile(path)).notes
	elseif c.notes == nil then
		-- First criteria for an asset already marked regen: carry the user's note into the prompt.
		for _, e in load("index") :: { Catalog.IndexEntry } do
			if e.name == c.name and e.review == "regen" and e.reason ~= nil and e.reason ~= "no reason given" then
				c.notes = { e.reason }
			end
		end
	end
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	fs.writeFile(path, serde.encode("json", c, true) .. "\n")
	print(`criteria: {c.name}`)
end

local function measure(name: string)
	local index: { Catalog.IndexEntry } = load("index")
	local entry: Catalog.IndexEntry? = nil
	for _, e in index do
		if e.name == name then
			entry = e
		end
	end
	if entry == nil then
		die(`unknown asset {name}`)
	end
	local cPath = `{assets}/criteria/{name}.json`
	if not fs.isFile(cPath) then
		die(`no criteria for {name}`)
	end
	local model = load(`library/{name}`)
	local lines = Measure.compare(model, serde.decode("json", fs.readFile(cPath)));
	(entry :: Catalog.IndexEntry).measure = table.concat(lines, "\n")
	save("index", Serialize.index(index))
	print(table.concat(lines, "\n"))
end

-- A regen that produced nothing: out of the queue, back to the user with why.
local function regenFailed(name: string, why: string)
	local index: { Catalog.IndexEntry } = load("index")
	local found = false
	for _, e in index do
		if e.name == name then
			found = true
			e.review = "unreviewed"
			e.reason = nil
			e.measure = `regen failed: {why}`
		end
	end
	if not found then
		die(`unknown asset {name}`)
	end
	save("index", Serialize.index(index))
	local path = `{assets}/REVIEW.md`
	fs.writeFile(path, Review.afterReplace(readOr(path), index, name))
	print(`regen failed: {name}`)
end

-- First asset waiting for a regen, in index order; prints nothing when none.
local function regenNext()
	for _, e in load("index") :: { Catalog.IndexEntry } do
		if e.review == "regen" then
			print(e.name)
			return
		end
	end
end

local cmd = args[1]
if cmd == "seen" and args[2] then
	seen(args[2])
elseif cmd == "add" and args[2] then
	add(args[2])
elseif cmd == "replace" and args[2] then
	replace(args[2])
elseif cmd == "drop" and args[2] then
	drop(args[2])
elseif cmd == "merge" and args[2] and args[3] then
	merge(args[2], args[3])
elseif cmd == "finish" and args[2] and args[3] and args[4] then
	finish(args[2], args[3], args[4])
elseif cmd == "review" then
	review()
elseif cmd == "wanted" and args[2] then
	wanted(args[2], { table.unpack(args, 3) })
elseif cmd == "want-done" and args[2] then
	wantDone(args[2])
elseif cmd == "criteria" and args[2] then
	criteria(args[2])
elseif cmd == "measure" and args[2] then
	measure(args[2])
elseif cmd == "regen-next" then
	regenNext()
elseif cmd == "regen-failed" and args[2] and args[3] then
	regenFailed(args[2], table.concat({ table.unpack(args, 3) }, " "))
else
	die(
		"usage: seen <image> | add <entry.json> | replace <entry.json> | merge <Name> <imageFile> | finish <image> <done|skipped> <result.json> | drop <image> | review | wanted <slug> [<Name> ...] | want-done <Name> | criteria <criteria.json> | measure <Name> | regen-next | regen-failed <Name> <why>"
	)
end

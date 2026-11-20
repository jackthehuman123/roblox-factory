--!strict
-- Pure validation and lookup for the asset catalogue (assets/index.luau, images.luau).
local Catalog = {}

export type IndexEntry = {
	name: string,
	tags: { string },
	size: { number },
	sources: { string },
	built: string,
	review: string,
	note: string?,
	reason: string?,
	measure: string?, -- measuring lines from asset_db measure, newline-joined
	gens: number?, -- generate_mesh runs it took to reach this version (built = generated)
}

export type ImageEntry = {
	file: string,
	hash: string,
	status: string,
	built: { string },
	skipped: { { object: string, why: string } },
}

export type Files = {
	library: { [string]: boolean },
	thumbs: { [string]: boolean },
	images: { [string]: boolean },
	skipped: { [string]: boolean },
}

local BUILT = { code = true, generated = true, mixed = true }
local REVIEW = { unreviewed = true, approved = true, regen = true, rejected = true } -- rejected: legacy, parses as regen

function Catalog.vocab(tags: { [string]: { string } }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, group in tags do
		for _, tag in group do
			set[tag] = true
		end
	end
	return set
end

local function validName(name: string): boolean
	return string.match(name, "^[A-Z][A-Za-z0-9]*$") ~= nil
end

local function validSize(size: { number }): boolean
	if #size ~= 3 then
		return false
	end
	for _, n in size do
		if type(n) ~= "number" or n ~= n or n <= 0 or n == math.huge then
			return false
		end
	end
	return true
end

local function checkEntry(e: IndexEntry, vocab: { [string]: boolean }, files: Files, errs: { string })
	local p = `index {e.name}:`
	if not validName(e.name) then
		table.insert(errs, `{p} name must be PascalCase letters and digits`)
	end
	for _, tag in e.tags do
		if not vocab[tag] then
			table.insert(errs, `{p} unknown tag {tag}`)
		end
	end
	if #e.tags == 0 then
		table.insert(errs, `{p} needs at least one tag`)
	end
	if not validSize(e.size) then
		table.insert(errs, `{p} size must be three positive numbers`)
	end
	if #e.sources == 0 then
		table.insert(errs, `{p} needs at least one source`)
	end
	for _, source in e.sources do
		if not files.images[source] then
			table.insert(errs, `{p} source {source} not in assets/images/`)
		end
	end
	if not BUILT[e.built] then
		table.insert(errs, `{p} built must be code, generated or mixed (got {e.built})`)
	end
	if not REVIEW[e.review] then
		table.insert(errs, `{p} review must be unreviewed, approved, regen or rejected (got {e.review})`)
	end
	if (e.review == "rejected" or e.review == "regen") and (e.reason == nil or e.reason == "") then
		table.insert(errs, `{p} {e.review} needs a reason`)
	end
	if not files.library[e.name] then
		table.insert(errs, `{p} missing library model file`)
	end
	if not files.thumbs[e.name] then
		table.insert(errs, `{p} missing thumb`)
	end
end

local function checkImages(images: { ImageEntry }, names: { [string]: boolean }, files: Files, errs: { string })
	local seen: { [string]: string } = {}
	for _, img in images do
		local p = `images {img.file}:`
		if string.match(img.hash, "^%x+$") == nil or #img.hash ~= 64 then
			table.insert(errs, `{p} bad hash (need 64 hex characters)`)
		elseif seen[img.hash] then
			table.insert(errs, `{p} duplicate hash, same as {seen[img.hash]}`)
		else
			seen[img.hash] = img.file
		end
		if img.status == "done" then
			if not files.images[img.file] then
				table.insert(errs, `{p} status done but file not in images/`)
			end
		elseif img.status == "skipped" then
			if not files.skipped[img.file] then
				table.insert(errs, `{p} status skipped but file not in skipped/`)
			end
		else
			table.insert(errs, `{p} status must be done or skipped (got {img.status})`)
		end
		for _, name in img.built do
			if not names[name] then
				table.insert(errs, `{p} built {name} has no index entry`)
			end
		end
	end
end

function Catalog.validate(
	index: { IndexEntry },
	images: { ImageEntry },
	vocab: { [string]: boolean },
	files: Files
): { string }
	local errs: { string } = {}
	local names: { [string]: boolean } = {}
	for _, e in index do
		if names[e.name] then
			table.insert(errs, `index {e.name}: duplicate name`)
		end
		names[e.name] = true
		checkEntry(e, vocab, files, errs)
	end
	checkImages(images, names, files, errs)
	for name in files.library do
		if not names[name] then
			table.insert(errs, `library {name}: no index entry`)
		end
	end
	return errs
end

function Catalog.find(index: { IndexEntry }, tags: { string }, withUnreviewed: boolean): { IndexEntry }
	local out: { IndexEntry } = {}
	for _, e in index do
		local ok = e.review == "approved" or (withUnreviewed and e.review == "unreviewed")
		if ok then
			local set: { [string]: boolean } = {}
			for _, t in e.tags do
				set[t] = true
			end
			for _, t in tags do
				if not set[t] then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(out, e)
		end
	end
	table.sort(out, function(a, b)
		local aa, bb = a.review == "approved", b.review == "approved"
		if aa ~= bb then
			return aa
		end
		return a.name < b.name
	end)
	return out
end

-- Adds file to the named entry's sources once; false when the name is unknown.
function Catalog.addSource(index: { IndexEntry }, name: string, file: string): boolean
	for _, e in index do
		if e.name == name then
			if not table.find(e.sources, file) then
				table.insert(e.sources, file)
			end
			return true
		end
	end
	return false
end

function Catalog.byHash(images: { ImageEntry }, hash: string): ImageEntry?
	for _, img in images do
		if img.hash == hash then
			return img
		end
	end
	return nil
end

return Catalog

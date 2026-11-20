--!strict
-- Moves a processed image to its status folder and logs it (the work behind `asset_db finish`).
local fs = require("@lune/fs")
local Catalog = require("./Catalog")
local Paths = require("./Paths")

local Finish = {}

export type Result = { built: { string }?, skipped: { { object: string, why: string } }? }

function Finish.dirFor(assets: string, status: string): string
	return `{assets}/{if status == "done" then "images" else "skipped"}`
end

local function basename(path: string): string
	return string.match(path, "([^/]+)$") :: string
end

-- First name (file, then file-2, file-3...) that is free in dir or already holds this exact image.
local function freeName(dir: string, file: string, hash: string, hashOf: (string) -> string): string
	local stem, ext = string.match(file, "^(.*)(%.[^.]*)$")
	if stem == nil then
		stem, ext = file, ""
	end
	local name, n = file, 1
	while fs.isFile(`{dir}/{name}`) and hashOf(`{dir}/{name}`) ~= hash do
		n += 1
		name = `{stem}-{n}{ext}`
	end
	return name
end

-- Removes an inbox copy of an image that is already logged. Returns the message, or nil and the problem.
function Finish.drop(assets: string, path: string, hash: string, images: { Catalog.ImageEntry }): (string?, string?)
	local hit = Catalog.byHash(images, hash)
	if hit == nil then
		return nil, `{basename(path)} is not processed yet`
	end
	local stored = `{Finish.dirFor(assets, hit.status)}/{hit.file}`
	if Paths.samePath(path, stored) then
		return nil, `{basename(path)} is the stored copy`
	end
	if not fs.isFile(stored) then
		return nil, `stored copy of {basename(path)} missing — not dropping`
	end
	fs.removeFile(path)
	return `dropped: {basename(path)} (already processed as {hit.file})`, nil
end

-- Sources that named the image by its inbox name now name the stored file.
function Finish.rewriteSources(index: { Catalog.IndexEntry }, from: string, to: string)
	if from == to then
		return
	end
	for _, e in index do
		for i, s in e.sources do
			if s == from then
				e.sources[i] = to
			end
		end
	end
end

-- Moves files, updates images and index in place, returns the stored file name.
-- Never deletes a file whose hash differs from the image being finished.
function Finish.run(
	assets: string,
	path: string,
	status: string,
	result: Result,
	hash: string,
	hashOf: (string) -> string,
	images: { Catalog.ImageEntry },
	index: { Catalog.IndexEntry }
): string
	local existing = Catalog.byHash(images, hash)
	local dir = Finish.dirFor(assets, status)
	local final = freeName(dir, if existing then existing.file else basename(path), hash, hashOf)
	if existing ~= nil and existing.status ~= status then
		local old = `{Finish.dirFor(assets, existing.status)}/{existing.file}`
		if fs.isFile(old) and hashOf(old) == hash then
			if fs.isFile(`{dir}/{final}`) then
				fs.removeFile(old)
			else
				fs.move(old, `{dir}/{final}`)
			end
		end
	end
	local dest = `{dir}/{final}`
	if not Paths.samePath(path, dest) then
		if fs.isFile(dest) then
			fs.removeFile(path)
		else
			fs.move(path, dest)
		end
	end
	Finish.rewriteSources(index, basename(path), final)
	local entry: Catalog.ImageEntry =
		{ file = final, hash = hash, status = status, built = result.built or {}, skipped = result.skipped or {} }
	if existing ~= nil then
		images[table.find(images, existing) :: number] = entry
	else
		table.insert(images, entry)
	end
	return final
end

return Finish

--!strict
-- Removes a discarded asset: its model, thumb, criteria and index entry. Images stay logged as processed.
local fs = require("@lune/fs")
local Catalog = require("./Catalog")

local Discard = {}

function Discard.run(assets: string, index: { Catalog.IndexEntry }, name: string): { Catalog.IndexEntry }
	for _, path in { `{assets}/library/{name}.luau`, `{assets}/thumbs/{name}.png`, `{assets}/criteria/{name}.json` } do
		if fs.isFile(path) then
			fs.removeFile(path)
		end
	end
	local kept: { Catalog.IndexEntry } = {}
	for _, e in index do
		if e.name ~= name then
			table.insert(kept, e)
		end
	end
	return kept
end

-- Drops every built name that has no index entry (after a discard). Images stay logged as processed.
-- Returns whether anything changed.
function Discard.heal(images: { Catalog.ImageEntry }, index: { Catalog.IndexEntry }): boolean
	local known: { [string]: boolean } = {}
	for _, e in index do
		known[e.name] = true
	end
	local changed = false
	for _, img in images do
		local built: { string } = {}
		for _, n in img.built do
			if known[n] then
				table.insert(built, n)
			else
				changed = true
			end
		end
		img.built = built
	end
	return changed
end

return Discard

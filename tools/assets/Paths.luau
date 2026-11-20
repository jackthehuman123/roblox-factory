--!strict
-- Path helpers for asset_db.
local fs = require("@lune/fs")
local process = require("@lune/process")
local Catalog = require("./Catalog")

local Paths = {}

function Paths.names(dir: string, pattern: string): { [string]: boolean }
	local s: { [string]: boolean } = {}
	if fs.isDir(dir) then
		for _, file in fs.readDir(dir) do
			local key = string.match(file, pattern)
			if key ~= nil then
				s[key] = true
			end
		end
	end
	return s
end

-- Files an entry may reference. Source images may still be in inbox/, so pretend they exist.
function Paths.entryFiles(assets: string, sources: { string }): Catalog.Files
	local images: { [string]: boolean } = {}
	for _, s in sources do
		images[s] = true
	end
	return {
		library = Paths.names(`{assets}/library`, "^([^.]+)%.luau$"),
		thumbs = Paths.names(`{assets}/thumbs`, "^(.+)%.png$"),
		images = images,
		skipped = {},
	}
end

local function absolute(path: string): string
	local r = process.exec("sh", {
		"-c",
		'cd "$(dirname "$1")" 2>/dev/null && printf "%s/%s" "$(pwd -P)" "$(basename "$1")"',
		"_",
		path,
	})
	return if r.ok and r.stdout ~= "" then r.stdout else path
end

function Paths.samePath(a: string, b: string): boolean
	return absolute(a) == absolute(b)
end

return Paths

--!strict
-- Surface and decal data checks for one model part. The single copy for tools.
local ArtSurface = require("../../kit/src/shared/ArtSurface")

return function(part: any, add: (string) -> ())
	if part.surface ~= nil then
		ArtSurface.checkSurface(part.surface, add)
	end
	if part.decals ~= nil then
		ArtSurface.checkDecals(part.decals, add)
	end
end

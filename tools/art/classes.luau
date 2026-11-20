--!strict
-- Classes a dump can hold that change how a model looks. An unsupported item of one of these blocks an import.
local VISUAL: { [string]: boolean } = {}
for _, c in
	{
		"Part",
		"MeshPart",
		"WedgePart",
		"CornerWedgePart",
		"TrussPart",
		"UnionOperation",
		"NegateOperation",
		"IntersectOperation",
		"SpecialMesh",
		"BlockMesh",
		"CylinderMesh",
		"FileMesh",
		"SurfaceAppearance",
		"Decal",
		"Texture",
		"PointLight",
		"SpotLight",
		"SurfaceLight",
		"ParticleEmitter",
		"Beam",
		"Trail",
		"Fire",
		"Smoke",
		"Sparkles",
		"Highlight",
		"SelectionBox",
		"SurfaceGui",
		"BillboardGui",
	}
do
	VISUAL[c] = true
end
return VISUAL

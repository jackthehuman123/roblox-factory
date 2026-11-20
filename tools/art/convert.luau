--!strict
-- Pure: turns a Studio art dump (see tools/art/dump.luau) into the Luau source of an art model file.
-- Returns (source, unsupported, blocking): unsupported lists what the dump could not express, never dropped silently;
-- blocking is the visual part of it (see classes.luau) that must stop an import.

export type DumpPart = {
	class: string,
	shape: string?,
	size: { number },
	at: { number },
	rot: { number },
	color: { number },
	material: string,
	transparency: number,
	meshId: string?,
	textureId: string?,
	surface: {
		colorMap: string?,
		normalMap: string?,
		roughnessMap: string?,
		metalnessMap: string?,
		color: { number }?,
		alphaMode: string?,
	}?,
	decals: {
		{
			face: string,
			texture: string,
			color: { number }?,
			transparency: number?,
			studsU: number?,
			studsV: number?,
		}
	}?,
	light: { kind: string, brightness: number, range: number, color: { number }?, angle: number? }?,
}

export type Dump = { name: string, parts: { DumpPart }, unsupported: { string }, source: string? }

local function num(x: number, step: number): string
	local v = math.round(x / step) * step
	if v == 0 then
		v = 0 -- drop negative zero
	end
	if v == math.floor(v) then
		return string.format("%d", v)
	end
	local s = string.format("%.3f", v)
	s = string.gsub(s, "0+$", "")
	return s
end

local function triple(t: { number }, step: number): string
	return `\{ {num(t[1], step)}, {num(t[2], step)}, {num(t[3], step)} }`
end

-- Every string from a dump goes through q, so the generated source can only hold inert literals.
local function q(s: any): string
	return string.format("%q", tostring(s))
end

-- Returns (normalised id or nil, ok). ok is false for a non-empty id in an unknown form.
local function assetId(id: string?): (string?, boolean)
	if id == nil or id == "" then
		return nil, true
	end
	local digits = string.match(id, "^rbxassetid://(%d+)$")
		or string.match(id, "^https?://[%w%.]*roblox%.com/asset/%?id=(%d+)$")
	if digits == nil then
		return nil, false
	end
	return `rbxassetid://{digits}`, true
end

-- Returns the part's source, or nil and why it was dropped.
local function partSource(p: DumpPart): (string?, string?)
	local lines: { string } = {}
	local function add(s: string)
		table.insert(lines, `\t\t\t{s},`)
	end
	local meshId, meshOk = assetId(p.meshId)
	local textureId, textureOk = assetId(p.textureId)
	if not meshOk or not textureOk then
		return nil, `{p.class} with a bad asset id ({q(p.meshId)}, {q(p.textureId)})`
	end
	if meshId == nil and p.shape ~= nil and p.shape ~= "Block" then
		add(`shape = {q(p.shape)}`)
	end
	add(`size = {triple(p.size, 0.001)}`)
	add(`at = {triple(p.at, 0.001)}`)
	local r = p.rot
	if num(r[1], 0.1) ~= "0" or num(r[2], 0.1) ~= "0" or num(r[3], 0.1) ~= "0" then
		add(`rot = {triple(r, 0.1)}`)
	end
	add(`color = {triple(p.color, 1)}`)
	if p.material ~= "Plastic" then
		add(`material = {q(p.material)}`)
	end
	if num(p.transparency, 0.01) ~= "0" then
		add(`transparency = {num(p.transparency, 0.01)}`)
	end
	if meshId ~= nil then
		add(`meshId = {q(meshId)}`)
		if textureId ~= nil then
			add(`textureId = {q(textureId)}`)
		end
	end
	local sf = p.surface
	if sf ~= nil then
		local fields: { string } = {}
		for _, key in { "colorMap", "normalMap", "roughnessMap", "metalnessMap" } do
			local id, idOk = assetId((sf :: any)[key])
			if not idOk then
				return nil, `{p.class} with a bad {key} id ({q((sf :: any)[key])})`
			end
			if id ~= nil then
				table.insert(fields, `{key} = {q(id)}`)
			end
		end
		if sf.color ~= nil then
			table.insert(fields, `color = {triple(sf.color, 1)}`)
		end
		if sf.alphaMode ~= nil then
			table.insert(fields, `alphaMode = {q(sf.alphaMode)}`)
		end
		if #fields > 0 then
			add(`surface = \{ {table.concat(fields, ", ")} }`)
		end
	end
	if p.decals ~= nil and #p.decals > 0 then
		local items: { string } = {}
		for _, d in p.decals do
			local tex, texOk = assetId(d.texture)
			if not texOk then
				return nil, `{p.class} with a bad decal texture ({q(d.texture)})`
			end
			if tex == nil then
				continue -- empty texture: invisible, skip
			end
			local fields = { `face = {q(d.face)}`, `texture = {q(tex)}` }
			if d.color ~= nil then
				table.insert(fields, `color = {triple(d.color, 1)}`)
			end
			if d.transparency ~= nil and num(d.transparency, 0.01) ~= "0" then
				table.insert(fields, `transparency = {num(d.transparency, 0.01)}`)
			end
			if d.studsU ~= nil and d.studsV ~= nil then
				table.insert(fields, `studsU = {num(d.studsU, 0.001)}`)
				table.insert(fields, `studsV = {num(d.studsV, 0.001)}`)
			end
			table.insert(items, `\{ {table.concat(fields, ", ")} }`)
		end
		if #items > 0 then
			add(`decals = \{ {table.concat(items, ", ")} }`)
		end
	end
	local l = p.light
	if l ~= nil then
		local fields = { `kind = {q(l.kind)}`, `brightness = {num(l.brightness, 0.01)}`, `range = {num(l.range, 0.1)}` }
		if l.color ~= nil then
			table.insert(fields, `color = {triple(l.color, 1)}`)
		end
		if l.angle ~= nil then
			table.insert(fields, `angle = {num(l.angle, 0.1)}`)
		end
		add(`light = \{ {table.concat(fields, ", ")} }`)
	end
	return "\t\t{\n" .. table.concat(lines, "\n") .. "\n\t\t},", nil
end

local VISUAL = require("./classes")

local function convert(dump: Dump): (string, { string }, { string })
	local parts: { string } = {}
	local unsupported = table.clone(dump.unsupported or {})
	for _, p in dump.parts do
		local src, why = partSource(p)
		if src ~= nil then
			table.insert(parts, src)
		else
			table.insert(unsupported, why :: string)
		end
	end
	local blocking: { string } = {}
	for _, u in unsupported do
		if VISUAL[string.match(u, "^(%w+)") or ""] then
			table.insert(blocking, u)
		end
	end
	local sourceLine = if dump.source ~= nil then `\tsource = {q(dump.source)},\n` else ""
	local name = string.gsub(tostring(dump.name), "[^%w]", "")
	local src = table.concat({
		"--!strict",
		`-- Art model {name}: generated by tools/art_import from a Studio dump. Re-import to change it.`,
		"return {",
		sourceLine .. "\tparts = {",
		table.concat(parts, "\n"),
		"\t},",
		"}",
		"",
	}, "\n")
	return src, unsupported, blocking
end

return convert

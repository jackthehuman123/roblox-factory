--!strict
-- Pure render/parse/apply for assets/REVIEW.md, the checklist the user ticks.
local Catalog = require("./Catalog")

local Review = {}

export type Verdict = { review: string, reason: string? }

local function num(x: number): string
	local v = math.round(x / 0.01) * 0.01
	if v == 0 then
		v = 0
	end
	if v == math.floor(v) then
		return string.format("%d", v)
	end
	local s = string.format("%.3f", v)
	s = string.gsub(s, "0+$", "")
	return s
end

Review.num = num

local function gensLine(e: Catalog.IndexEntry): string
	if e.built ~= "generated" then
		return ""
	end
	return `  generations {e.gens or 1}\n`
end

local function measureLines(measure: string?): string
	if measure == nil then
		return ""
	end
	local out = {}
	for line in string.gmatch(measure, "[^\n]+") do
		table.insert(out, `  {line}\n`)
	end
	return table.concat(out)
end

local HEADER = "# Asset review\n\n"
	.. '<!-- Tick a box and write after "verdict:" one of: approved | regen: <note> | discard. '
	.. "regen makes it again once with your note; discard removes it. rejected: <reason> means regen. "
	.. "/stock copies verdicts into assets/index.luau. -->\n\n"

function Review.render(index: { Catalog.IndexEntry }, typed: { [string]: string }?): string
	local sorted = table.clone(index)
	table.sort(sorted, function(a, b)
		return a.name < b.name
	end)
	local todo, done = {}, {}
	for _, e in sorted do
		if e.review == "unreviewed" then
			local size = `{num(e.size[1])}×{num(e.size[2])}×{num(e.size[3])}`
			table.insert(
				todo,
				`- [ ] {e.name} — {table.concat(e.tags, ", ")} — {size} — from {table.concat(e.sources, ", ")} — verdict:{if typed
						and typed[e.name]
					then " " .. typed[e.name]
					else ""}\n`
					.. gensLine(e)
					.. measureLines(e.measure)
					.. `  ![{e.name}](thumbs/{e.name}.png)\n`
			)
		elseif e.review == "rejected" or e.review == "regen" then
			table.insert(
				done,
				`- [x] {e.name} — verdict: {if typed and typed[e.name]
					then typed[e.name]
					else `{e.review}: {e.reason or "no reason given"}`}\n`
			)
		else
			table.insert(
				done,
				`- [x] {e.name} — verdict: {if typed and typed[e.name] then typed[e.name] else e.review}\n`
			)
		end
	end
	return HEADER
		.. `## To check ({#todo})\n\n{table.concat(todo)}{if #todo > 0 then "\n" else ""}`
		.. `## Checked ({#done})\n\n{table.concat(done)}`
end

-- Returns verdicts, notes for ignored lines, and unrecognised typed verdict text by name.
function Review.parse(md: string): ({ [string]: Verdict }, { string }, { [string]: string })
	local verdicts: { [string]: Verdict } = {}
	local notes: { string } = {}
	local typed: { [string]: string } = {}
	for line in string.gmatch(md, "[^\n]+") do
		if string.sub(line, 1, 3) == "- [" then
			local mark, name = string.match(line, "^%- %[(.?)%] ([A-Z][A-Za-z0-9]*)%f[^A-Za-z0-9]")
			local text = string.match(line, "verdict:(.*)$")
			if mark == nil or name == nil or text == nil or (mark ~= " " and mark ~= "x" and mark ~= "X") then
				table.insert(notes, line)
			else
				text = string.gsub(text, "^%s+", "")
				text = string.gsub(text, "%s+$", "")
				local lower = string.lower(text)
				local word = string.match(lower, "^rejected%f[%A]")
					or string.match(lower, "^reject%f[%A]")
					or string.match(lower, "^regen%f[%A]")
				if word then
					local reason = string.gsub(string.sub(text, #word + 1), "^[%s:%-]+", "")
					verdicts[name] = { review = "regen", reason = if reason == "" then "no reason given" else reason }
				elseif string.match(lower, "^discard%f[%A]") then
					verdicts[name] = { review = "discard" }
				elseif string.match(lower, "^approved?%f[%A]") then
					verdicts[name] = { review = "approved" }
				elseif text == "" then
					if mark ~= " " then
						verdicts[name] = { review = "approved" }
					end
				else
					typed[name] = text
					table.insert(notes, line)
				end
			end
		end
	end
	return verdicts, notes, typed
end

function Review.apply(index: { Catalog.IndexEntry }, verdicts: { [string]: Verdict }): ({ Catalog.IndexEntry }, number)
	local count = 0
	for _, e in index do
		local v = verdicts[e.name]
		if v ~= nil and (e.review ~= v.review or e.reason ~= v.reason) then
			e.review = v.review
			e.reason = v.reason
			count += 1
		end
	end
	return index, count
end

-- Parses md and applies it; verdicts for unknown names become notes.
function Review.sync(
	md: string,
	index: { Catalog.IndexEntry }
): ({ Catalog.IndexEntry }, number, { string }, { [string]: string })
	local verdicts, notes, typed = Review.parse(md)
	local known: { [string]: boolean } = {}
	for _, e in index do
		known[e.name] = true
	end
	local applied: { [string]: Verdict } = {}
	for name, v in verdicts do
		if known[name] then
			applied[name] = v
		else
			table.insert(notes, `unknown asset {name}`)
		end
	end
	local out, count = Review.apply(index, applied)
	return out, count, notes, typed
end

-- REVIEW.md re-rendered after a replace: that name's old line is gone and it is listed unreviewed.
function Review.afterReplace(md: string, index: { Catalog.IndexEntry }, name: string): string
	local _, _, typed = Review.parse(md)
	typed[name] = nil
	return Review.render(index, typed)
end

return Review

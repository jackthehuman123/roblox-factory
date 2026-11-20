--!strict
-- Pure parse/query/tick for assets/WANTED.md, the list of library assets games still need.
local Catalog = require("./Catalog")

local Wanted = {}

Wanted.LIMIT = 5

Wanted.HEADER = "# Wanted assets\n"
	.. "<!-- art-director adds what a game needs that the library lacks. Drop reference images for these into assets/inbox/\n"
	.. "     (name the file after the item if you can). /stock ticks an item when it builds a matching asset.\n"
	.. "     /dress waits while its game has unticked items or picks that aren't approved yet. -->\n"

export type Item = { name: string, done: boolean, over: boolean, accepted: boolean, text: string }

local ITEM = "^%- %[(.?)%] ([A-Z][A-Za-z0-9]*) — (.*)$"

local function marked(mark: string): boolean
	return mark == "x" or mark == "X"
end

-- Returns sections, every garbled line, and the garbled lines of each section by slug.
function Wanted.parse(md: string): ({ [string]: { Item } }, { string }, { [string]: { string } })
	local sections: { [string]: { Item } } = {}
	local notes: { string } = {}
	local bySlug: { [string]: { string } } = {}
	local current: { Item }? = nil
	local currentSlug = ""
	local over = false
	for line in string.gmatch(md, "[^\n]+") do
		local slug = string.match(line, "^## (%S+)%s*$")
		if slug ~= nil then
			current = sections[slug] or {}
			currentSlug = slug
			sections[slug] = current
			over = false
		elseif string.match(line, "^### Over the limit%s*$") then
			over = true
		elseif string.sub(line, 1, 3) == "- [" then
			local mark, name, text = string.match(line, ITEM)
			if current == nil or mark == nil or name == nil or (mark ~= " " and not marked(mark)) then
				table.insert(notes, line)
				if current ~= nil then
					bySlug[currentSlug] = bySlug[currentSlug] or {}
					table.insert(bySlug[currentSlug], line)
				end
			else
				local on = marked(mark)
				table.insert(
					current,
					{ name = name, done = on and not over, over = over, accepted = on and over, text = text }
				)
			end
		end
	end
	return sections, notes, bySlug
end

function Wanted.pending(
	sections: { [string]: { Item } },
	slug: string,
	index: { Catalog.IndexEntry },
	picks: { string }
): { string }
	local items = sections[slug] or {}
	local out: { string } = {}
	local normal = 0
	for _, it in items do
		if not it.over then
			normal += 1
		end
	end
	if normal > Wanted.LIMIT then
		table.insert(
			out,
			`limit: {slug} lists {normal} wanted items, max {Wanted.LIMIT} — move extras under ### Over the limit`
		)
	end
	for _, it in items do
		if it.over and not it.accepted then
			table.insert(out, `decide {it.name}: over the limit — tick to accept or delete to drop`)
		end
	end
	for _, it in items do
		if (not it.over and not it.done) or it.accepted then
			table.insert(out, `wanted {it.name}: {it.text}`)
		end
	end
	local byName: { [string]: Catalog.IndexEntry } = {}
	for _, e in index do
		byName[e.name] = e
	end
	local names: { string } = {}
	local listed: { [string]: boolean } = {}
	for _, it in items do
		if it.done and not listed[it.name] then
			listed[it.name] = true
			table.insert(names, it.name)
		end
	end
	for _, name in picks do
		if not listed[name] then
			listed[name] = true
			table.insert(names, name)
		end
	end
	local missing: { string } = {}
	for _, name in names do
		local e = byName[name]
		if e == nil then
			table.insert(missing, `missing {name}`)
		elseif e.review == "rejected" then
			table.insert(out, `rejected {name}: {e.reason or "no reason given"} — re-pick`)
		elseif e.review == "regen" then
			table.insert(out, `regen {name}: waiting on /stock`)
		elseif e.review ~= "approved" then
			table.insert(out, `review {name}`)
		end
	end
	table.move(missing, 1, #missing, #out + 1, out)
	return out
end

local function isHeading(line: string): boolean
	return string.match(line, "^## %S+%s*$") ~= nil
end

-- Ticks the item as built in every game section that wants it, moving an accepted over-limit item into its
-- game's normal list.
function Wanted.markDone(md: string, name: string): (string, boolean)
	local lines: { string } = {}
	for line in string.gmatch(md, "([^\n]*)\n?") do
		table.insert(lines, line)
	end
	if lines[#lines] == "" then
		table.remove(lines)
	end
	local targets: { { at: number, accepted: boolean, last: number } } = {}
	local last, over = 0, false
	local hit: { at: number, accepted: boolean }? = nil
	local function flush()
		if hit ~= nil then
			table.insert(targets, { at = hit.at, accepted = hit.accepted, last = last })
		end
		hit = nil
	end
	for i, line in lines do
		if isHeading(line) then
			flush()
			last, over = i, false
		elseif string.match(line, "^### Over the limit%s*$") then
			over = true
		else
			local mark, n = string.match(line, ITEM)
			if mark ~= nil and n ~= nil and (mark == " " or marked(mark)) then
				if not over then
					last = i
				end
				if hit == nil and n == name and (if over then marked(mark) else mark == " ") then
					hit = { at = i, accepted = over }
				end
			end
		end
	end
	flush()
	if #targets == 0 then
		return md, false
	end
	local done = `- [x] {name} — built`
	for k = #targets, 1, -1 do
		local t = targets[k]
		if not t.accepted then
			lines[t.at] = done
		else
			table.remove(lines, t.at)
			table.insert(lines, if t.last > t.at then t.last else t.last + 1, done)
		end
	end
	return table.concat(lines, "\n") .. "\n", true
end

-- Unticks every built line for the name (after a discard), so /dress waits for a new image.
function Wanted.unmark(md: string, name: string): string
	local out: { string } = {}
	for line in string.gmatch(md, "([^\n]*)\n?") do
		local mark, n = string.match(line, ITEM)
		if mark ~= nil and n == name and marked(mark) then
			line = `- [ ] {name} — discarded; drop a new reference image`
		end
		table.insert(out, line)
	end
	if out[#out] == "" then
		table.remove(out)
	end
	return table.concat(out, "\n") .. "\n"
end

return Wanted

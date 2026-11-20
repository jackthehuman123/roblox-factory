--!strict
local Catalog = require("../../tools/assets/Catalog")
local Wanted = require("../../tools/assets/Wanted")

local function entry(name: string, review: string): Catalog.IndexEntry
	return { name = name, tags = { "home" }, size = { 1, 1, 1 }, sources = { "a.png" }, built = "code", review = review }
end

local MD = [[
# Wanted assets
<!-- header -->

## game-a
- [ ] Gurney — hospital, old — rusted gurney
- [x] Lamp — built

### Over the limit
- [ ] Sofa — big sofa
- [x] Rug — round rug

## game-b
- [ ] Vase — tall vase
]]

local function has(s: string, part: string): boolean
	return string.find(s, part, 1, true) ~= nil
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("parse sections and marks", function()
		local s, notes = Wanted.parse(MD)
		assert(#notes == 0, "notes")
		local a = s["game-a"]
		assert(#a == 4 and #s["game-b"] == 1, "counts")
		assert(not a[1].done and not a[1].over and not a[1].accepted, "normal unticked")
		assert(a[1].text == "hospital, old — rusted gurney", "text")
		assert(a[2].done and not a[2].over and not a[2].accepted, "normal ticked")
		assert(not a[3].done and a[3].over and not a[3].accepted, "over unticked")
		assert(not a[4].done and a[4].over and a[4].accepted, "over ticked")
	end)

	test("garbled lines become notes", function()
		local _, notes = Wanted.parse("## g\n- [x]\n- [ ] lowercase name — x\n")
		assert(#notes == 2, `notes {#notes}`)
	end)

	test("ready when empty", function()
		local s = Wanted.parse("## g\n- [x] Lamp — built\n")
		assert(
			#Wanted.pending(s, "g", { entry("Lamp", "approved"), entry("Bed", "approved") }, { "Bed" }) == 0,
			"ready"
		)
		assert(#Wanted.pending(s, "none", {}, {}) == 0, "no section")
	end)

	test("waits on wanted, decide, review, missing", function()
		local s = Wanted.parse(MD)
		local out = Wanted.pending(s, "game-a", { entry("Lamp", "unreviewed") }, { "Ghost" })
		assert(#out == 5, `got {#out}: {table.concat(out, "|")}`)
		assert(has(out[1], "decide Sofa: over the limit"), out[1])
		assert(out[2] == "wanted Gurney: hospital, old — rusted gurney", out[2])
		assert(has(out[3], "wanted Rug: round rug"), out[3])
		assert(out[4] == "review Lamp", out[4])
		assert(out[5] == "missing Ghost", out[5])
	end)

	test("done item without index entry is missing", function()
		local s = Wanted.parse("## g\n- [x] Lamp — built\n")
		assert(Wanted.pending(s, "g", {}, {})[1] == "missing Lamp", "missing")
	end)

	test("limit", function()
		local md = "## game-a\n"
		for i = 1, 6 do
			md ..= `- [x] Item{i} — built\n`
		end
		local out = Wanted.pending(Wanted.parse(md), "game-a", {}, {})
		assert(string.sub(out[1], 1, 22) == "limit: game-a lists 6 ", out[1])
	end)

	test("accepted over item counts as wanted", function()
		local out = Wanted.pending(Wanted.parse(MD), "game-a", {}, {})
		local joined = table.concat(out, "\n")
		assert(has(joined, "wanted Rug:") and not has(joined, "decide Rug"), joined)
	end)

	test("markDone normal", function()
		local md, ok = Wanted.markDone(MD, "Gurney")
		assert(ok and has(md, "- [x] Gurney — built\n"), md)
		assert(has(md, "- [ ] Sofa — big sofa") and has(md, "- [ ] Vase"), "others untouched")
	end)

	test("markDone accepted over", function()
		local md, ok = Wanted.markDone(MD, "Rug")
		assert(ok, "ok")
		assert(has(md, "- [x] Lamp — built\n- [x] Rug — built\n\n### Over the limit"), md)
		assert(not has(md, "round rug"), "old line removed")
		local s = Wanted.parse(md)
		assert(s["game-a"][3].name == "Rug" and s["game-a"][3].done, "now normal")
	end)

	test("markDone unknown", function()
		local md, ok = Wanted.markDone(MD, "Sofa")
		assert(not ok and md == MD, "unticked over is not wanted yet")
		local md2, ok2 = Wanted.markDone(MD, "Nope")
		assert(not ok2 and md2 == MD, "unknown")
	end)

	test("markDone ticks every game section that wants it", function()
		local md0 = "## a\n- [ ] Lamp — l\n- [ ] Bed — b\n\n## b\n- [ ] Lamp — l\n\n## c\n- [ ] Vase — v\n"
		local md, ok = Wanted.markDone(md0, "Lamp")
		assert(ok, "ok")
		local s = Wanted.parse(md)
		assert(s["a"][1].done and s["b"][1].done, md)
		assert(not s["a"][2].done and not s["c"][1].done, "others untouched")
	end)

	test("markDone ticks accepted over items in several sections", function()
		local md0 =
			"## a\n- [ ] Bed — b\n\n### Over the limit\n- [x] Rug — r\n\n## b\n- [ ] Cot — c\n\n### Over the limit\n- [x] Rug — r\n"
		local md, ok = Wanted.markDone(md0, "Rug")
		assert(ok, "ok")
		local s = Wanted.parse(md)
		assert(s["a"][2].name == "Rug" and s["a"][2].done and not s["a"][2].over, md)
		assert(s["b"][2].name == "Rug" and s["b"][2].done and not s["b"][2].over, md)
	end)

	test("rejected entry asks for a re-pick", function()
		local s = Wanted.parse("## g\n- [x] Lamp — built\n")
		local rejected = entry("Lamp", "rejected")
		rejected.reason = "too small"
		local bed = entry("Bed", "rejected")
		bed.reason = "ugly"
		local out = Wanted.pending(s, "g", { rejected, bed }, { "Bed" })
		assert(#out == 2, table.concat(out, "|"))
		assert(out[1] == "rejected Lamp: too small — re-pick", out[1])
		assert(out[2] == "rejected Bed: ugly — re-pick", out[2])
	end)

	test("notes are kept per section", function()
		local _, all, by = Wanted.parse("## a\n- [x]\n\n## b\n- [ ] Bed — ok\n- [ ] lower — x\n")
		assert(#all == 2, "all")
		assert(#by["a"] == 1 and #by["b"] == 1, "per slug")
		assert(by["c"] == nil, "no section")
	end)
	test("unmark both sections", function()
		local md = Wanted.unmark("## a\n- [x] Lamp — built\n\n## b\n- [ ] Bed — b\n- [x] Lamp — built\n", "Lamp")
		local count = 0
		for _ in string.gmatch(md, "%- %[ %] Lamp — discarded; drop a new reference image") do
			count += 1
		end
		assert(count == 2, md)
		assert(not has(md, "[x] Lamp"), md)
		assert(has(md, "- [ ] Bed — b"), md)
	end)

	test("regen pick waits on stock", function()
		local s = Wanted.parse("## g\n- [x] Lamp — built\n")
		local lamp = entry("Lamp", "regen")
		lamp.reason = "too shiny"
		local out = Wanted.pending(s, "g", { lamp }, {})
		assert(#out == 1 and out[1] == "regen Lamp: waiting on /stock", table.concat(out, "|"))
	end)
end

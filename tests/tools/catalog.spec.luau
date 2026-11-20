--!strict
local Catalog = require("../../tools/assets/Catalog")

local HASH = string.rep("a", 64)
local vocab = Catalog.vocab({
	setting = { "home" },
	room = { "bedroom" },
	kind = { "furniture", "plant" },
	era = { "modern" },
})

local function entry(name: string): Catalog.IndexEntry
	return {
		name = name,
		tags = { "home", "bedroom", "furniture" },
		size = { 3.6, 2.1, 7 },
		sources = { "bed.png" },
		built = "code",
		review = "unreviewed",
	}
end

local function image(): Catalog.ImageEntry
	return { file = "bed.png", hash = HASH, status = "done", built = { "QuiltedNavySingleBed" }, skipped = {} }
end

local function files(): Catalog.Files
	return {
		library = { QuiltedNavySingleBed = true },
		thumbs = { QuiltedNavySingleBed = true },
		images = { ["bed.png"] = true },
		skipped = {},
	}
end

local function joined(errs: { string }): string
	return table.concat(errs, "; ")
end

local function has(errs: { string }, needle: string)
	local text = joined(errs)
	assert(string.find(text, needle, 1, true), `expected "{needle}" in: {text}`)
end

local function check(e: Catalog.IndexEntry, f: Catalog.Files?): { string }
	return Catalog.validate({ e }, { image() }, vocab, f or files())
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("valid catalogue has no errors", function()
		local errs = check(entry("QuiltedNavySingleBed"))
		assert(#errs == 0, joined(errs))
	end)

	test("empty library is valid", function()
		local errs = Catalog.validate({}, {}, vocab, { library = {}, thumbs = {}, images = {}, skipped = {} })
		assert(#errs == 0, joined(errs))
	end)

	test("bad name", function()
		has(check(entry("quilted-bed")), "name")
	end)

	test("duplicate name", function()
		local errs = Catalog.validate(
			{ entry("QuiltedNavySingleBed"), entry("QuiltedNavySingleBed") },
			{ image() },
			vocab,
			files()
		)
		has(errs, "duplicate")
	end)

	test("unknown tag", function()
		local e = entry("QuiltedNavySingleBed")
		e.tags = { "home", "spooky" }
		has(check(e), "spooky")
	end)

	test("bad size", function()
		local e = entry("QuiltedNavySingleBed")
		e.size = { 1, 0, 2 }
		has(check(e), "size")
	end)

	test("source missing from images", function()
		local f = files()
		f.images = {}
		has(check(entry("QuiltedNavySingleBed"), f), "bed.png")
	end)

	test("bad built and review", function()
		local e = entry("QuiltedNavySingleBed")
		e.built = "magic"
		e.review = "maybe"
		local errs = check(e)
		has(errs, "built")
		has(errs, "review")
	end)

	test("rejected needs reason", function()
		local e = entry("QuiltedNavySingleBed")
		e.review = "rejected"
		has(check(e), "reason")
		e.reason = "too bright"
		local errs = check(e)
		assert(#errs == 0, joined(errs))
	end)

	test("regen needs reason", function()
		local e = entry("QuiltedNavySingleBed")
		e.review = "regen"
		has(check(e), "regen needs a reason")
		e.reason = "too shiny"
		local errs = check(e)
		assert(#errs == 0, joined(errs))
	end)

	test("discard is not a stored review state", function()
		local e = entry("QuiltedNavySingleBed")
		e.review = "discard"
		has(check(e), "review must be unreviewed, approved, regen or rejected")
	end)

	test("missing model or thumb", function()
		local f = files()
		f.library = {}
		f.thumbs = {}
		local errs = check(entry("QuiltedNavySingleBed"), f)
		has(errs, "library")
		has(errs, "thumb")
	end)

	test("library file without entry", function()
		local f = files()
		f.library.Orphan = true
		has(check(entry("QuiltedNavySingleBed"), f), "Orphan")
	end)

	test("image log problems", function()
		local bad = image()
		bad.hash = "xyz"
		local errs = Catalog.validate({ entry("QuiltedNavySingleBed") }, { bad }, vocab, files())
		has(errs, "hash")

		local a, b = image(), image()
		b.file = "other.png"
		b.built = {}
		local f = files()
		f.images["other.png"] = true
		has(Catalog.validate({ entry("QuiltedNavySingleBed") }, { a, b }, vocab, f), "duplicate hash")

		local f2 = files()
		f2.images = { ["bed.png"] = nil }
		f2.skipped = { ["bed.png"] = true }
		local wrong = Catalog.validate({}, { image() }, vocab, f2)
		assert(string.find(joined(wrong), "images/", 1, true), joined(wrong))

		local ghost = image()
		ghost.built = { "QuiltedNavySingleBed", "GhostLamp" }
		has(Catalog.validate({ entry("QuiltedNavySingleBed") }, { ghost }, vocab, files()), "GhostLamp")
	end)

	test("find filters, sorts and ANDs tags", function()
		local approved, unrev, rej, other = entry("ZBed"), entry("ABed"), entry("MBed"), entry("Desk")
		approved.review = "approved"
		rej.review = "rejected"
		other.review = "approved"
		other.tags = { "home", "plant" }
		local index = { unrev, rej, approved, other }

		local got = Catalog.find(index, { "home", "bedroom" }, false)
		assert(#got == 1 and got[1].name == "ZBed", "approved only")

		got = Catalog.find(index, { "home", "bedroom" }, true)
		assert(#got == 2 and got[1].name == "ZBed" and got[2].name == "ABed", "approved first")

		got = Catalog.find(index, { "home" }, true)
		assert(#got == 3 and got[1].name == "Desk" and got[2].name == "ZBed" and got[3].name == "ABed", "sorted")
	end)

	test("byHash finds and misses", function()
		local imgs = { image() }
		local hit = Catalog.byHash(imgs, HASH)
		assert(hit and hit.file == "bed.png", "hit")
		assert(Catalog.byHash(imgs, string.rep("b", 64)) == nil, "miss")
	end)
end

--!strict
local Catalog = require("../../tools/assets/Catalog")
local Review = require("../../tools/assets/Review")

local function entry(name: string, review: string, reason: string?): Catalog.IndexEntry
	return {
		name = name,
		tags = { "home", "bedroom" },
		size = { 3.6, 2.1, 7 },
		sources = { "a.png", "b.png" },
		built = "code",
		review = review,
		reason = reason,
	}
end

local function has(s: string, part: string): boolean
	return string.find(s, part, 1, true) ~= nil
end

return function(test: (name: string, fn: () -> ()) -> ())
	test("render empty", function()
		local s = Review.render({})
		assert(has(s, "## To check (0)"), "to check")
		assert(has(s, "## Checked (0)"), "checked")
	end)

	test("render sorts and sizes", function()
		local s = Review.render({
			entry("Zed", "unreviewed"),
			entry("Bed", "unreviewed"),
			entry("Cot", "approved"),
			entry("Dot", "rejected", "ugly"),
		})
		assert(has(s, "## To check (2)"), "count")
		assert(
			has(
				s,
				"- [ ] Bed — home, bedroom — 3.6×2.1×7 — from a.png, b.png — verdict:\n  ![Bed](thumbs/Bed.png)"
			),
			s
		)
		assert(has(s, "- [x] Cot — verdict: approved\n"), s)
		assert(has(s, "- [x] Dot — verdict: rejected: ugly"), s)
		assert((string.find(s, "Bed", 1, true) :: number) < (string.find(s, "Zed", 1, true) :: number), "order")
	end)

	test("parse approved / rejected with reason / rejected bare / tick only / unticked empty", function()
		local v, notes = Review.parse(
			"- [x] Aa — verdict: approved\n"
				.. "- [ ] Bb — x — verdict: rejected: too tall \n"
				.. "- [ ] Cc — verdict: rejected\n"
				.. "- [x] Dd — verdict:\n"
				.. "- [ ] Ee — verdict:\n"
		)
		assert(v.Aa.review == "approved", "Aa")
		assert(v.Bb.review == "regen" and v.Bb.reason == "too tall", "Bb")
		assert(v.Cc.review == "regen" and v.Cc.reason == "no reason given", "Cc")
		assert(v.Dd.review == "approved", "Dd")
		assert(v.Ee == nil, "Ee")
		assert(#notes == 0, "notes")
	end)

	test("garbled lines", function()
		local v, notes = Review.parse("- [x]\n- [?] lowercase thing verdict: approved\n")
		assert(next(v) == nil, "verdicts")
		assert(#notes == 2, "notes " .. #notes)
	end)

	test("apply", function()
		local index = { entry("Bed", "unreviewed"), entry("Cot", "unreviewed") }
		local out, n = Review.apply(index, { Bed = { review = "approved" }, Nope = { review = "approved" } })
		assert(n == 1, "count")
		assert(out[1].review == "approved" and out[2].review == "unreviewed", "changed")
	end)

	test("case and word forms", function()
		local v, notes = Review.parse(
			"- [x] Aa — verdict: Approved\n"
				.. "- [ ] Bb — verdict: Rejected: ugly\n"
				.. "- [ ] Cc — verdict: approve\n"
				.. "- [ ] Dd — verdict: reject: x\n"
				.. "- [ ] Ee — verdict: rejected too tall\n"
				.. "- [ ] Ff — verdict: rejected - slim\n"
		)
		assert(v.Aa.review == "approved" and v.Cc.review == "approved", "approve")
		assert(v.Bb.reason == "ugly" and v.Dd.reason == "x", "reject")
		assert(v.Ee.reason == "too tall" and v.Ff.reason == "slim", "no colon")
		assert(#notes == 0, "notes")
	end)

	test("unrecognised verdict survives re-render", function()
		local md = "- [ ] Bed — verdict: maybe later\n"
		local _, notes, typed = Review.parse(md)
		assert(#notes == 1 and typed.Bed == "maybe later", "typed")
		local out = Review.render({ entry("Bed", "unreviewed") }, typed)
		assert(has(out, "verdict: maybe later\n"), out)
		local v2, n2, t2 = Review.parse(out)
		assert(next(v2) == nil and #n2 == 1 and t2.Bed == "maybe later", "reparse")
	end)

	test("sync idempotent and counts only changes", function()
		local index = { entry("Bed", "unreviewed") }
		local md = "- [ ] Bed — verdict: rejected: ugly\n"
		local i1, n1, _, t1 = Review.sync(md, index)
		assert(n1 == 1, "first")
		local md2 = Review.render(i1, t1)
		local i2, n2, _, t2 = Review.sync(md2, i1)
		assert(n2 == 0 and Review.render(i2, t2) == md2, "second")
	end)
	test("parse regen", function()
		local v = Review.parse("- [x] Bed — verdict: regen: too shiny\n")
		assert(v.Bed.review == "regen" and v.Bed.reason == "too shiny", "regen")
	end)

	test("parse regen no note", function()
		local v = Review.parse("- [x] Bed — verdict: regen\n")
		assert(v.Bed.review == "regen" and v.Bed.reason == "no reason given", "bare regen")
	end)

	test("parse rejected is regen", function()
		local v = Review.parse("- [x] Bed — verdict: rejected: blocky\n")
		assert(v.Bed.review == "regen" and v.Bed.reason == "blocky", "alias")
	end)

	test("parse discard", function()
		local v = Review.parse("- [x] Bed — verdict: discard\n")
		assert(v.Bed.review == "discard" and v.Bed.reason == nil, "discard")
	end)

	test("render regen", function()
		local s = Review.render({ entry("Bed", "regen", "too shiny") })
		assert(has(s, "## Checked (1)"), s)
		assert(has(s, "- [x] Bed — verdict: regen: too shiny\n"), s)
	end)

	test("render measure", function()
		local e = entry("Bed", "unreviewed")
		e.measure = "size 2×3.5×2 (criteria 2×3.5×2)\nparts 6"
		e.built = "generated"
		e.gens = 2
		local s = Review.render({ e })
		assert(
			has(
				s,
				"— verdict:\n  generations 2\n  size 2×3.5×2 (criteria 2×3.5×2)\n  parts 6\n  ![Bed](thumbs/Bed.png)\n"
			),
			s
		)
	end)

	test("render generations default", function()
		local gen = entry("Bed", "unreviewed")
		gen.built = "generated"
		assert(has(Review.render({ gen }), "  generations 1\n"), "generated without gens counts 1")
		assert(not has(Review.render({ entry("Cot", "unreviewed") }), "generations"), "code-built shows none")
	end)
end

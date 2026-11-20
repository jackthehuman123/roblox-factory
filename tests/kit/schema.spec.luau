--!strict
local Schema = require("../../kit/src/shared/Schema")

return function(test: (name: string, fn: () -> ()) -> ())
	local spec = { "number", "string" }

	test("matching args pass", function()
		assert(Schema.check(spec, { 1, "x" }) == true, "expected true")
	end)

	test("wrong types fail", function()
		assert(Schema.check(spec, { "x", 1 }) == false, "expected false")
	end)

	test("too few args fail", function()
		assert(Schema.check(spec, { 1 }) == false, "expected false")
	end)

	test("too many args fail", function()
		assert(Schema.check(spec, { 1, "x", 2 }) == false, "expected false")
	end)

	test("NaN fails", function()
		assert(Schema.check({ "number" }, { 0 / 0 }) == false, "expected false")
	end)

	test("infinity fails", function()
		assert(Schema.check({ "number" }, { math.huge }) == false, "expected false for inf")
		assert(Schema.check({ "number" }, { -math.huge }) == false, "expected false for -inf")
	end)
end

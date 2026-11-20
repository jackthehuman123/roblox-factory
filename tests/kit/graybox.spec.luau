--!strict
local Graybox = require("../../kit/src/shared/Graybox")

return function(test: (name: string, fn: () -> ()) -> ())
	test("a valid box has no errors", function()
		local errs = Graybox.validate({
			{
				size = { 4, 1, 4 },
				at = { 0, 0, 0 },
				rot = 45,
				color = { 0, 128, 255 },
				material = "Concrete",
				tags = { "Spawn" },
			},
		})
		assert(#errs == 0, `expected 0 errors, got {#errs}: {table.concat(errs, "; ")}`)
	end)

	test("bad box lists every problem with its index", function()
		local errs = Graybox.validate({
			{ size = { 0, 1, 1 }, at = { 0, 0 } :: any, color = { 300, 0, 0 }, material = "Plastic" },
		})
		assert(#errs == 4, `expected 4 errors, got {#errs}: {table.concat(errs, "; ")}`)
		for _, e in errs do
			assert(string.sub(e, 1, 6) == "box 1:", `bad prefix: {e}`)
		end
	end)

	test("index points at the bad box", function()
		local errs = Graybox.validate({
			{ size = { 1, 1, 1 }, at = { 0, 0, 0 } },
			{ size = { 1, 1, 1 }, at = { 0, 0, 0 }, tags = { 5 } :: any },
		})
		assert(#errs == 1 and string.sub(errs[1], 1, 6) == "box 2:", `got {table.concat(errs, "; ")}`)
	end)
end

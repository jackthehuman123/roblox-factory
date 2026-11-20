--!strict
local RateLimit = require("../../kit/src/shared/RateLimit")

return function(test: (name: string, fn: () -> ()) -> ())
	test("allows maxCalls per window then blocks", function()
		local l = RateLimit.new(3, 1)
		assert(l:allow("a", 0), "call 1")
		assert(l:allow("a", 0), "call 2")
		assert(l:allow("a", 0), "call 3")
		assert(not l:allow("a", 0), "call 4 should be blocked")
	end)

	test("keys are independent", function()
		local l = RateLimit.new(3, 1)
		for _ = 1, 4 do
			l:allow("a", 0)
		end
		assert(l:allow("b", 0), "b should be allowed")
	end)

	test("a new window resets the count", function()
		local l = RateLimit.new(3, 1)
		for _ = 1, 4 do
			l:allow("a", 0)
		end
		assert(l:allow("a", 1), "a should be allowed in the next window")
	end)
end

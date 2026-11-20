--!strict
return function(test: (name: string, fn: () -> ()) -> ())
	test("one plus one is two", function()
		assert(1 + 1 == 2, "expected 1 + 1 == 2")
	end)
end

--!strict
-- Discovers tests/**/*.spec.luau, runs each test in pcall.
-- Prints nothing on success; one "<file>: <test>: <error>" line per failure.
local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOT = "tests"

local function collect(dir: string, out: { string })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			collect(path, out)
		elseif string.sub(name, -10) == ".spec.luau" then
			table.insert(out, path)
		end
	end
end

local specs: { string } = {}
collect(ROOT, specs)

local failures = 0
for _, path in specs do
	-- require is relative to this file (tests/), so strip "tests/" and ".luau"
	local modulePath = "./" .. string.sub(path, #ROOT + 2, -6)
	local ok, spec = pcall(require, modulePath)
	if not ok then
		failures += 1
		print(`{path}: <load>: {spec}`)
	elseif type(spec) ~= "function" then
		failures += 1
		print(`{path}: <load>: spec must return a function`)
	else
		spec(function(name: string, fn: () -> ())
			local passed, err = pcall(fn)
			if not passed then
				failures += 1
				print(`{path}: {name}: {err}`)
			end
		end)
	end
end

if failures > 0 then
	process.exit(1)
end

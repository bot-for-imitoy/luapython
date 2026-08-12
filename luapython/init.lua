local loader = require("luapython.loader")

-- It is not recommanded to call native method directly,
-- but we still keep it for advanced users who want to manage the loading process manually.
-- loader.loadNative = nil

-- Run a command and return (success, stdout) — works on Lua 5.1+.
local function exec_capture(cmd)
    local ok = os.execute(cmd .. " > /dev/null 2>&1")
    -- Lua 5.1 returns exit code (0 = success), 5.2+ returns boolean
    if type(ok) == "number" then ok = ok == 0 end
    if not ok then return false, nil end
    local handle = io.popen(cmd)
    if not handle then return false, nil end
    local out = handle:read("*a")
    handle:close()
    return true, out
end

function loader.load(version, lib_prefix)
	-- When called without arguments, auto-detect libpython path via sysconfig
	if version == nil and lib_prefix == nil then
		local ok, out = exec_capture([[python3 -c "
import sysconfig, os, glob
d = sysconfig.get_config_var('LIBDIR')
if d:
    pattern = os.path.join(d, 'libpython*.so*')
    files = sorted(glob.glob(pattern))
    if files:
        import os.path as op
        print(op.realpath(files[-1]))
"]])
		if ok and out then
			local path = out:gsub("%s+$", "")
			if path ~= "" then
				loader.loadNative(path)
				local core = require("luapython.core")
				local luapython = loader
				for k, v in pairs(core) do
					luapython[k] = v
				end
				luapython.initialize()
				return path
			end
		end
	end

	-- Fallback: manual construction using exec-prefix + version
	if not lib_prefix then
		local ok, out = exec_capture("python3-config --exec-prefix")
		if ok then
			lib_prefix = out:gsub("%s+$", "") .. "/lib"
		else
			lib_prefix = ""
		end
	end
	if type(version) == "number" then
		version = tostring(version)
	elseif type(version) == "nil" then
		local ok, out = exec_capture("python3 --version")
		if ok then
			local version_extract = string.match(out, "%d+%.%d+")
			if version_extract then
				version = version_extract  -- keep as string, don't tonumber (preserves "3.10")
			else
				version = "3"
			end
		else
			version = "3"
		end
	elseif type(version) ~= "string" then
		error("core.load: version: string expected, got" .. type(version))
	end
	if lib_prefix ~= "" then
		lib_prefix = lib_prefix .. "/"
	end
	local path = lib_prefix .. "libpython" .. version .. ".so"
	loader.loadNative(path)
	local core = require("luapython.core")
	local luapython = loader
	for k, v in pairs(core) do
		luapython[k] = v
	end
	luapython.initialize()
	return path
end

return loader
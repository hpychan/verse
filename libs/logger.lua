local select, tostring = select, tostring;
local io_write = io.write;
module "logger"

local function format(format, ...)
	local n, maxn = 0, #arg;
	return (format:gsub("%%(.)", function (c) if c ~= "%" and n <= maxn then n = n + 1; return tostring(arg[n]); end end));
end

local function format(format, ...)
	local n, maxn = 0, select('#', ...);
	local arg = { ... };
	return (format:gsub("%%(.)", function (c) if n <= maxn then n = n + 1; return tostring(arg[n]); end end));
end

function init(name)
	return function (level, message, ...)
		io_write(level, "\t", format(message, ...), "\n");
	end
end

return _M;

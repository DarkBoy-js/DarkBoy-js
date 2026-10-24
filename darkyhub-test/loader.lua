-- DarkyHub testing loader: report compile failures instead of calling nil
local url = "https://raw.githubusercontent.com/DarkBoy-js/DarkBoy-js/main/darkyhub-test/DarkyHub.lua"
local source = game:HttpGet(url)
assert(type(source) == "string" and #source > 0, "DarkyHub: download returned no Lua source")
local scriptFunction, compileError = loadstring(source)
assert(scriptFunction, "DarkyHub compile error: " .. tostring(compileError))
local success, runtimeError = xpcall(scriptFunction, function(err)
    return debug and debug.traceback and debug.traceback(tostring(err), 2) or tostring(err)
end)
if not success then error("DarkyHub runtime error: " .. tostring(runtimeError), 0) end

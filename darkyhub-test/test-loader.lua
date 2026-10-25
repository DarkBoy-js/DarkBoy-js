-- DarkyHub TEST Loader v1.0
-- TEST ONLY: does not modify the private/main DarkyHub repository
local base="https://raw.githubusercontent.com/DarkBoy-js/DarkBoy-js/main/darkyhub-test/"
local env=type(getgenv)=="function" and getgenv() or _G
env.DarkyHubTestLoaderVersion="1.0"
local function start(name)
 local ok,source=pcall(function()return game:HttpGet(base..name.."?v=20261025-test1")end)
 if not ok then warn("[DarkyHub TEST Loader] Download failed:",name,source);return false end
 local fn,err=loadstring(source)
 if not fn then warn("[DarkyHub TEST Loader] Compile failed:",name,err);return false end
 local ran,why=pcall(fn)
 if not ran then warn("[DarkyHub TEST Loader] Runtime error:",name,why);return false end
 print("[DarkyHub TEST Loader] loaded",name)
 return true
end
-- The test navigator itself loads DarkyHub's public test copy.
local a=start("DarkyHub_TEST.lua")
local b=start("RemoteLab.lua")
if not a or not b then warn("[DarkyHub TEST Loader] One or more modules failed; check console")end

--[[
 DarkyHub v5.9 | Candy Kingdom TD / Roblox tower-defense macro hub
 Scoped-module Luau build. RightShift toggles menu; placement minimizes the hub.

 NOTE: Roblox games use different remotes, button names and unit models.
       Teach actions in the Home / Spy tabs. Remote spying requires
       hookmetamethod + getnamecallmethod + checkcaller in your executor.
       Server-authoritative placement success cannot be verified generically.

 Structure: Core / Store / Codec / Map / Spy / Markers / Macro / Detect /
            Actions / Automations / Player / UI / Lifecycle
--]]
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = (getgenv and getgenv()) or _G
if type(env.DarkyHubUnload) == "function" then pcall(env.DarkyHubUnload) end

-- ======================================================================
--  CORE
-- ======================================================================
local Core = { alive = true, connections = {}, log = {}, logMax = 100 }
local function connect(signal, handler)
    local c = signal:Connect(handler)
    table.insert(Core.connections, c)
    return c
end
local function log(message)
    local line = os.date("%H:%M:%S") .. "  " .. tostring(message)
    table.insert(Core.log, 1, line)
    if #Core.log > Core.logMax then table.remove(Core.log) end
    print("[DarkyHub v5.3] " .. tostring(message))
end
local function safeCall(fn, ...)
    local ok, value = pcall(fn, ...)
    if not ok then log("ERROR: " .. tostring(value)) end
    return ok, value
end
local function lower(s) return string.lower(tostring(s or "")) end
local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end
local function clean(s)
    return string.upper(trim(tostring(s or ""):gsub("<[^>]*>", "")))
end
local function fmtNumber(n)
    local s = tostring(math.floor(n or 0))
    return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function new(class, props, parent)
    local o = Instance.new(class)
    for key, value in pairs(props or {}) do o[key] = value end
    if parent then o.Parent = parent end
    return o
end
local function corner(instance, radius)
    new("UICorner", { CornerRadius = UDim.new(0, radius or 7) }, instance)
end
local function safeName(name)
    local v = tostring(name or ""):gsub("[^%w_%- ]", "_")
    v = trim(v):sub(1, 60)
    return v ~= "" and v or "Default"
end
local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
end
local GUI
local function getStat(names)
    local ls = player:FindFirstChild("leaderstats")
    for _, name in ipairs(names) do
        local v = ls and ls:FindFirstChild(name)
        if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v.Value end
        local attr = player:GetAttribute(name)
        if type(attr) == "number" then return attr end
    end
    return nil
end
local function sortedKeys(t)
    local out = {}
    for k in pairs(t or {}) do table.insert(out, k) end
    table.sort(out)
    return out
end

-- ======================================================================
--  STORE: human-named dungeon/map profiles, explicit save feedback
-- ======================================================================
local Store = {}
Store.root = "DarkyHubV4"
Store.playerId = tostring(player.UserId)
Store.playerName = player.DisplayName ~= "" and player.DisplayName or player.Name
Store.settingsFile = Store.root .. "/players/" .. Store.playerId .. "/settings.json"
Store.hasMigratedSettings = false
Store.hasFS = type(readfile) == "function" and type(writefile) == "function"
    and type(makefolder) == "function" and type(isfolder) == "function"
    and type(listfiles) == "function"
Store.settings = {
    autoRaid = false, isRaidMatch = false, raidSolo = true, raidMinMilk = 1, raidStage = "", raidNextStage = true,
    raidReturnOnDefeat = true, raidAutoEnter = false,
    raidMilkPerNextStage = 1, raidMilkManual = 0, raidRequireKnownMilk = false,
    raidReturnWhenOutOfMilk = false, raidMaxNextAttempts = 3,
    raidKeepMapProfile = true,
    autoShop = false, shopAutoOpen = false, shopItems = "", shopMaxPerReset = 1, shopInterval = 8,
    webhookEnabled = false, webhookUrl = "", webhookWaves = true, webhookWaveEvery = 10,
    webhookResults = true, webhookDisconnect = true,
    placementByWave = false, remoteOnly = true, allowScreenFallback = true, useRecordedCamera = true, minPlacementCash = 0,

    autoPlay = false, autoSkip = false, autoUpgrade = false,
    manualUnitTarget = 0, -- 0 means macro/manual-confirm gate is required
    stopWaveEnabled = false, stopWaveNumber = 100,
    stopWaveSell = true, stopWaveReplay = true,
    stopWaveMaxSellAttempts = 3, stopWaveSellDelay = 1.0,
    individualUpgradeFallback = true,
    matchMode = "INF / Story", modeProfiles = {},
    uiTheme = "Midnight", uiScale = 1, uiGlow = true, uiCompact = false,
    resultMode = "Off", autoJoin = false, autoChallenge = false,
    autoSummon = false, autoTrait = false, claimDaily = false,
    claimBP = false, claimLevel = false, showMarkers = true,
    upgradeInterval = 1.8, placementDelay = 2, fixedStepDelay = 0.75,
    playbackMode = "Fixed", summonDelay = 3, keepGems = 0,
    traitDelay = 4, traitMaxRolls = 25, traitTarget = "",
    expectedPlacements = 0, mapOverride = "", activeMap = "",
    selectedMacro = "", maxPlacementAttempts = 3, maxMacroPasses = 3, retryInterval = 2,
    replayOnDefeat = true, captureClickFallback = true, selectedSlot = 1,
    challengeStage = "",
    unitContainer = "", verification = "Smart", matchScanInterval = 1.2,
    walkEnabled = false, walkSpeed = 32, infiniteJump = false,
    noclip = false, fly = false, flySpeed = 60,
    autoReconnect = false, antiAFK = true,
}
Store.actions = { slots = {}, join = {}, challenge = {}, placementTemplate = nil }
Store.macros = {}
Store.mapNames = {}
Store.mapConfig = {}
local function directory(path)
    if not Store.hasFS then return false end
    local exists, result = pcall(isfolder, path)
    if exists and result then return true end
    local ok, err = pcall(makefolder, path)
    if not ok then log("Folder error " .. path .. ": " .. tostring(err)) end
    return ok
end
local function initializeFolders()
    if not Store.hasFS then return false end
    return directory(Store.root) and directory(Store.root .. "/maps")
        and directory(Store.root .. "/players")
        and directory(Store.root .. "/players/" .. Store.playerId)
end
local function readJSON(path)
    if not Store.hasFS then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    return ok and type(data) == "table" and data or nil
end
local function writeJSON(path, data)
    if not Store.hasFS then log("SAVE BLOCKED: executor has no file API"); return false end
    if not initializeFolders() then return false end
    local ok, err = pcall(function() writefile(path, HttpService:JSONEncode(data)) end)
    if not ok then log("SAVE ERROR " .. path .. ": " .. tostring(err)) end
    return ok
end
function Store.load()
    initializeFolders()
    local s = readJSON(Store.settingsFile)
    -- Existing users keep their original settings on first launch, then diverge.
    if not s then
        s = readJSON(Store.root .. "/settings.json") or readJSON("DarkyHubV3/settings.json")
        Store.hasMigratedSettings = true
    end
    if s then
        for key, oldValue in pairs(Store.settings) do
            if type(s[key]) == type(oldValue) then Store.settings[key] = s[key] end
        end
    end
    local a = readJSON(Store.root .. "/actions.json") or readJSON("DarkyHubV3/actions.json")
    if a then
        for _, k in ipairs({ "slots", "join", "challenge" }) do
            Store.actions[k] = type(a[k]) == "table" and a[k] or {}
        end
        Store.actions.placementTemplate = type(a.placementTemplate) == "table"
            and a.placementTemplate or nil
    end
    local index = readJSON(Store.root .. "/map_index.json") or readJSON("DarkyHubV3/map_index.json")
    if index and type(index.names) == "table" then
        for _, name in ipairs(index.names) do
            if type(name) == "string" and name ~= "" then
                Store.mapNames[name] = true
            end
        end
    end
end
local saveRevision = 0
function Store.saveSettings()
    saveRevision = saveRevision + 1
    local rev = saveRevision
    task.delay(0.5, function()
        if Core.alive and rev == saveRevision then
            writeJSON(Store.settingsFile, Store.settings)
        end
    end)
end
function Store.saveActions()
    return writeJSON(Store.root .. "/actions.json", Store.actions)
end
function Store.mapFolder(key)
    local dir = Store.root .. "/maps/" .. safeName(key)
    return directory(dir) and dir or nil
end
function Store.registerMap(name)
    name = trim(name)
    if name == "" then return false end
    Store.mapNames[name] = true
    local names = sortedKeys(Store.mapNames)
    return writeJSON(Store.root .. "/map_index.json", { names = names })
end
function Store.loadMap(key)
    if Store.macros[key] then return Store.macros[key] end
    local data = {}
    Store.macros[key] = data
    if not Store.hasFS then return data end
    local folder = Store.mapFolder(key)
    if not folder then return data end
    local ok, files = pcall(listfiles, folder)
    if ok and #files == 0 then
        local old = "DarkyHubV3/maps/" .. safeName(key)
        local exists, isOld = pcall(isfolder, old)
        if exists and isOld then ok, files = pcall(listfiles, old) end
    end
    if not ok then log("Map listing failed: " .. tostring(files)); return data end
    for _, path in ipairs(files) do
        if lower(path):sub(-5) == ".json" and not lower(path):find("map_settings.json", 1, true) then
            local m = readJSON(path)
            if m and type(m.steps) == "table" then
                local name = m.name or path:gsub("^.*[/\\]", ""):gsub("%.json$", "")
                data[name] = m
            end
        end
    end
    return data
end
function Store.saveMacro(key, name, data)
    -- Even with no executor disk API, allow testing a macro in memory.
    -- Report that it is NOT persistent so users never mistake this for a save.
    local folder = Store.mapFolder(key)
    local written = folder and writeJSON(folder .. "/" .. safeName(name) .. ".json", data) or false
    Store.macros[key] = Store.macros[key] or {}
    Store.macros[key][name] = data
    Store.mapNames[key] = true
    if written then Store.registerMap(key) end
    return true, written == true
end
function Store.deleteMacro(key, name)
    local folder = Store.mapFolder(key)
    if folder and Store.hasFS and type(delfile) == "function" then
        pcall(delfile, folder .. "/" .. safeName(name) .. ".json")
    end
    if Store.macros[key] then Store.macros[key][name] = nil end
end
function Store.loadMapConfig(key)
    local dir = Store.mapFolder(key)
    local cfg = dir and (readJSON(dir .. "/map_settings.json")
        or readJSON("DarkyHubV3/maps/" .. safeName(key) .. "/map_settings.json"))
    Store.mapConfig = type(cfg) == "table" and cfg or {}
end
function Store.saveMapConfig(key)
    local dir = Store.mapFolder(key)
    if dir then return writeJSON(dir .. "/map_settings.json", Store.mapConfig) end
    return false
end
Store.load()
if Store.hasMigratedSettings and Store.hasFS then writeJSON(Store.settingsFile, Store.settings) end

-- ======================================================================
--  CODEC: round-trip remote arguments into JSON
-- ======================================================================
local Codec = {}
function Codec.path(instance)
    local parts = {}
    local obj = instance
    while obj and obj ~= game do
        table.insert(parts, 1, obj.Name)
        obj = obj.Parent
    end
    return parts
end
function Codec.resolve(parts)
    if type(parts) ~= "table" then return nil end
    local obj = game
    for _, segment in ipairs(parts) do
        obj = obj and obj:FindFirstChild(segment)
        if not obj then return nil end
    end
    return obj
end
function Codec.encode(v, depth, seen)
    depth, seen = depth or 0, seen or {}
    if depth > 12 then return { _t = "cut" } end
    local t = typeof(v)
    if t == "nil" then return { _t = "nil" } end
    if t == "string" or t == "boolean" then return v end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return { _t = "nil" } end
        return v
    end
    if t == "Vector3" then return { _t = "V3", a = { v.X, v.Y, v.Z } } end
    if t == "Vector2" then return { _t = "V2", a = { v.X, v.Y } } end
    if t == "CFrame" then return { _t = "CF", a = { v:GetComponents() } } end
    if t == "Color3" then return { _t = "C3", a = { v.R, v.G, v.B } } end
    if t == "UDim2" then return { _t = "U2", a = { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } } end
    if t == "EnumItem" then return { _t = "Enum", a = { tostring(v.EnumType), v.Name } } end
    if t == "Instance" then return { _t = "Inst", a = Codec.path(v) } end
    if t == "table" then
        if seen[v] then return { _t = "cut" } end
        seen[v] = true
        local pairsOut, count = {}, 0
        for k, value in pairs(v) do
            count = count + 1
            if count > 150 then break end
            table.insert(pairsOut, { Codec.encode(k, depth + 1, seen), Codec.encode(value, depth + 1, seen) })
        end
        seen[v] = nil
        return { _t = "Table", a = pairsOut }
    end
    return { _t = "nil" }
end
function Codec.decode(v)
    if type(v) ~= "table" then return v end
    local t, a = v._t, v.a
    if t == "nil" or t == "cut" then return nil end
    if t == "V3" then return Vector3.new(unpack(a)) end
    if t == "V2" then return Vector2.new(unpack(a)) end
    if t == "CF" then return CFrame.new(unpack(a)) end
    if t == "C3" then return Color3.new(unpack(a)) end
    if t == "U2" then return UDim2.new(a[1], a[2], a[3], a[4]) end
    if t == "Inst" then return Codec.resolve(a) end
    if t == "Enum" then
        local ok, result = pcall(function()
            return Enum[a[1]:gsub("^Enum%.", "")][a[2]]
        end)
        return ok and result or nil
    end
    if t == "Table" then
        local out = {}
        for _, pair in ipairs(a or {}) do
            local k = Codec.decode(pair[1])
            if k ~= nil then out[k] = Codec.decode(pair[2]) end
        end
        return out
    end
    return nil
end
function Codec.encodeArgs(args)
    local encoded = { n = args.n or #args, a = {} }
    for i = 1, encoded.n do encoded.a[i] = Codec.encode(args[i]) end
    return encoded
end
function Codec.decodeArgs(args)
    if type(args) ~= "table" then return table.pack() end
    local out = { n = tonumber(args.n) or 0 }
    for i = 1, out.n do out[i] = Codec.decode((args.a or {})[i]) end
    return out
end
function Codec.call(snapshot)
    if type(snapshot) ~= "table" then return false, "Missing action", nil end
    -- Hybrid placement: prefer real server remotes; use the client's normal input
    -- path for older position-only macros. This is input simulation, not a
    -- server-side spawn API. Screen projection requires a stable camera.
    if snapshot.method == "ScreenPlace" then
        if Store.settings.remoteOnly and not Store.settings.allowScreenFallback then
            return false, "Screen-click step disabled (enable Hybrid screen fallback)", false
        end
        local camera = workspace.CurrentCamera
        local xyz, slot = snapshot.pos, tonumber(snapshot.slot)
        if not camera or type(xyz) ~= "table" or not slot or slot < 1 or slot > 6 then
            return false, "Missing saved world position, camera or unit slot", false
        end
        local key = ({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
            Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six })[slot]
        local oldType, oldCF, oldFov = camera.CameraType, camera.CFrame, camera.FieldOfView
        local usedCamera = Store.settings.useRecordedCamera and type(snapshot.cameraCF) == "table"
            and #snapshot.cameraCF == 12
        local ok, reason = pcall(function()
            if usedCamera then
                camera.CameraType = Enum.CameraType.Scriptable
                camera.CFrame = CFrame.new(unpack(snapshot.cameraCF))
                if tonumber(snapshot.cameraFov) then camera.FieldOfView = snapshot.cameraFov end
                task.wait(0.12)
            end
            local point, inView = camera:WorldToViewportPoint(Vector3.new(unpack(xyz)))
            if not inView or point.Z <= 0 then error("World position outside camera view") end
            -- Temporarily hide the hub so it cannot absorb the simulated click.
            local hubWasEnabled = GUI and GUI.Enabled
            if GUI then GUI.Enabled = false end
            local fired, err = pcall(function()
                VIM:SendKeyEvent(true, key, false, game)
                VIM:SendKeyEvent(false, key, false, game)
                task.wait(0.24)
                -- Roblox input coordinates can differ from viewport coordinates
                -- by GUI inset; the viewport values are the best initial guess.
                VIM:SendMouseMoveEvent(point.X, point.Y, game)
                task.wait(0.16)
                VIM:SendMouseButtonEvent(point.X, point.Y, 0, true, game, 0)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(point.X, point.Y, 0, false, game, 0)
            end)
            if GUI then GUI.Enabled = hubWasEnabled end
            if not fired then error(tostring(err)) end
        end)
        if usedCamera then
            camera.CameraType = oldType
            camera.CFrame = oldCF
            camera.FieldOfView = oldFov
        end
        return ok, ok and "Input sent; checking tower occupancy" or tostring(reason), nil
    end
    local remote = Codec.resolve(snapshot.path or snapshot.r)
    if not remote then return false, "Remote path not found: " .. table.concat(snapshot.path or snapshot.r or {}, "."), nil end
    local method = snapshot.method or snapshot.m
    local args = Codec.decodeArgs(snapshot.args or snapshot.a)
    if method == "FireServer" and remote:IsA("RemoteEvent") then
        local ok, err = pcall(function() remote:FireServer(unpack(args, 1, args.n)) end)
        return ok, ok and "Sent; server acceptance unknown" or tostring(err), nil
    elseif method == "InvokeServer" and remote:IsA("RemoteFunction") then
        local ok, result = pcall(function() return remote:InvokeServer(unpack(args, 1, args.n)) end)
        if not ok then return false, tostring(result), false end
        if result == false then return false, "Server rejected placement", false end
        return true, "Invoked", result == true and true or nil
    end
    return false, "Remote/method mismatch", false
end


-- ======================================================================
--  MAP: select a readable profile explicitly when game doesn't expose names
-- ======================================================================
local Map = { name = "", key = "", changedAt = 0, autoName = "" }
local function knownMapName(root)
    if not root then return nil end
    for _, attr in ipairs({ "MapName", "CurrentMap", "StageName", "SelectedMap", "LevelName", "DungeonName" }) do
        local v = root:GetAttribute(attr)
        if type(v) == "string" and trim(v) ~= "" then return trim(v) end
    end
    for _, name in ipairs({ "MapName", "CurrentMap", "StageName", "LevelName" }) do
        local obj = root:FindFirstChild(name)
        if obj and obj:IsA("StringValue") and trim(obj.Value) ~= "" then return trim(obj.Value) end
    end
end
function Map.detect()
    local name = knownMapName(workspace) or knownMapName(ReplicatedStorage)
    if name then return name end
    for _, rootName in ipairs({ "Map", "CurrentMap", "ActiveMap" }) do
        local root = workspace:FindFirstChild(rootName)
        if root then
            name = knownMapName(root)
            if name then return name end
            local children = root:GetChildren()
            if #children == 1 and (children[1]:IsA("Model") or children[1]:IsA("Folder")) then
                return children[1].Name
            end
        end
    end
    return nil
end
function Map.refresh()
    local detected = Map.detect()
    Map.autoName = detected or "Not detected"
    local chosen = trim(Store.settings.mapOverride)
    if chosen == "" then chosen = detected or trim(Store.settings.activeMap) end
    if chosen == "" then chosen = "Unnamed Dungeon - Set Map Name" end
    if chosen == Map.key then return false end
    Map.name, Map.key, Map.changedAt = chosen, chosen, os.clock()
    Store.settings.activeMap = chosen
    Store.loadMap(chosen)
    Store.loadMapConfig(chosen)
    log("Map profile: " .. chosen .. " (detected: " .. Map.autoName .. ")")
    return true
end
function Map.choose(name)
    name = trim(name)
    if name == "" then return false end
    Store.settings.mapOverride = name
    Store.settings.activeMap = name
    Store.registerMap(name)
    Store.saveSettings()
    return Map.refresh()
end
Map.refresh()

-- ======================================================================
--  SPY: passive remote logging and learn-on-next-manual-action
-- ======================================================================
local Spy = { available = false, enabled = false, events = {}, max = 90,
              selected = 1, selectedEvent = nil, learn = nil, changed = 0 }
local ignore = { "ping", "heartbeat", "analytics", "camera", "cursor", "mousemove", "chat", "telemetry" }
function Spy.ignored(name)
    local v = lower(name)
    for _, word in ipairs(ignore) do
        if v:find(word, 1, true) then return true end
    end
    return false
end
local function summaryArg(v)
    local t = typeof(v)
    if t == "string" then return string.format("%q", v:sub(1, 36)) end
    if t == "Vector3" then return string.format("(%.1f %.1f %.1f)", v.X, v.Y, v.Z) end
    if t == "CFrame" then return "CFrame " .. summaryArg(v.Position) end
    if t == "Instance" then return v.ClassName .. ":" .. v.Name end
    if t == "table" then return "{table}" end
    return tostring(v)
end
function Spy.describe(args)
    local pieces = {}
    for i = 1, math.min(args.n or 0, 6) do
        table.insert(pieces, summaryArg(args[i]))
    end
    return table.concat(pieces, ", ")
end
local function snapshot(remote, method, args)
    return { path = Codec.path(remote), method = method, args = Codec.encodeArgs(args) }
end
local function isValidPosition(p)
    return p and typeof(p) == "Vector3"
        and p.X == p.X and p.Y == p.Y and p.Z == p.Z and p.Magnitude < 1000000
end
local function positionOf(value, depth, visited)
    if depth > 6 then return nil end
    local t = typeof(value)
    if t == "Vector3" then return isValidPosition(value) and value or nil end
    if t == "CFrame" then return isValidPosition(value.Position) and value.Position or nil end
    if t == "table" then
        if visited[value] then return nil end
        visited[value] = true
        local x, y, z = value.x or value.X, value.y or value.Y, value.z or value.Z
        if type(x) == "number" and type(y) == "number" and type(z) == "number" then
            local p = Vector3.new(x, y, z)
            if isValidPosition(p) then return p end
        end
        for _, key in ipairs({ "Position", "position", "WorldPosition", "worldPosition", "Pos", "pos",
            "Placement", "placement", "Pivot", "pivot", "Transform", "transform", "CFrame", "cframe", "cf", "location" }) do
            if value[key] ~= nil then
                local p = positionOf(value[key], depth + 1, visited)
                if p then return p end
            end
        end
        if type(value[1]) == "number" and type(value[2]) == "number"
            and type(value[3]) == "number" then
            local p = Vector3.new(value[1], value[2], value[3])
            if isValidPosition(p) then return p end
        end
        for _, val in pairs(value) do
            local p = positionOf(val, depth + 1, visited)
            if p then return p end
        end
    end
    return nil
end
function Spy.placementPosition(args)
    -- Prefer CFrame / Vector3 arguments over random numbers in unrelated payloads.
    for i = 1, args.n or 0 do
        local val = args[i]
        if typeof(val) == "CFrame" or typeof(val) == "Vector3" then
            local p = positionOf(val, 0, {})
            if p then return { p.X, p.Y, p.Z } end
        end
    end
    for i = 1, args.n or 0 do
        local p = positionOf(args[i], 0, {})
        if p then return { p.X, p.Y, p.Z } end
    end
    return nil
end

local function classify(remote, args)
    local text = lower(remote.Name)
    for i = 1, math.min(args.n or 0, 3) do
        if type(args[i]) == "string" then text = text .. " " .. lower(args[i]) end
    end
    if text:find("place", 1, true) or text:find("spawnunit", 1, true)
        or text:find("deploy", 1, true) then return "place" end
    if text:find("upgrade", 1, true) or text:find("levelup", 1, true) then return "upgrade" end
    if text:find("sell", 1, true) then return "sell" end
    if text:find("skip", 1, true) or text:find("startwave", 1, true) then return "wave" end
    return "other"
end

-- Forward references for recorder
local Detect -- forward declaration: stamping placement steps with the actual wave
local Macro = { recording = nil, playing = false, playToken = 0, step = "-",
    placementDone = false, dispatchedPlacements = 0, expectedPlacements = 0,
    lastRunStarted = -1, selected = nil, currentStep = nil,
    failures = 0, attempts = 0, unverified = 0, lastFailure = "" }
local Actions = {}
local uiNotify = function(msg) log(msg) end

local function samePath(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
local function stringSignature(action)
    local encoded = (action.args or {}).a or {}
    local result = {}
    for i = 1, math.min(#encoded, 4) do
        local v = encoded[i]
        if type(v) == "string" then
            local low = lower(v)
            if low:find("place", 1, true) or low:find("deploy", 1, true)
                or low:find("spawn", 1, true) then
                result[i] = v
            end
        end
    end
    return result
end
function Spy.matchesPlacement(action, kind)
    local template = Store.actions.placementTemplate
    if not template then return kind == "place" end
    if action.method ~= template.method or not samePath(action.path, template.path) then
        return false
    end
    for i, value in pairs(template.signature or {}) do
        if ((action.args or {}).a or {})[i] ~= value then return false end
    end
    return true
end
local function makePlacementStep(event, started)
    if not event.pos then return nil, "No world position in remote arguments" end
    local step = shallowCopy(event.action)
    step.t = math.max(0, event.time - started)
    step.kind = "place"
    step.wave = (Detect and Detect.wave) or 1
    step.pos = event.pos
    step.unit = "Tower"
    local args = (event.action.args or {}).a or {}
    for _, arg in ipairs(args) do
        if type(arg) == "string" and #arg > 1 and #arg < 50 and not lower(arg):find("place", 1, true) then
            step.unit = arg; break
        end
    end
    return step
end
function Spy.captureSelectedPlacement()
    local event = Spy.selectedEvent
    if not event then uiNotify("SPY: select the actual PLACE remote in the list") return end
    if not event.pos then
        uiNotify("Selected remote has NO position; select the placement call with Vector3/CFrame")
        return
    end
    Store.actions.placementTemplate = {
        path = event.action.path, method = event.action.method,
        signature = stringSignature(event.action),
    }
    local saved = Store.saveActions()
    if Macro.recording then
        local already = false
        for _, step in ipairs(Macro.recording.steps) do
            if step._eventTime == event.time then already = true; break end
        end
        if not already then
            local step = makePlacementStep(event, Macro.recording.started)
            step._eventTime = event.time
            table.insert(Macro.recording.steps, step)
            Macro.recording.placements = Macro.recording.placements + 1
        end
    end
    uiNotify("PLACE remote selected: " .. event.name .. (saved and " [saved]" or " [memory only]"))
end
-- Screen-click fallback for games which do not expose placement remotes to the hook.
-- The user selects a tower with hotkeys 1-6 and clicks the ground normally.
-- If a matching remote placement arrives, the fallback click is discarded.
local SLOT_KEYS = {
    [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
}
connect(UIS.InputBegan, function(input, used)
    if not Core.alive or used then return end
    local keySlot = SLOT_KEYS[input.KeyCode]
    if keySlot then
        Store.settings.selectedSlot = keySlot
        return
    end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local rec = Macro.recording
    if not rec then return end
    -- Track the manual click for automatic remote matching and a position-only draft.
    -- This does not move the pointer during playback.
    rec.pendingClickTime = os.clock()
    if not Store.settings.captureClickFallback then return end
    local mouse = player:GetMouse()
    if not mouse or not mouse.Target then return end
    local hit = mouse.Hit
    if not hit then return end
    local pos = hit.Position
    if not isValidPosition(pos) then return end
    -- Avoid counting clicks on towers already placed as fresh placement clicks.
    local slot = tonumber(Store.settings.selectedSlot) or 1
    local when = rec.pendingClickTime
    task.delay(0.42, function()
        if Macro.recording ~= rec or not Core.alive then return end
        for _, step in ipairs(rec.steps) do
            if math.abs((step._eventTime or -99) - when) <= 0.7 then return end
        end
        local camera = workspace.CurrentCamera
        local step = { kind = "place", method = "ScreenPlace", slot = slot,
            cameraCF = camera and { camera.CFrame:GetComponents() } or nil,
            cameraFov = camera and camera.FieldOfView or nil,
            pos = { pos.X, pos.Y, pos.Z }, t = when - rec.started,
            wave = (Detect and Detect.wave) or 1,
            unit = "Hotkey " .. slot, _eventTime = when }
        table.insert(rec.steps, step)
        rec.placements = #rec.steps
        Macro.currentStep = #rec.steps
        uiNotify("Recorded draft marker #" .. #rec.steps .. " for slot " .. slot .. " (not replayable until a remote is captured)")
    end)
end)

function Spy.consume(remote, method, args, timestamp)
    if not Core.alive or Spy.ignored(remote.Name) then return end
    if not Spy.enabled and not Macro.recording and not Spy.learn then return end
    local action = snapshot(remote, method, args)
    local kind = classify(remote, args)
    local pos = Spy.placementPosition(args)
    local event = { action = action, kind = kind, pos = pos, time = timestamp,
        name = remote.Name, preview = Spy.describe(args) }
    if Spy.enabled then
        -- Limit retained events; only rebuild spy UI while the tab is visible.
        table.insert(Spy.events, 1, event)
        if #Spy.events > Spy.max then table.remove(Spy.events) end
        Spy.changed = Spy.changed + 1
    end
    if Spy.learn then
        local target = Spy.learn
        Spy.learn = nil
        target.store[target.name] = action
        if Store.saveActions() then
            uiNotify("Saved " .. target.name .. " -> " .. remote.Name)
        else
            uiNotify("Captured " .. target.name .. " but disk saving is unavailable")
        end
        if target.after then target.after() end
        return
    end
    local rec = Macro.recording
    if not rec then return end
    -- Generic remotes may have no descriptive name. Accept position-bearing
    -- actions immediately after a real manual ground click as candidates.
    local recentClick = rec.pendingClickTime and math.abs(timestamp - rec.pendingClickTime) < 0.65
    local templateMatch = Spy.matchesPlacement(action, kind)
    -- Autolearn the placement remote while the user is manually placing units.
    -- Ignore unrelated position-bearing remote calls unless they coincide with
    -- an actual ground click or the remote clearly indicates placement.
    local candidate = pos and (kind == "place" or recentClick)
    if kind == "upgrade" or kind == "sell" or kind == "wave" then candidate = false end
    if not templateMatch and not candidate then return end
    if candidate and not templateMatch then
        Store.actions.placementTemplate = {
            path = action.path, method = action.method,
            signature = stringSignature(action),
        }
        Store.saveActions()
        if not rec.autoLearned then
            rec.autoLearned = true
            uiNotify("AUTO-DETECTED PLACE REMOTE: " .. remote.Name .. " | recording server placement calls")
        end
    end
    if pos and rec.lastRecordPos and (timestamp - (rec.lastRecordTime or -100)) < 0.35 then
        local prev = rec.lastRecordPos
        if math.abs(prev[1]-pos[1]) < 0.4 and math.abs(prev[2]-pos[2]) < 0.4
            and math.abs(prev[3]-pos[3]) < 0.4 then return end
    end
    if not pos then
        rec.missingPositions = rec.missingPositions + 1
        if rec.missingPositions <= 3 then
            uiNotify("PLACE call without world position: open Spy tab and inspect arguments")
        end
        return
    end
    local step = makePlacementStep(event, rec.started)
    step.unit = step.unit ~= "Tower" and step.unit or ("Tower " .. (#rec.steps + 1))
    step._eventTime = timestamp
    table.insert(rec.steps, step)
    rec.placements = rec.placements + 1
    rec.lastRecordTime, rec.lastRecordPos = timestamp, pos
    Macro.currentStep = #rec.steps
    uiNotify("Captured PLACE #" .. rec.placements .. " at "
        .. string.format("%.0f, %.0f, %.0f", pos[1], pos[2], pos[3]))
end

-- One reusable router: repeated execution does not stack another namecall hook.
local router = env.DarkyHubRemoteRouter
if type(router) ~= "table" then router = { installed = false }; env.DarkyHubRemoteRouter = router end
router.handler = function(remote, method, args, at)
    if Core.alive then safeCall(Spy.consume, remote, method, args, at) end
end
if router.installed then
    Spy.available = true
elseif type(hookmetamethod) == "function" and type(getnamecallmethod) == "function"
    and type(checkcaller) == "function" then
    local oldNamecall
    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and (method == "FireServer" or method == "InvokeServer")
                and typeof(self) == "Instance"
                and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local args = table.pack(...)
                local at = os.clock()
                task.defer(function()
                    if type(router.handler) == "function" then
                        pcall(router.handler, self, method, args, at)
                    end
                end)
            end
            return oldNamecall(self, ...)
        end)
    end)
    router.installed = ok
    Spy.available = ok
    if not ok then log("Remote Spy unavailable: " .. tostring(err)) end
else
    log("Remote Spy unavailable: requires namecall interception")
end
function Spy.learnNext(store, name, after)
    if not Spy.available then uiNotify("Cannot learn: remote hook unavailable") return end
    if trim(name) == "" then uiNotify("Name needed") return end
    Spy.learn = { store = store, name = trim(name), after = after }
    uiNotify("Learning " .. name .. ": do that action manually one time")
end
function Spy.selectAction(store, name)
    local event = Spy.selectedEvent
    if not event then uiNotify("Select a Spy event first") return end
    store[name] = event.action
    if Store.saveActions() then
        uiNotify("Saved " .. name .. " from " .. event.name)
    else
        uiNotify("Action captured but could NOT write to disk")
    end
end

-- ======================================================================
--  MARKERS: visible, numbered hints for recorded placements
-- ======================================================================
local Markers = { folder = nil }
function Markers.clear()
    if Markers.folder then Markers.folder:Destroy(); Markers.folder = nil end
end
function Markers.show(macro)
    Markers.clear()
    if not Store.settings.showMarkers or type(macro) ~= "table" then return end
    Markers.folder = new("Folder", { Name = "DarkyHubV4Markers" }, workspace)
    local n = 0
    for _, step in ipairs(macro.steps or {}) do
        if step.kind == "place" and type(step.pos) == "table" and #step.pos >= 3 then
            n = n + 1
            local p = Vector3.new(step.pos[1], step.pos[2], step.pos[3])
            if isValidPosition(p) then
                local part = new("Part", { Name = "Placement_" .. n,
                    Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.13, 3.3, 3.3),
                    CFrame = CFrame.new(p + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.pi / 2),
                    Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
                    Material = Enum.Material.Neon, Color = Color3.fromRGB(160, 100, 255),
                    Transparency = 0.45 }, Markers.folder)
                local billboard = new("BillboardGui", { Name = "Index", Adornee = part,
                    Size = UDim2.fromOffset(130, 36), StudsOffsetWorldSpace = Vector3.new(0, 3, 0),
                    AlwaysOnTop = true }, part)
                new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                    Text = "#" .. n .. "  " .. tostring(step.unit or "Unit"), Font = Enum.Font.GothamBold, TextSize = 16,
                    TextColor3 = Color3.fromRGB(230, 210, 255), TextStrokeTransparency = 0 }, billboard)
            end
        end
    end
end

-- ======================================================================
--  MACRO: ONLY placements, retry money failures, verify before upgrades
-- ======================================================================
function Macro.library() return Store.loadMap(Map.key) end
function Macro.select(name)
    Macro.selected = name
    Store.mapConfig.selectedMacro = name or ""
    Store.saveMapConfig(Map.key)
    Markers.show(name and Macro.library()[name])
end
function Macro.loadSelection()
    local library = Macro.library()
    local desired = Store.mapConfig.selectedMacro
    if not library[desired] then desired = sortedKeys(library)[1] end
    Macro.select(desired)
end
function Macro.startRecord(name)
    if not Spy.available then
        uiNotify("Remote hooks unavailable - recording using keyboard 1-6 and ground-click fallback")
    end
    if not Store.hasFS then
        uiNotify("Recording will work this session only; executor lacks file saving APIs")
    end
    name = trim(name)
    if name == "" then uiNotify("Type a macro name, press Enter, then Record") return false end
    if Macro.playing then Macro.stopPlay() end
    if not Store.settings.captureClickFallback then
        Store.settings.captureClickFallback = true
        uiNotify("Enabled draft marker recording to prevent losing placements")
    end
    Macro.recording = { name = name, map = Map.key, started = os.clock(),
        steps = {}, placements = 0, missingPositions = 0 }
    uiNotify("RECORDING: place towers normally. DarkyHub will auto-detect position-bearing placement remotes")
    return true
end
function Macro.stopRecord()
    local rec = Macro.recording
    Macro.recording = nil
    if not rec then return end
    if #rec.steps == 0 then
        uiNotify("NOT SAVED: no placements recorded. Enable Save placement markers from clicks, then select hotkey and click ground")
        return false
    end
    local steps = {}
    for _, step in ipairs(rec.steps) do
        if step.kind == "place" and step.pos then
            local copy = shallowCopy(step)
            copy._eventTime = nil
            copy.t = math.min(copy.t or 0, 300)
            table.insert(steps, copy)
        end
    end
    if #steps == 0 then uiNotify("NOT SAVED: no valid placement positions") return false end
    -- Always save a draft even if no remote was captured: markers remain visible.
    -- A ScreenPlace step is NOT a mouse-free placement command.
    local remoteCount = 0
    for _, step in ipairs(steps) do
        if step.method ~= "ScreenPlace" then remoteCount = remoteCount + 1 end
    end
    local data = { version = 3, name = rec.name, map = rec.map,
        createdAt = os.time(), steps = steps, placements = #steps }
    local cached, persistent = Store.saveMacro(rec.map, rec.name, data)
    if cached then
        if rec.map == Map.key then Macro.select(rec.name) end
        local prefix = persistent and "SAVED ON DISK" or "MEMORY ONLY - NOT SAVED TO DISK"
        uiNotify(prefix .. "  " .. rec.name .. " [" .. rec.map .. "] " .. #steps .. " markers / " .. remoteCount .. " playable remotes")
        return true
    end
    uiNotify("SAVE FAILED")
    return false
end
function Macro.stopPlay()
    if Macro.setPlacementHUD then Macro.setPlacementHUD(false) end
    Macro.playToken = Macro.playToken + 1
    Macro.playing = false
    Macro.step = "Stopped"
    Macro.placementDone = false
end
local function pauseOrCancel(seconds, token)
    local deadline = os.clock() + math.max(0, seconds)
    while Core.alive and token == Macro.playToken and os.clock() < deadline do
        task.wait(math.min(0.15, math.max(0.02, deadline - os.clock())))
    end
    return Core.alive and token == Macro.playToken
end
function Macro.getPlacementCount(m)
    local n = 0
    for _, step in ipairs(m.steps or {}) do
        if step.kind == "place" then n = n + 1 end
    end
    return n
end
-- A verified unit container can prove a new tower spawned. Without one we DO NOT
-- resend a FireServer action 30 times blindly because it could create 30 towers.
local Verify = {}
function Verify.folder()
    local override = trim(Store.settings.unitContainer)
    if override ~= "" then
        local p = override:gsub("^game%.", ""):gsub("^workspace%.", "")
        local root = workspace
        for name in p:gmatch("[^%.]+") do
            if name ~= "workspace" and name ~= "Workspace" then
                root = root and root:FindFirstChild(name)
            end
        end
        return root
    end
    for _, path in ipairs({ { "Units" }, { "Towers" }, { "PlacedUnits" },
            { "PlacedTowers" }, { "Troops" }, { "Entities", "Towers" },
            { "Map", "Units" }, { "CurrentMap", "Towers" } }) do
        local folder = workspace
        for _, key in ipairs(path) do folder = folder and folder:FindFirstChild(key) end
        if folder then return folder end
    end
    return nil
end
-- Ignore markers, effect parts and single-part placement circles.
function Verify.realTower(unit)
    if not unit or not unit:IsA("Model") or unit.Name:match("^Placement_") then return false end
    local n = 0
    for _, part in ipairs(unit:GetDescendants()) do
        if part:IsA("BasePart") then n += 1; if n >= 2 then return true end end
    end
    return false
end
function Verify.countNear(folder, pos)
    if not folder or not pos then return nil end
    local target = Vector3.new(pos[1], pos[2], pos[3])
    local count = 0
    for _, unit in ipairs(folder:GetChildren()) do
        local point
        if Verify.realTower(unit) then
            local ok, cf = pcall(function() return unit:GetPivot() end)
            point = ok and cf.Position or nil
        end
        if point and (point - target).Magnitude <= 12 then count = count + 1 end
    end
    return count
end
-- Check whether a tower already occupies a saved location before sending input.
-- This only inspects replicated units, never the visual marker folder.
function Verify.occupied(folder, pos)
    if not folder or type(pos) ~= "table" or #pos < 3 then return nil end
    local target = Vector3.new(pos[1], pos[2], pos[3])
    local radius = tonumber(Store.settings.occupancyRadius) or 4.5
    for _, unit in ipairs(folder:GetChildren()) do
        if Verify.realTower(unit) then
            local pivot
            local ok = pcall(function()
                pivot = unit:GetPivot().Position
            end)
            if ok and pivot and (Vector3.new(pivot.X, 0, pivot.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude <= radius then
                return true, unit.Name
            end
        end
    end
    return false
end
function Verify.manualCount()
    local folder = Verify.folder()
    if not folder then return nil end
    local count = 0
    for _, item in ipairs(folder:GetChildren()) do
        if Verify.realTower(item) then
            -- A manually specified folder is recommended: automatic unit counting is
            -- unreliable for games that combine towers and enemies in one container.
            count = count + 1
        end
    end
    return count
end

-- A visible insufficient-money toast is negative evidence even if the game
-- does not expose an easily recognized tower model folder.
function Verify.rejectionToast()
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local txt = clean(obj.Text)
            if txt:find("NOT ENOUGH", 1, true) or txt:find("CAN'T AFFORD", 1, true)
                or txt:find("CANNOT AFFORD", 1, true)
                or txt:find("INSUFFICIENT", 1, true) then
                local shown, ancestor = true, obj.Parent
                while ancestor and ancestor ~= playerGui do
                    if ancestor:IsA("GuiObject") and not ancestor.Visible then shown = false; break end
                    if ancestor:IsA("ScreenGui") and not ancestor.Enabled then shown = false; break end
                    ancestor = ancestor.Parent
                end
                if shown then return txt end
            end
        end
    end
    return nil
end
-- Positive proof is a newly replicated model near saved world location or
-- a true RemoteFunction response. Failure evidence is an error/false response.
function Verify.placement(step, before, folder, explicit)
    if explicit == true then return "success" end
    if explicit == false then return "failed" end
    if not folder then
        if Verify.rejectionToast() then return "failed" end
        return "unknown"
    end
    local after = Verify.countNear(folder, step.pos)
    if before ~= nil and after ~= nil then
        return after > before and "success" or "failed"
    end
    return "unknown"
end
function Macro.startPlay()
    local name = Macro.selected
    local m = name and Macro.library()[name]
    if not m or type(m.steps) ~= "table" or #m.steps == 0 then
        uiNotify("NO MACRO: select a saved placement macro for this map")
        return false
    end
    if Macro.recording then uiNotify("Stop and save recording first"); return false end
    local placements = {}
    for _, step in ipairs(m.steps) do
        if step.kind == "place" and step.pos then table.insert(placements, step) end
    end
    if #placements == 0 then
        uiNotify("MACRO INVALID: no placement calls with positions")
        return false
    end
    -- A saved XYZ is a target location, not itself a server placement request.
    -- Occupancy can skip an existing unit, but cannot create a missing one.
    -- ScreenPlace contains a marker and a hotkey, NOT a placement remote.
    -- Refuse mouse-free playback early instead of showing a misleading success.
    if Store.settings.remoteOnly and not Store.settings.allowScreenFallback then
        local clicks = 0
        for _, step in ipairs(placements) do
            if step.method == "ScreenPlace" and Verify.occupied(Verify.folder(), step.pos) ~= true then
                clicks = clicks + 1
            end
        end
        if clicks > 0 then
            Macro.lastFailure = string.format("%d/%d missing placements are marker-only; enable screen-input fallback or capture a placement remote", clicks, #placements)
            Macro.step = "BLOCKED: " .. Macro.lastFailure
            Macro.placementDone = false
            uiNotify(Macro.step)
            return false
        end
    end
    Macro.stopPlay()
    local token = Macro.playToken
    Macro.playing = true
    if Macro.setPlacementHUD then Macro.setPlacementHUD(true) end
    Macro.placementDone = false
    Macro.expectedPlacements = #placements
    Macro.dispatchedPlacements, Macro.attempts, Macro.failures, Macro.unverified = 0, 0, 0, 0
    Macro.pass = 0
    Markers.show(m)
    uiNotify("PLAYING " .. name .. ": " .. #placements .. " placements")
    task.spawn(function()
        local pending = {}
        local attempted = {}
        local sentUnverified = {}
        for i = 1, #placements do pending[i] = true; attempted[i] = 0 end
        local tries = 3
        local function active()
            return Core.alive and token == Macro.playToken and not (Detect and Detect.result)
        end
        local function refreshStats()
            local placed, failed, unknown = 0, 0, 0
            for i = 1, #placements do
                if pending[i] then failed = failed + 1 else placed = placed + 1 end
                if sentUnverified[i] then unknown = unknown + 1 end
            end
            Macro.dispatchedPlacements, Macro.failures, Macro.unverified = placed, failed, unknown
        end
        local function attemptOne(index, step)
            if not active() or not pending[index] or attempted[index] >= tries or sentUnverified[index] then return end
            local folder = Verify.folder()
            local occupied, unitName = Verify.occupied(folder, step.pos)
            if occupied then
                pending[index] = nil
                sentUnverified[index] = nil
                Macro.step = string.format("Placement %d/%d: already occupied (%s)", index, #placements, tostring(unitName))
                refreshStats()
                return
            end
            local minimumCash = tonumber(step.minCash) or tonumber(Store.settings.minPlacementCash) or 0
            local cash = getStat({ "Cash", "Money", "Gold" })
            if cash and cash < minimumCash then
                Macro.lastFailure = "Waiting for cash " .. tostring(minimumCash)
                return -- Do not waste a request when known funds are insufficient
            end
            attempted[index] = attempted[index] + 1
            Macro.attempts = Macro.attempts + 1
            Macro.step = string.format("Placement %d/%d | Pending %d", index, #placements, Macro.failures)
            local before = Verify.countNear(folder, step.pos)
            local ok, reason, explicit = Codec.call(step)
            if not pauseOrCancel(math.max(0.4, Store.settings.placementDelay), token) then return end
            local verdict = ok and Verify.placement(step, before, folder, explicit) or "failed"
            local occupiedAfter = Verify.occupied(folder, step.pos)
            if verdict == "success" or occupiedAfter == true then
                pending[index] = nil
                sentUnverified[index] = nil
            elseif verdict == "unknown" and ok then
                -- No proof either way: do not send duplicate requests on next pass.
                sentUnverified[index] = true
                Macro.lastFailure = "Unverified placement at XYZ: no hero confirmation"
            else
                Macro.lastFailure = tostring(reason or "Placement rejected")
            end
            refreshStats()
        end
        -- Initial pass: play each scheduled placement once. No repeats of confirmed towers.
        local previous = 0
        for index, step in ipairs(placements) do
            if not active() then return end
            if Store.settings.placementByWave then
                local targetWave = tonumber(step.wave) or 1
                while active() and ((not Detect or not Detect.wave) or Detect.wave < targetWave) do
                    Macro.step = "Waiting for wave " .. targetWave
                    task.wait(0.35)
                end
                if not active() then return end
            end
            local delay = Store.settings.playbackMode == "Fixed" and Store.settings.fixedStepDelay
                or math.min(100, math.max(0, (step.t or 0) - previous))
            if not pauseOrCancel(delay, token) then return end
            attemptOne(index, step)
            previous = step.t or previous
        end
        if not active() then return end
        Macro.pass = 1
        if Macro.setPlacementHUD then Macro.setPlacementHUD(false) end
        Macro.playing = false
        Macro.placementDone = true -- Upgrade gate unlocked after initial scheduled placements.
        refreshStats()
        Macro.step = string.format("Upgrades unlocked | Placed %d/%d | Pending %d", Macro.dispatchedPlacements, #placements, Macro.failures)
        uiNotify(Macro.step .. " | Failed towers retry every 10 seconds")
        -- Independent retry queue. Auto Upgrade keeps running between attempts.
        while active() do
            local remaining, eligible = 0, 0
            for index, step in ipairs(placements) do
                if pending[index] then
                    local occupied = Verify.occupied(Verify.folder(), step.pos)
                    if occupied then pending[index] = nil; sentUnverified[index] = nil
                    else remaining = remaining + 1 end
                    if attempted[index] < tries and not sentUnverified[index] then eligible = eligible + 1 end
                end
            end
            if remaining == 0 or eligible == 0 then break end
            if not pauseOrCancel(10, token) then return end
            for index, step in ipairs(placements) do
                if not active() then return end
                if pending[index] and attempted[index] < tries and not sentUnverified[index] then
                    local targetWave = tonumber(step.wave) or 1
                    if not Store.settings.placementByWave or (Detect.wave and Detect.wave >= targetWave) then
                        attemptOne(index, step)
                    end
                end
            end
            refreshStats()
        end
        if token ~= Macro.playToken then return end
        Macro.step = string.format("Placement queue ended | Placed %d/%d | Failed %d | Upgrading ON", Macro.dispatchedPlacements, #placements, Macro.failures)
    end)
    return true
end
Macro.loadSelection()

-- ======================================================================
--  DETECT: one low-frequency GUI scan feeds every automation
-- ======================================================================
Detect = { texts = {}, buttons = {}, wave = nil, maxWave = nil,
    inMatch = false, result = false, resultKind = "", runs = 0, totalXP = 0,
    rewards = {}, wins = 0, losses = 0, history = {}, runId = 0, lastWave = nil,
    changed = 0, blockedUntil = 0,
    resultSince = 0, runStartedAt = os.clock(), resultSerial = 0 }
local END_WORDS = { "WELL FOUGHT", "VICTORY", "DEFEAT", "GAME OVER", "MISSION COMPLETE", "YOU WIN", "YOU LOSE", "STAGE CLEAR", "STAGE COMPLETE", "LEVEL COMPLETE", "MISSION SUCCESS" }
local BLOCKED_WORDS = { "FULLY UPGRADED", "NOT ENOUGH", "CAN'T AFFORD", "CANNOT AFFORD", "INSUFFICIENT", "MAX LEVEL" }
local ResultEvent = function() end
local WaveEvent = function() end
local Webhook
local function isOurGUI(obj) return GUI and obj:IsDescendantOf(GUI) end
local function visible(obj)
    local cur = obj
    while cur and cur ~= playerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end
local function buttonAncestor(obj)
    local p = obj
    while p and p ~= playerGui do
        if p:IsA("GuiButton") then return p end
        p = p.Parent
    end
    return nil
end
local scanObjects = {}
local function trackGameText(obj)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        scanObjects[obj] = true
    end
end
for _, obj in ipairs(playerGui:GetDescendants()) do trackGameText(obj) end
connect(playerGui.DescendantAdded, trackGameText)
connect(playerGui.DescendantRemoving, function(obj) scanObjects[obj] = nil end)
local function captureRewards(texts)
    local found, seen = {}, {}
    local xp = 0
    local REWARD_TAGS = { "XP", "EXP", "GEM", "COIN", "GOLD", "CANDY", "MILK", "TICKET", "TOKEN", "PAGE", "DIAMOND" }
    for _, entry in ipairs(texts) do
        if entry.obj:IsA("TextLabel") then
            local t = entry.text
            local hasNum = t:find("%d") ~= nil
            local named = false
            for _, tag in ipairs(REWARD_TAGS) do
                if t:find(tag, 1, true) then named = true; break end
            end
            if (hasNum or t:find("NO GEMS", 1, true) or t:find("NO REWARD", 1, true))
                and named and not seen[t] and #found < 25 then
                -- Status bar and navigation can also mention currencies; this is a best-effort snapshot.
                seen[t] = true
                table.insert(found, entry.obj.Text)
                local amount = t:match("([%d,]+)%s*XP") or t:match("XP%s*[:%+X]*%s*([%d,]+)")
                if amount then xp = xp + (tonumber(amount:gsub(",", "")) or 0) end
            end
        end
    end
    -- Capture an explicit lack of rewards even if a results label has no number.
    if #found == 0 then
        for _, entry in ipairs(texts) do
            if entry.obj:IsA("TextLabel") and (entry.text:find("NO GEMS", 1, true)
                or entry.text:find("NO REWARDS", 1, true)) then
                table.insert(found, entry.obj.Text)
                break
            end
        end
    end
    return found, xp
end
function Detect.scan()
    local texts, buttons = {}, {}
    for obj in pairs(scanObjects) do
        if obj.Parent and not isOurGUI(obj)
            and visible(obj) and obj.Text ~= "" then
            local up = clean(obj.Text)
            table.insert(texts, { text = up, obj = obj })
            local b = buttonAncestor(obj)
            if b then table.insert(buttons, { text = up, button = b }) end
        end
    end
    Detect.texts, Detect.buttons = texts, buttons
    local wave, maxWave, resultKind = nil, nil, nil
    -- HUD-first wave detection: prioritize short labels beginning with WAVE.
    -- Descriptions like "BOSS AT WAVE 15" and "WAVE REWARDS" are not the HUD.
    local bestScore = -math.huge
    for _, e in ipairs(texts) do
        local w, max = e.text:match("^WAVE%s*[:#%-]?%s*(%d+)%s*/%s*(%d+)")
        if not w then w = e.text:match("^WAVE%s*[:#%-]?%s*(%d+)%f[^%d]") end
        if w and #e.text < 24 then
            local score = 100
            local ok, pos = pcall(function() return e.obj.AbsolutePosition end)
            if ok and pos then score = score - math.max(0, pos.Y) / 50 end
            if tonumber(max) then score = score + 15 end
            if score > bestScore then
                bestScore = score
                wave, maxWave = tonumber(w), tonumber(max)
            end
        end
    end
    for _, e in ipairs(texts) do
        if e.obj:IsA("TextLabel") then
            for _, phrase in ipairs(END_WORDS) do
                if e.text == phrase or e.text:find(phrase, 1, true) then
                    resultKind = phrase
                    break
                end
            end
        end
        if resultKind then break end
    end
    -- Result screens in Dungeon mode may ONLY show TRY AGAIN / RETURN TO HUB,
    -- with the WAVE HUD still visible in the blurred background.
    if not resultKind then
        local again, hub, nextStage = false, false, false
        for _, entry in ipairs(buttons) do
            if entry.text == "TRY AGAIN" or entry.text == "REPLAY" then again = true end
            if entry.text == "RETURN TO HUB" or entry.text == "RETURN TO LOBBY" then hub = true end
            if entry.text == "NEXT STAGE" or entry.text == "NEXT LEVEL" or entry.text == "NEXT" then nextStage = true end
        end
        if hub and (again or nextStage) then
            resultKind = again and "DUNGEON DEFEAT" or "DUNGEON COMPLETE"
        end
    end
    local oldResult = Detect.result
    Detect.result = resultKind ~= nil
    Detect.resultKind = resultKind or ""
    Detect.wave, Detect.maxWave = wave, maxWave
    local oldWave = Detect.lastWave
    local oldInMatch = Detect.inMatch
    Detect.inMatch = wave ~= nil and not Detect.result
    if Detect.result and not oldResult then
        Detect.runs = Detect.runs + 1
        Macro.stopPlay()
        log("Match result: " .. Detect.resultKind .. " (run #" .. Detect.runs .. ")")
        Detect.resultSince = os.clock()
        local outcome = (resultKind == "WELL FOUGHT" or resultKind == "DEFEAT"
            or resultKind == "DUNGEON DEFEAT" or resultKind == "GAME OVER"
            or resultKind == "YOU LOSE") and "Loss" or "Win"
        if outcome == "Win" then Detect.wins = Detect.wins + 1 else Detect.losses = Detect.losses + 1 end
        table.insert(Detect.history, 1, { timestamp = os.time(), outcome = outcome,
            map = Map.key, wave = wave, result = resultKind })
        if #Detect.history > 30 then table.remove(Detect.history) end
        Detect.resultSerial = Detect.resultSerial + 1
        local reward, xp = captureRewards(texts)
        Detect.rewards = reward
        Detect.totalXP = Detect.totalXP + xp
        local last = Detect.history[1]
        if last then last.rewards = reward end
        local serial = Detect.resultSerial
        task.delay(1.2, function()
            if not Core.alive or serial ~= Detect.resultSerial or not Detect.result then return end
            -- Rewards often animate into the results window after the headline.
            local latest, latestXP = captureRewards(Detect.texts)
            if #latest > 0 then
                Detect.totalXP = Detect.totalXP - xp + latestXP
                Detect.rewards = latest
                if Detect.history[1] then Detect.history[1].rewards = latest end
            end
            if Store.hasFS then
                writeJSON(Store.root .. "/run_history.json", {
                    session = Webhook and Webhook.id or tostring(os.time()),
                    runs = Detect.runs, wins = Detect.wins, losses = Detect.losses,
                    xp = Detect.totalXP, history = Detect.history,
                })
            end
            ResultEvent(Detect.resultKind)
        end)
    end
    if Detect.inMatch and wave <= 1 and (not oldInMatch or (oldWave and wave < oldWave)) then
        Detect.runId = Detect.runId + 1
        Macro.placementDone = false
        Macro.dispatchedPlacements = 0
        Macro.lastRunStarted = Detect.runId
        log("Match start / reset: " .. tostring(wave))
        if Store.settings.autoPlay then Macro.startPlay() end
    end
    if wave and (not oldWave or wave ~= oldWave) and not Detect.result then
        WaveEvent(wave, maxWave)
    end
    Detect.lastWave = wave
    Detect.changed = Detect.changed + 1
end
function Detect.findButton(words)
    for _, word in ipairs(words) do
        for _, entry in ipairs(Detect.buttons) do
            if entry.text == word or entry.text:match("^" .. word .. "%s*%d+$") then
                return entry.button
            end
        end
    end
    return nil
end

-- ======================================================================
--  ACTIONS: learned remotes and a GUI-button fallback
-- ======================================================================
function Actions.click(button)
    if not button or not button.Parent or not visible(button) then return false end
    -- Fire one signal only; firing Activated + MouseButton1Click can double-spend.
    if type(getconnections) == "function" then
        for _, sig in ipairs({ button.MouseButton1Click, button.Activated }) do
            local ok, connections = pcall(getconnections, sig)
            if ok and connections then
                for _, c in ipairs(connections) do
                    if c.Enabled ~= false then
                        local success = pcall(function() c:Fire() end)
                        if success then return true end
                    end
                end
            end
        end
    end
    if type(firesignal) == "function" then
        local success = pcall(firesignal, button.Activated)
        if success then return true end
    end
    local pos = button.AbsolutePosition + button.AbsoluteSize / 2
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
    end)
    return ok
end
-- Cache the upgrade button briefly, but don't scan the entire PlayerGui every frame.
local upgradeButtonCache, upgradeButtonCachedAt = nil, 0
local function directGameButton(words)
    local cacheValid = upgradeButtonCache and upgradeButtonCache.Parent
        and visible(upgradeButtonCache) and os.clock() - upgradeButtonCachedAt < 2
    if words[1] == "UPGRADE ALL" and cacheValid then return upgradeButtonCache end
    for obj in pairs(scanObjects) do
        if obj.Parent and not isOurGUI(obj) and visible(obj) and obj.Text ~= "" then
            local text = clean(obj.Text)
            for _, word in ipairs(words) do
                local nextChar = text:sub(#word + 1, #word + 1)
                if text == word or (text:sub(1, #word) == word
                    and (nextChar == " " or nextChar == "(" or nextChar == ":")) then
                    local button = buttonAncestor(obj)
                    if button then
                        if words[1] == "UPGRADE ALL" then
                            upgradeButtonCache, upgradeButtonCachedAt = button, os.clock()
                        end
                        return button
                    end
                end
            end
        end
    end
    return nil
end
-- The upgrade menu may be closed: its existing click connections can still be
-- called without opening it. This is only used for UPGRADE ALL.
local function hiddenUpgradeButton()
    for obj in pairs(scanObjects) do
        if obj.Parent and not isOurGUI(obj) and obj.Text ~= "" and clean(obj.Text) == "UPGRADE ALL" then
            local b = buttonAncestor(obj)
            if b then return b end
        end
    end
    -- Catch UI elements created before the scanner initialized.
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and not isOurGUI(obj)
            and clean(obj.Text) == "UPGRADE ALL" then
            local b = buttonAncestor(obj)
            if b then return b end
        end
    end
    return nil
end
local function fireUpgradeConnections(btn)
    if not btn or not btn.Parent or type(getconnections) ~= "function" then return false end
    for _, signal in ipairs({ btn.MouseButton1Click, btn.Activated }) do
        local ok, connections = pcall(getconnections, signal)
        if ok and connections then
            for _, c in ipairs(connections) do
                if c.Enabled ~= false then
                    local fired = pcall(function() c:Fire() end)
                    if fired then return true end
                end
            end
        end
    end
    return false
end
local upgradeOpenAttemptAt = -100
local function performUpgradeAll()
    local btn = hiddenUpgradeButton()
    if fireUpgradeConnections(btn) then return true, "Direct connection" end
    -- Fallback 2: N opens Your Heroes menu. Never press N when already open.
    local visibleBtn = directGameButton({ "UPGRADE ALL" })
    if visibleBtn then
        return Actions.click(visibleBtn), "Visible button"
    end
    local now = os.clock()
    if now - upgradeOpenAttemptAt >= 4 then
        upgradeOpenAttemptAt = now
        local ok = pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.N, false, game)
            task.wait(0.06)
            VIM:SendKeyEvent(false, Enum.KeyCode.N, false, game)
        end)
        return false, ok and "Opening Heroes menu with N" or "N key fallback unavailable"
    end
    return false, "Waiting for Heroes menu"
end
function Actions.perform(slotName, labels)
    -- Game GUI actions should work WITHOUT learning. Use remotes only as fallback.
    local button = directGameButton(labels or {}) or Detect.findButton(labels or {})
    if Actions.click(button) then return true end
    local learned = Store.actions.slots[slotName]
    if learned then
        local ok, why = Codec.call(learned)
        if not ok then log(slotName .. ": " .. why) end
        return ok
    end
    return false
end
-- Dungeon challenge selection: find the PLAY button in the unique card
-- containing the configured act/stage name (e.g. FROSTY FUDGE PASS).
function Actions.challengeCard(stageName)
    local target = clean(stageName)
    if #target < 4 then return false end
    for _, entry in ipairs(Detect.texts) do
        if entry.text:find(target, 1, true) then
            local ancestor = entry.obj.Parent
            for depth = 1, 7 do
                if not ancestor or ancestor == playerGui then break end
                local choices, seen = {}, {}
                for _, obj in ipairs(ancestor:GetDescendants()) do
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        if visible(obj) and clean(obj.Text) == "PLAY" then
                            local btn = buttonAncestor(obj)
                            if btn and not seen[btn] then
                                seen[btn] = true
                                table.insert(choices, btn)
                            end
                        end
                    end
                end
                if #choices == 1 then return Actions.click(choices[1]) end
                if #choices > 1 then break end
                ancestor = ancestor.Parent
            end
        end
    end
    return false
end
function Actions.profile(kind, name)
    local action = Store.actions[kind][name or ""]
    if not action then return false end
    local ok, why = Codec.call(action)
    if not ok then log("Profile " .. kind .. "/" .. name .. ": " .. why) end
    return ok
end

-- ======================================================================
--  AUTOMATIONS: cooldowns, placement barrier, result priority
-- ======================================================================
local Auto = { clocks = {}, selectedJoin = nil, selectedChallenge = nil,
    traitRolls = 0, summons = 0, waiting = "", lastMapKey = Map.key }
local function allowed(name, delay)
    local now = os.clock()
    if now - (Auto.clocks[name] or -1000) < delay then return false end
    Auto.clocks[name] = now
    return true
end
local function detectBlocked()
    for _, entry in ipairs(Detect.texts) do
        for _, phrase in ipairs(BLOCKED_WORDS) do
            if entry.text:find(phrase, 1, true) then
                return phrase
            end
        end
    end
    return nil
end
local function traitReached(target)
    target = clean(target)
    if target == "" then return false end
    for _, entry in ipairs(Detect.texts) do
        if entry.obj:IsA("TextLabel") then
            -- Only read trait-specific labels, not a button that offers target choices.
            local t = entry.text
            if t:find("TRAIT", 1, true) and t:find(target, 1, true) then return true end
        end
    end
    return false
end
-- Hub transition gate: prevent macro, upgrade, and result-button interference.
Core.hubTransition = false
Core.hubTransitionAt = 0
local function beginHubTransition()
    if Core.hubTransition then return end
    Core.hubTransition = true
    Core.hubTransitionAt = os.clock()
    Macro.stopPlay()
    if GUI then GUI.Enabled = false end
    if Core.placementHudGui then Core.placementHudGui.Enabled = false end
    log("Returning to Hub: automation paused")
end
local RESULT_LABELS = {
    Replay = { "TRY AGAIN", "REPLAY", "PLAY AGAIN", "RETRY" },
    ["Next Stage"] = { "NEXT STAGE", "NEXT LEVEL", "NEXT" },
    Lobby = { "RETURN TO HUB", "RETURN TO LOBBY", "BACK TO LOBBY", "LOBBY" },
}
local RESULT_SLOTS = { Replay = "replay", ["Next Stage"] = "nextStage", Lobby = "lobby" }
local Infinite -- initialized below; called by the match state machine
local Raid -- initialized after Automations, referenced by result handler
function Auto.tick()
    if not Core.alive then return end
    if Map.refresh() then
        Macro.stopPlay()
        Macro.loadSelection()
        Auto.lastMapKey = Map.key
        uiNotify("Map changed: " .. Map.name)
    end
    Detect.scan()
    if Core.hubTransition then
        -- A failed/no-op navigation must not lock DarkyHub forever.
        if os.clock() - Core.hubTransitionAt > 20 then
            Core.hubTransition = false
            if GUI then GUI.Enabled = true end
        else
            return
        end
    end
    local s = Store.settings
    Auto.waiting = ""
    -- Halloween Raid: NEXT -> POUR 1 BUG MILK -> PLAY AGAIN? -> YES.
    -- The confirmation is a modal: only click YES while its exact header is shown.
    if Raid and Raid.pendingResult ~= nil and (s.autoRaid or s.isRaidMatch) and s.resultMode == "Next Stage" then
        local playAgainModal = false
        local continueModal = false
        for _, e in ipairs(Detect.texts) do
            if e.text:find("PLAY AGAIN?", 1, true) then playAgainModal = true end
            if e.text:find("ARE YOU SURE", 1, true)
                or e.text:find("WANT TO CONTINUE", 1, true) then
                continueModal = true
            end
        end
        -- Confirmation must be handled before trying another Pour Milk.
        if playAgainModal then
            Auto.waiting = "Raid: confirming PLAY AGAIN?"
            if allowed("raid_play_again_yes", 4) then
                local yes = directGameButton({ "YES" })
                if yes and Actions.click(yes) then
                    Raid.phase = "YES submitted; waiting for next stage wave 1"
                    Auto.waiting = Raid.phase
                end
            end
            return
        end
        if continueModal then
            Auto.waiting = "Raid: confirming next"
            if allowed("raid_confirm_next", 4) then
                local yes = directGameButton({ "YES CONTINUE", "CONFIRM", "YES" })
                if yes and Actions.click(yes) then
                    Raid.phase = "Continue confirmed; waiting for milk prompt"
                    Auto.waiting = Raid.phase
                end
            end
            return
        end
        local pourButton = directGameButton({ "POUR 1 BUG MILK", "POUR MILK", "POUR BUG MILK" })
        if pourButton then
            Auto.waiting = "Raid: pour one Bug Milk"
            if allowed("raid_pour_milk", 6) and Actions.click(pourButton) then
                Raid.phase = "Pour Milk clicked; waiting for PLAY AGAIN?"
                Auto.waiting = Raid.phase
            end
            return
        end
    end
    -- Manual-placement unlock only with an explicit target and reliable chosen
    -- unit container. This gate is optional and never needed for saved macros.
    if Detect.inMatch and s.autoUpgrade and not Macro.placementDone
        and not Macro.playing and (tonumber(s.manualUnitTarget) or 0) > 0 then
        local count = Verify.manualCount()
        if count and count >= s.manualUnitTarget then
            Macro.placementDone = true
            Macro.step = "Manual unit target reached " .. count .. "/" .. s.manualUnitTarget
            uiNotify("Manual unit target reached; upgrades unlocked")
        end
    end
    if Infinite then Infinite.tick() end

    -- Only ONE result action can be active, avoiding replay/next-stage races.
    if Detect.result then
        if os.clock() - Detect.resultSince < 1.6 then return end
        -- The Match tab selector is authoritative. Raid / Challenge / Infinite
        -- settings must NOT change it behind the user's back.
        local modeChosen = s.resultMode or "Off"
        if modeChosen ~= "Off" and modeChosen ~= "Replay"
            and modeChosen ~= "Next Stage" and modeChosen ~= "Lobby" then
            modeChosen = "Off"
        end
        -- Dungeon/raid next stages reuse the SAME MAP macro, but each
        -- advancing stage may consume one Bug Milk. Do not blindly queue
        -- more next-stage clicks if we cannot afford the transition.
        if (s.autoRaid or s.isRaidMatch) and modeChosen == "Next Stage" and Raid then
            local good, reason = Raid.canAdvance(Detect.resultSerial)
            if not good then
                Auto.waiting = reason
                return -- Do not unexpectedly leave the raid when out of milk.
            end
        end
        if modeChosen ~= "Off" and allowed("result_action", 3.5) then
            local mode = modeChosen
            -- No implicit Replay on defeat: only the selected action runs.
            -- The GUI is a first-class action source: no learned remotes required.
            local button = Detect.findButton(RESULT_LABELS[mode] or {})
            local worked = Actions.click(button)
            if not worked and Store.actions.slots[RESULT_SLOTS[mode] or ""] then
                worked = Actions.perform(RESULT_SLOTS[mode], {})
            end
            if worked then
                if mode == "Lobby" then beginHubTransition() end
                log("Result GUI clicked: " .. mode)
                if (s.autoRaid or s.isRaidMatch) and mode == "Next Stage" and Raid then
                    Raid.noteNextStage(Detect.resultSerial)
                end
            else
                Auto.waiting = "No visible " .. mode .. " button; waiting for result GUI"
            end
        end
        return
    end

    if Detect.inMatch then
        if Infinite and Infinite.active then
            Auto.waiting = Infinite.status
            return -- Stop-wave phase disables upgrading and skipping until defeat
        end
        if s.autoSkip and allowed("skip", 1.8) then
            if not Actions.perform("skipWave", { "SKIP WAVE", "SKIP", "START WAVE", "READY", "START" }) then
                Auto.waiting = "No skip/start wave action found"
            end
        end
        if s.autoUpgrade and not Macro.placementDone then
            Auto.waiting = Macro.playing and "Placing towers before upgrades" or
                "Auto Upgrade LOCKED: run a placement macro or confirm placements manually"
        end
        return
    end

    if s.autoChallenge and not s.autoRaid and allowed("challenge", 12) then
        local stage = trim(s.challengeStage)
        if stage ~= "" then
            if not Actions.challengeCard(stage) then
                local opened = Actions.perform("challengeMenu", { "CHALLENGES", "DUNGEON TRAIN" })
                Auto.waiting = opened and "Opening Challenges; waiting for " .. stage
                    or "Open Challenges screen; waiting for card " .. stage
            end
        elseif Auto.selectedChallenge then
            Actions.profile("challenge", Auto.selectedChallenge)
        else
            Auto.waiting = "Enter a Challenge Card name in Home"
        end
    elseif s.autoJoin and not s.autoRaid and Auto.selectedJoin and allowed("join", 12) then
        Actions.profile("join", Auto.selectedJoin)
    end

    if s.autoSummon and allowed("summon", math.max(1.5, s.summonDelay)) then
        local gems = getStat({ "Gems", "Gem", "Diamonds" })
        if gems and gems > s.keepGems then
            if Actions.perform("summon", { "SUMMON", "SUMMON X1" }) then
                Auto.summons = Auto.summons + 1
            else
                Auto.waiting = "Learn Summon action"
            end
        elseif not gems then
            Auto.waiting = "Cannot read gems; summon paused"
        end
    end
    if s.autoTrait and allowed("trait", math.max(2, s.traitDelay)) then
        if traitReached(s.traitTarget) and s.traitTarget ~= "" then
            s.autoTrait = false
            Store.saveSettings()
            uiNotify("Target trait detected; auto trait stopped")
        elseif Auto.traitRolls >= s.traitMaxRolls then
            s.autoTrait = false
            Store.saveSettings()
            uiNotify("Trait attempt limit reached; auto trait stopped")
        elseif Actions.perform("trait", { "REROLL TRAIT", "REROLL", "ROLL TRAIT" }) then
            Auto.traitRolls = Auto.traitRolls + 1
        else
            Auto.waiting = "Learn Trait Reroll action"
        end
    end
    for _, claim in ipairs({
        { enabled = s.claimDaily, slot = "daily" },
        { enabled = s.claimBP, slot = "battlepass" },
        { enabled = s.claimLevel, slot = "level" },
    }) do
        if claim.enabled and allowed(claim.slot, 35) then
            Actions.perform(claim.slot, {})
        end
    end
end

-- ======================================================================
--  INFINITE STOP AT WAVE: controlled sell -> wait for defeat -> replay.
--  A tower is only targeted at a SAVED placement coordinate, not an unrelated
--  player's model. If no placement macro / unit folder is available, it stops
--  safely rather than guessing random models and selling the wrong object.
-- ======================================================================
Infinite = { active = false, processing = false, finished = false, status = "Idle",
    sold = 0, skipped = 0, startedAt = 0, runId = -1, lastWave = 0 }
local function sellAtSavedPosition(step)
    local folder = Verify.folder()
    local camera = workspace.CurrentCamera
    if not folder or not camera or not step.pos then
        return false, "No verified unit folder / camera / XYZ"
    end
    local xyz = Vector3.new(unpack(step.pos))
    local before = Verify.countNear(folder, step.pos)
    if not before or before == 0 then return true, "Already absent" end
    -- One saved placement can identify a tower model near its saved position.
    -- Select with virtual input; this doesn't need the real mouse to move.
    local targetPos
    local smallest = 8
    for _, item in ipairs(folder:GetChildren()) do
        local p
        if item:IsA("Model") then
            local ok, cf = pcall(function() return item:GetPivot() end)
            if ok then p = cf.Position end
        elseif item:IsA("BasePart") then p = item.Position end
        if p and (p - xyz).Magnitude < smallest then
            smallest, targetPos = (p - xyz).Magnitude, p
        end
    end
    if not targetPos then return false, "Saved tower not found within 8 studs" end
    local point, visibleOnScreen = camera:WorldToViewportPoint(targetPos)
    if not visibleOnScreen or point.Z <= 0 then return false, "Tower out of view" end
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(point.X, point.Y, 0, true, game, 0)
        VIM:SendMouseButtonEvent(point.X, point.Y, 0, false, game, 0)
    end)
    if not ok then return false, "Could not select tower" end
    task.wait(0.22)
    local sell = directGameButton({ "SELL" })
    if not sell then return false, "Tower selected but SELL button not detected" end
    if not Actions.click(sell) then return false, "SELL button activation failed" end
    task.wait(0.45)
    local after = Verify.countNear(folder, step.pos)
    if after and after < before then return true, "Sold and confirmed" end
    return false, "Sell requested but unit disappearance not confirmed"
end
function Infinite.execute()
    if Infinite.processing then return end
    Infinite.processing = true
    local s = Store.settings
    if not s.stopWaveSell then
        Infinite.status = "Stop wave reached; waiting for defeat (sell disabled)"
        Infinite.finished, Infinite.processing = true, false
        return
    end
    if Actions.perform("sellAll", { "SELL ALL UNITS", "SELL ALL" }) then
        Infinite.status = "Sell All requested; waiting for defeat"
        Infinite.finished, Infinite.processing = true, false
        return
    end
    local macro = Macro.selected and Macro.library()[Macro.selected]
    if not macro or #(macro.steps or {}) == 0 then
        Infinite.status = "No saved placements; cannot safely sell towers"
        log(Infinite.status)
        Infinite.finished, Infinite.processing = true, false
        return
    end
    for idx = #macro.steps, 1, -1 do
        if not Core.alive or not Infinite.active or Detect.result then break end
        local step = macro.steps[idx]
        if step.kind == "place" and step.pos then
            local sold, reason = false, "unknown"
            for attempt = 1, math.clamp(tonumber(s.stopWaveMaxSellAttempts) or 3, 1, 10) do
                if not Core.alive or Detect.result or not Infinite.active then break end
                Infinite.status = string.format("Sell saved tower %d | try %d", idx, attempt)
                sold, reason = sellAtSavedPosition(step)
                if sold then break end
                task.wait(math.max(0.4, tonumber(s.stopWaveSellDelay) or 1))
            end
            if sold then Infinite.sold = Infinite.sold + 1
            else
                Infinite.skipped = Infinite.skipped + 1
                log("Stop-wave sell skipped tower " .. idx .. ": " .. tostring(reason))
            end
        end
    end
    Infinite.status = string.format("Stop-wave finished: %d sold / %d skipped; waiting for defeat",
        Infinite.sold, Infinite.skipped)
    Infinite.finished, Infinite.processing = true, false
    uiNotify(Infinite.status)
end
function Infinite.tick()
    local s = Store.settings
    if not s.stopWaveEnabled then
        Infinite.active = false
        Infinite.status = "Disabled"
        return
    end
    -- Reset the stop/sell once per new match, never once per wave.
    if Detect.inMatch and Detect.runId ~= Infinite.runId then
        Infinite.active, Infinite.processing, Infinite.finished = false, false, false
        Infinite.sold, Infinite.skipped = 0, 0
        Infinite.runId = Detect.runId
        Infinite.status = "Waiting for wave " .. tostring(s.stopWaveNumber)
    end
    if Detect.inMatch and Detect.wave and Detect.wave >=
        math.max(1, tonumber(s.stopWaveNumber) or 100) and not Infinite.active then
        Infinite.active = true
        Infinite.startedAt = os.clock()
        Infinite.status = "Stop wave reached; selling units"
        Macro.stopPlay()
        log("Infinite stop at wave " .. Detect.wave)
        task.spawn(function() safeCall(Infinite.execute) end)
    end
    Infinite.lastWave = Detect.wave or Infinite.lastWave
end

-- ======================================================================
--  RAID: visible UI flow only; don't guess game-specific remotes.
-- ======================================================================
local existingLedger = env.DarkyHubRaidLedger
local sameRaidServer = type(existingLedger) == "table" and
    existingLedger.place == game.PlaceId and existingLedger.job == game.JobId
Raid = {
    phase = "Idle", lastAction = "", milk = nil, observedMilk = nil,
    estimatedMilk = sameRaidServer and existingLedger.estimated or nil,
    confirmedAt = 0, source = "Not read", stageAdvances = sameRaidServer and (existingLedger.advances or 0) or 0,
    stage = sameRaidServer and (existingLedger.stage or 1) or 1,
    pendingResult = nil, pendingAt = 0, pendingAttempts = 0,
    pendingRun = 0, pendingDeducted = false,
    nearbyPrompt = nil, lastPromptAttempt = -100,
}
local function persistRaidLedger()
    env.DarkyHubRaidLedger = { place = game.PlaceId, job = game.JobId,
        estimated = Raid.estimatedMilk, advances = Raid.stageAdvances,
        stage = Raid.stage }
end
local function findVisibleText(query)
    query = clean(query)
    for _, e in ipairs(Detect.texts) do
        if e.text == query or e.text:find(query, 1, true) then return e end
    end
end
local function visibleContains(needle)
    return findVisibleText(needle) ~= nil
end
local function nearbyNumeric(label, maxDepth)
    local entry = findVisibleText(label)
    if not entry then return nil end
    local node = entry.obj.Parent
    for _ = 1, (maxDepth or 4) do
        if not node or node == playerGui then return nil end
        for _, child in ipairs(node:GetDescendants()) do
            if (child:IsA("TextLabel") or child:IsA("TextButton")) and visible(child) then
                local text = clean(child.Text)
                local n = text:match("YOU HAVE%s*X?%s*(%d+)") or text:match("^X%s*(%d+)$")
                if n then return tonumber(n) end
            end
        end
        node = node.Parent
    end
    return nil
end
connect(ProximityPromptService.PromptShown, function(prompt)
    local txt = clean(tostring(prompt.ActionText or "") .. " " .. tostring(prompt.ObjectText or "")
        .. " " .. tostring(prompt.Parent and prompt.Parent.Name or ""))
    if txt:find("RAID", 1, true) or txt:find("HALLOWEEN", 1, true) then
        Raid.nearbyPrompt = prompt
        Raid.phase = "Raid gate prompt nearby: " .. txt:sub(1, 50)
    end
end)
-- Explicitly prefer game-observed balance. The estimate is only a forecast
-- when stage transitions hide the raid inventory UI.
function Raid.scanMilk()
    local balance = getStat({ "BugMilk", "Bug Milk", "RaidMilk", "Milk", "Bug_Milk" })
    local source = balance ~= nil and "Game stat" or ""
    if balance == nil then
        balance = nearbyNumeric("BUG MILK", 4)
        if balance ~= nil then source = "Raid menu" end
    end
    if balance ~= nil then
        balance = math.max(0, math.floor(balance))
        -- If the same GUI/stat still shows the pre-click balance while the
        -- next stage loads, do not overwrite a provisional deduction.
        if Raid.pendingResult ~= nil and Raid.pendingDeducted
            and Raid.observedMilk ~= nil and balance == Raid.observedMilk then
            Raid.source = "Estimated while next stage loads (UI may be stale)"
            return
        end
        Raid.milk = balance
        Raid.observedMilk = balance
        Raid.estimatedMilk = balance
        Raid.confirmedAt = os.clock()
        Raid.source = source
        persistRaidLedger()
    elseif Raid.estimatedMilk ~= nil then
        Raid.source = "Estimated since last stage entry"
    elseif (Store.settings.raidMilkManual or 0) > 0 then
        Raid.source = "Manual input (unverified)"
    end
end
function Raid.balance()
    if Raid.estimatedMilk ~= nil then return Raid.estimatedMilk end
    local manual = tonumber(Store.settings.raidMilkManual) or 0
    if manual > 0 then return math.floor(manual) end
    return nil
end
function Raid.canAdvance(serial)
    local settings = Store.settings
    local left = Raid.balance()
    local cost = math.max(1, math.floor(tonumber(settings.raidMilkPerNextStage) or 1))
    if Raid.pendingResult == serial then
        if os.clock() - Raid.pendingAt < 12 then
            return false, "Waiting for server to load next raid stage"
        end
        if Raid.pendingAttempts >= math.max(1, settings.raidMaxNextAttempts or 3) then
            return false, "Next stage did not start after " .. Raid.pendingAttempts .. " attempts"
        end
        -- Retrying the SAME stage request never consumes the balance twice.
        return true, "Retrying pending stage"
    end
    if left ~= nil and left < math.max(cost, settings.raidMinMilk or 1) then
        return false, "NOT ENOUGH BUG MILK for next stage (" .. left .. " left; costs " .. cost .. ")"
    end
    if left == nil and settings.raidRequireKnownMilk then
        return false, "BUG MILK balance unknown; open raid menu or set manual count"
    end
    return true, "Ready"
end
function Raid.noteNextStage(serial)
    local isFirst = Raid.pendingResult ~= serial
    Raid.pendingResult = serial
    Raid.pendingAt = os.clock()
    Raid.pendingAttempts = isFirst and 1 or Raid.pendingAttempts + 1
    Raid.pendingRun = Detect.runId
    if isFirst then
        local previous = Raid.balance()
        if previous ~= nil then
            Raid.estimatedMilk = math.max(0, previous - math.max(1, math.floor(Store.settings.raidMilkPerNextStage or 1)))
            Raid.source = "ESTIMATE after Next Stage request"
        end
        Raid.pendingDeducted = true
        persistRaidLedger()
    end
    Raid.phase = "Next Stage requested; awaiting wave 1 confirmation"
end
function Raid.trackProgress()
    if Raid.pendingResult ~= nil and Detect.inMatch and
        Detect.runId ~= Raid.pendingRun then
        Raid.stageAdvances = Raid.stageAdvances + 1
        Raid.stage = Raid.stage + 1
        Raid.pendingResult = nil
        Raid.pendingDeducted = false
        Raid.pendingAttempts = 0
        Raid.phase = "Next raid stage entered; same map macro remains selected"
        persistRaidLedger()
    end
end
function Raid.tick()
    Raid.scanMilk()
    Raid.trackProgress()
    if not Store.settings.autoRaid or Detect.inMatch or Detect.result then return end
    local s = Store.settings
    local openPage = visibleContains("HALLOWEEN RAID") or visibleContains("START A RAID")
    if openPage then
        Raid.phase = "Halloween Raid page"
        local currentMilk = Raid.balance()
        if currentMilk and currentMilk < s.raidMinMilk then
            Raid.phase = "Not enough Bug Milk (have " .. currentMilk .. ")"
            return
        end
        if trim(s.raidStage) ~= "" and visibleContains(s.raidStage) and allowed("raid_stage", 6) then
            if Actions.challengeCard(s.raidStage) then
                Raid.phase = "Selected raid stage: " .. s.raidStage
                return
            end
        end
        if allowed("raid_open", 12) then
            if Actions.perform("raidOpen", { "OPEN RAID" }) then
                Raid.phase = "Opened raid lobby (milk is spent on entry, not opening)"
                return
            end
        end
    end
    -- Entering consumes the event currency. Do it only on an explicit opt-in.
    -- Never run a generic ENTER/START search on unrelated lobby menus.
    -- A visible raid-entry control or raid-specific confirmation is required.
    local entryReady = visibleContains("ENTER RAID") or visibleContains("JOIN RAID")
        or (visibleContains("RAID") and visibleContains("BUG MILK")
            and visibleContains("ENTER"))
    if s.raidAutoEnter and entryReady and allowed("raid_enter", 16) then
        local currentMilk = Raid.balance()
        if currentMilk ~= nil and currentMilk < s.raidMinMilk then
            Raid.phase = "Raid entry paused: below minimum Bug Milk"
            return
        end
        if s.raidSolo and Actions.perform("raidSolo", { "SOLO", "PLAY SOLO", "JOIN ALONE" }) then
            Raid.phase = "Selected solo raid"
        elseif Actions.perform("raidEnter", { "ENTER RAID", "ENTER", "START RAID", "START" }) then
            Raid.phase = "Requested raid entry"
        end
    end
    if not openPage and allowed("raid_page", 8) then
        local prompt = Raid.nearbyPrompt
        if prompt and prompt.Parent then
            local success = false
            if type(fireproximityprompt) == "function" then
                success = pcall(fireproximityprompt, prompt)
            else
                success = pcall(function()
                    prompt:InputHoldBegin()
                    task.wait(math.max(0, prompt.HoldDuration or 0) + 0.08)
                    prompt:InputHoldEnd()
                end)
            end
            Raid.phase = success and "Interacted with nearby raid gate" or "Raid prompt interaction failed"
        else
            local found = Actions.perform("raidPage", { "HALLOWEEN RAID", "RAID" })
            Raid.phase = found and "Opened raid menu" or
                "Raid badge not clickable; approach the raid gate until an E prompt appears"
        end
    end
end

-- ======================================================================
--  CANDY SHOP: reset-aware, bounded purchases by explicit item name
-- ======================================================================
local Shop = { status = "Shop not scanned", resetSeconds = nil,
    resets = 0, boughtThisReset = 0, boughtTotal = 0, lastResetAt = 0, recent = {} }
local function initializeCandyShop()
local function parseCountdown(s)
    local h, m, sec = s:match("(%d+):(%d%d):(%d%d)")
    if h then return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(sec) end
    m, sec = s:match("(%d+):(%d%d)")
    if m then return tonumber(m) * 60 + tonumber(sec) end
    return nil
end
local function shopItemNames()
    local items = {}
    for name in tostring(Store.settings.shopItems or ""):gmatch("[^,\n]+") do
        name = clean(name)
        if #name >= 2 and #items < 20 then table.insert(items, name) end
    end
    return items
end
local function findUniqueBuyFor(itemName)
    -- Only use BUY inside a card containing the exact configured item name.
    for _, e in ipairs(Detect.texts) do
        if e.text == itemName then
            local node = e.obj.Parent
            for _ = 1, 5 do
                if not node or node == playerGui then break end
                local buttons, sold = {}, false
                local seen = {}
                for _, child in ipairs(node:GetDescendants()) do
                    if (child:IsA("TextLabel") or child:IsA("TextButton")) and visible(child) then
                        local t = clean(child.Text)
                        if t == "SOLD OUT" or t == "PURCHASED" or t == "OWNED" then sold = true end
                        if t == "BUY" or t:find("^BUY%s+X?%d+") or t == "PURCHASE" then
                            local btn = buttonAncestor(child)
                            if btn and not seen[btn] then seen[btn] = true; table.insert(buttons, btn) end
                        end
                    end
                end
                if sold then return nil, "Sold out" end
                if #buttons == 1 then return buttons[1], nil end
                if #buttons > 1 then return nil, "Ambiguous purchase buttons" end
                node = node.Parent
            end
        end
    end
    return nil, "Item/card not visible"
end
function Shop.tick()
    if Detect.inMatch or Detect.result then return end
    local pageVisible = visibleContains("CANDY SHOP") or visibleContains("CANDY STORE")
    if not pageVisible then
        if Store.settings.autoShop and Store.settings.shopAutoOpen and allowed("shop_open", 12) then
            Actions.perform("shopOpen", { "CANDY SHOP", "CANDY STORE" })
        end
        Shop.status = "Open Candy Shop to scan reset and stock"
        return
    end
    local timer
    for _, e in ipairs(Detect.texts) do
        if e.text:find("RESET", 1, true) or e.text:find("RESTOCK", 1, true) then
            timer = parseCountdown(e.text)
            if not timer and e.obj.Parent then
                for _, sibling in ipairs(e.obj.Parent:GetDescendants()) do
                    if (sibling:IsA("TextLabel") or sibling:IsA("TextButton")) and visible(sibling) then
                        timer = parseCountdown(clean(sibling.Text))
                        if timer then break end
                    end
                end
            end
            if timer then break end
        end
    end
    if timer then
        if Shop.resetSeconds and timer > Shop.resetSeconds + 60 then
            Shop.resets = Shop.resets + 1
            Shop.boughtThisReset = 0
            Shop.recent = {}
            Shop.lastResetAt = os.clock()
            log("Candy Shop refresh detected; purchase quota reset")
        end
        Shop.resetSeconds = timer
    end
    local clockText = timer and (" | reset in " .. math.floor(timer / 60) .. "m " .. timer % 60 .. "s") or " | reset timer not found"
    Shop.status = "Shop open" .. clockText .. " | bought " .. Shop.boughtThisReset .. "/" .. Store.settings.shopMaxPerReset
    if not Store.settings.autoShop then return end
    if Shop.boughtThisReset >= Store.settings.shopMaxPerReset then return end
    if not allowed("shop_buy", math.max(3, Store.settings.shopInterval)) then return end
    local names = shopItemNames()
    if #names == 0 then Shop.status = "Enter item names to auto buy"; return end
    for _, item in ipairs(names) do
        if not Shop.recent[item] then
            local btn, reason = findUniqueBuyFor(item)
            if btn and Actions.click(btn) then
                Shop.recent[item] = true -- do not blindly click again: success may be server-side delayed
                Shop.boughtThisReset = Shop.boughtThisReset + 1
                Shop.boughtTotal = Shop.boughtTotal + 1
                Shop.status = "Purchase requested: " .. item .. clockText
                log("Candy Shop purchase requested: " .. item)
                return
            elseif reason == "Sold out" then
                Shop.status = item .. " sold out" .. clockText
            end
        end
    end
end

end -- initializeCandyShop
initializeCandyShop()

-- ======================================================================
--  DISCORD SESSION LOGGING: opt-in, throttle, no credential in exports
-- ======================================================================
Webhook = { queued = {}, sending = false, sent = 0, failed = 0,
    id = tostring(os.time()) .. "-" .. tostring(math.random(10000, 99999)), last = "Disabled" }
local function webhookValid(url)
    -- Only allow the actual Discord webhook API hostname (not lookalikes).
    return type(url) == "string" and #url < 512
        and (url:match("^https://discord%.com/api/webhooks/%d+/[%w_%-]+/?$")
         or url:match("^https://discordapp%.com/api/webhooks/%d+/[%w_%-]+/?$")) ~= nil
end
local function httpRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end
function Webhook.queue(event, details)
    local s = Store.settings
    if not s.webhookEnabled or not webhookValid(s.webhookUrl) then return end
    if #Webhook.queued >= 20 then table.remove(Webhook.queued, 1) end
    local message = string.format("**DarkyHub** | %s\nSession: `%s` | Map: `%s`\n%s",
        tostring(event):sub(1, 70), Webhook.id,
        tostring(Map.key):sub(1, 80), tostring(details or ""):sub(1, 1000))
    table.insert(Webhook.queued, message)
end
task.spawn(function()
    while Core.alive do
        task.wait(2.2)
        if #Webhook.queued > 0 and Store.settings.webhookEnabled then
            local content = table.remove(Webhook.queued, 1)
            local func = httpRequest()
            if not func then
                Webhook.failed = Webhook.failed + 1
                Webhook.last = "Executor has no HTTP request API"
            else
                local ok, response = pcall(func, {
                    Url = Store.settings.webhookUrl, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode({ content = content }),
                })
                local status = ok and type(response) == "table" and
                    (response.StatusCode or response.Status) or nil
                if ok and (status == 204 or status == 200) then
                    Webhook.sent = Webhook.sent + 1
                    Webhook.last = "Last Discord event delivered"
                else
                    Webhook.failed = Webhook.failed + 1
                    Webhook.last = "HTTP failed: " .. tostring(status or "no status")
                end
            end
        end
    end
end)
ResultEvent = function(kind)
    if not Store.settings.webhookResults then return end
    local rewardLines = #Detect.rewards > 0 and table.concat(Detect.rewards, "; ") or "No identifiable result labels"
    Webhook.queue("Match ended: " .. kind, string.format(
        "Wave %s/%s | Runs %d | XP tracked %d\nRewards: %s",
        tostring(Detect.wave or "?"), tostring(Detect.maxWave or "?"),
        Detect.runs, Detect.totalXP, rewardLines))
end
WaveEvent = function(wave, maximum)
    if Store.settings.webhookWaves then
        local every = math.max(1, tonumber(Store.settings.webhookWaveEvery) or 10)
        if wave % every == 0 then
            Webhook.queue("Wave milestone", string.format("Wave %d/%s reached", wave, tostring(maximum or "infinite")))
        end
    end
end

-- ======================================================================
--  DIAGNOSTICS: local-only snapshot to support live game investigation.
--  No HTTP or Discord sends. Never exports webhook credentials.
-- ======================================================================
local Diagnostics = { last = "Not captured", lastPath = "" }
local function inspectPath(obj, stopAt)
    local parts = {}
    for _ = 1, 9 do
        if not obj or obj == stopAt or obj == game then break end
        table.insert(parts, 1, tostring(obj.Name):sub(1, 60))
        obj = obj.Parent
    end
    return table.concat(parts, "/")
end
function Diagnostics.snapshot()
    -- Reuse cached GUI scanner. This never clicks anything.
    Detect.scan()
    local info = {
        format = "DarkyHub diagnostics v4.4", capturedAt = os.time(),
        stopWaveEnabled = Store.settings.stopWaveEnabled,
        stopWaveNumber = Store.settings.stopWaveNumber,
        infiniteStatus = Infinite and Infinite.status or "Unavailable",
        placeId = game.PlaceId, mapProfile = Map.key, detectedMap = Map.autoName,
        wave = Detect.wave, result = Detect.resultKind,
        selectedMacro = Macro.selected, recording = Macro.recording ~= nil,
        playing = Macro.playing, placementsDone = Macro.placementDone,
        dispatchedPlacements = Macro.dispatchedPlacements,
        expectedPlacements = Macro.expectedPlacements,
        placementFailures = Macro.failures, unverified = Macro.unverified,
        latestPlacementError = tostring(Macro.lastFailure or ""):sub(1, 180),
        autoUpgrade = Store.settings.autoUpgrade,
        upgradeInterval = Store.settings.upgradeInterval,
        upgradeButtonFound = directGameButton({ "UPGRADE ALL" }) ~= nil,
        raidState = Raid.phase, raidMilk = Raid.milk,
        raidMilkEstimate = Raid.balance(), raidStageAdvances = Raid.stageAdvances,
        raidMilkSource = Raid.source, raidAutoEnter = Store.settings.raidAutoEnter,
        gameButtons = {}, gameLabels = {}, remoteCalls = {}, nearbyPrompts = {},
    }
    local unitFolder = Verify.folder()
    info.unitFolder = unitFolder and inspectPath(unitFolder, workspace) or "Unknown"
    -- Button paths and text reveal whether actions are actually GUIButtons.
    for _, item in ipairs(Detect.buttons) do
        if #info.gameButtons >= 100 then break end
        local labelText = tostring(item.text or "")
        if not labelText:find("CHAT", 1, true) and #labelText < 160 then
            table.insert(info.gameButtons, { text = labelText,
                guiPath = inspectPath(item.button, playerGui),
                class = item.button.ClassName })
        end
    end
    for _, item in ipairs(Detect.texts) do
        if #info.gameLabels >= 130 then break end
        local val = tostring(item.text or "")
        if #val <= 120 and not val:find("CHAT", 1, true) then
            table.insert(info.gameLabels, { text = val,
                guiPath = inspectPath(item.obj, playerGui) })
        end
    end
    -- Report remote names / argument type shapes, never argument values.
    for i = 1, math.min(#Spy.events, 35) do
        local event = Spy.events[i]
        local encoded = (event.action or {}).args or {}
        local kinds = {}
        for j = 1, math.min(encoded.n or 0, 8) do
            local v = (encoded.a or {})[j]
            kinds[j] = type(v) == "table" and (v._t or "table") or type(v)
        end
        table.insert(info.remoteCalls, { name = tostring(event.name or ""):sub(1, 70),
            method = event.action.method, argumentTypes = kinds,
            hasWorldPosition = event.pos ~= nil })
    end
    -- Proximity prompts are often how the Halloween raid gate is opened.
    -- Only include prompts near the local player, bounded in count.
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        local scanned = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            scanned = scanned + 1
            if scanned > 9000 or #info.nearbyPrompts >= 45 then break end
            if obj:IsA("ProximityPrompt") then
                local adornee = obj.Parent
                local pos
                if adornee and adornee:IsA("BasePart") then
                    pos = adornee.Position
                elseif adornee and adornee:IsA("Model") then
                    local ok, pivot = pcall(function() return adornee:GetPivot() end)
                    if ok then pos = pivot.Position end
                end
                if pos and (pos - root.Position).Magnitude <= 65 then
                    table.insert(info.nearbyPrompts, {
                        path = inspectPath(obj, workspace),
                        actionText = tostring(obj.ActionText or ""):sub(1, 75),
                        objectText = tostring(obj.ObjectText or ""):sub(1, 75),
                        distance = math.floor((pos - root.Position).Magnitude + 0.5),
                    })
                end
            end
        end
    end
    return info
end
function Diagnostics.export()
    local info = Diagnostics.snapshot()
    local jsonOk, json = pcall(function() return HttpService:JSONEncode(info) end)
    if not jsonOk then uiNotify("Diagnostic JSON failed to encode"); return end
    local filename = Store.root .. "/live_diagnostics.json"
    local saved = writeJSON(filename, info)
    local copied = type(setclipboard) == "function" and pcall(setclipboard, json)
    Diagnostics.lastPath = saved and filename or "Not saved"
    Diagnostics.last = "GUI buttons: " .. #info.gameButtons
        .. ", calls: " .. #info.remoteCalls
        .. ", prompts: " .. #info.nearbyPrompts
    uiNotify(Diagnostics.last .. (saved and " | file: " .. filename or " | no disk access")
        .. (copied and " | clipboard copied" or ""))
    return info
end

-- ======================================================================
--  BACKUP: JSON import/export with map macros and per-map preferences
-- ======================================================================
local Backup = {}
function Backup.exportAll()
    local all = { version = 4, createdAt = os.time(), settings = shallowCopy(Store.settings),
        actions = Store.actions, maps = {}, mapConfig = {}, mapIndex = sortedKeys(Store.mapNames),
        runHistory = readJSON(Store.root .. "/run_history.json") }
    -- A publicly shared exported config must never contain the Discord credential.
    all.settings.webhookUrl = ""
    all.settings.webhookEnabled = false
    for _, name in ipairs(all.mapIndex) do
        all.maps[name] = Store.loadMap(name)
        local dir = Store.mapFolder(name)
        all.mapConfig[name] = (dir and readJSON(dir .. "/map_settings.json")) or {}
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(all) end)
    if not ok then uiNotify("Export failed: " .. tostring(encoded)); return end
    local path = Store.root .. "/DarkyHub_backup_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
    local saved = writeJSON(path, all)
    local copied = type(setclipboard) == "function" and pcall(setclipboard, encoded)
    uiNotify((saved and "Backup file saved " .. path or "Disk backup failed")
        .. (copied and " + copied to clipboard" or ""))
end
function Backup.importAll(raw)
    if type(raw) ~= "string" or #raw > 2000000 or #raw < 10 then
        uiNotify("Import requires a JSON backup under 2MB"); return
    end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(decoded) ~= "table" or decoded.version ~= 4 then
        uiNotify("Invalid DarkyHub v4 backup JSON"); return
    end
    if type(decoded.settings) == "table" then
        for k, v in pairs(decoded.settings) do
            if Store.settings[k] ~= nil and type(v) == type(Store.settings[k])
                and k ~= "webhookUrl" and k ~= "webhookEnabled" then
                Store.settings[k] = v
            end
        end
    end
    if type(decoded.actions) == "table" then
        for _, key in ipairs({ "slots", "join", "challenge" }) do
            if type(decoded.actions[key]) == "table" then
                Store.actions[key] = decoded.actions[key]
            end
        end
        if type(decoded.actions.placementTemplate) == "table" then
            Store.actions.placementTemplate = decoded.actions.placementTemplate
        end
    end
    local imported = 0
    if type(decoded.maps) == "table" then
        for key, library in pairs(decoded.maps) do
            if type(key) == "string" and #key > 0 and #key < 80 and type(library) == "table" then
                Store.registerMap(key)
                for name, macro in pairs(library) do
                    if type(name) == "string" and type(macro) == "table"
                        and type(macro.steps) == "table" and #macro.steps <= 500 then
                        Store.saveMacro(key, name, macro)
                        imported = imported + 1
                    end
                end
                local conf = decoded.mapConfig and decoded.mapConfig[key]
                if type(conf) == "table" then
                    local dir = Store.mapFolder(key)
                    if dir then writeJSON(dir .. "/map_settings.json", conf) end
                end
            end
        end
    end
    writeJSON(Store.settingsFile, Store.settings)
    Store.saveActions()
    Store.loadMapConfig(Map.key)
    Macro.loadSelection()
    Markers.show(Macro.selected and Macro.library()[Macro.selected])
    uiNotify("Imported " .. imported .. " macros; Discord URL intentionally unchanged")
end

task.spawn(function()
    while Core.alive do
        task.wait(2.5)
        safeCall(Raid.tick)
        safeCall(Shop.tick)
    end
end)

-- ======================================================================
--  PLAYER: retained from v1 with cleanup on unload
-- ======================================================================
local Player = { velocity = nil, gyro = nil, oldSpeed = nil }
local function humanoid()
    return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end
local function rootPart()
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
function Player.stopFly()
    if Player.velocity then Player.velocity:Destroy(); Player.velocity = nil end
    if Player.gyro then Player.gyro:Destroy(); Player.gyro = nil end
    local hum = humanoid()
    if hum then hum.PlatformStand = false end
end
connect(RunService.Heartbeat, function()
    if not Core.alive then return end
    local hum = humanoid()
    if hum then
        if Store.settings.walkEnabled then
            if not Player.oldSpeed then Player.oldSpeed = hum.WalkSpeed end
            hum.WalkSpeed = Store.settings.walkSpeed
        elseif Player.oldSpeed then
            hum.WalkSpeed = Player.oldSpeed
            Player.oldSpeed = nil
        end
    end
end)
connect(player.CharacterAdded, function()
    Player.stopFly()
    Player.oldSpeed = nil
end)
connect(UIS.JumpRequest, function()
    if Store.settings.infiniteJump and humanoid() then
        humanoid():ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
connect(RunService.Stepped, function()
    if not Store.settings.noclip then return end
    for _, p in ipairs((player.Character and player.Character:GetDescendants()) or {}) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)
connect(RunService.RenderStepped, function()
    if not Store.settings.fly then return end
    local root, hum, cam = rootPart(), humanoid(), workspace.CurrentCamera
    if not root or not hum or not cam then return end
    if not Player.velocity then
        Player.velocity = new("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9) }, root)
        Player.gyro = new("BodyGyro", { MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 10000 }, root)
    end
    hum.PlatformStand = true
    local d = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d = d - cam.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d = d - cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + cam.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then d = d + Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d = d - Vector3.yAxis end
    Player.velocity.Velocity = d.Magnitude > 0 and d.Unit * Store.settings.flySpeed or Vector3.zero
    Player.gyro.CFrame = cam.CFrame
end)
connect(player.Idled, function()
    if not Store.settings.antiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
end)

-- ======================================================================
--  UI: self-contained dark purple interface
-- ======================================================================
-- v5.4: default to minimizing during placement; the option persists in settings.
if Store.settings.minimizeOnPlacement == nil then Store.settings.minimizeOnPlacement = true end
local View = {}
local function setupInterface()
local UI = { page = "Match", pages = {}, tabButtons = {}, refreshed = {} }
local C = {
    bg = Color3.fromRGB(11, 12, 23), panel = Color3.fromRGB(22, 24, 40),
    section = Color3.fromRGB(29, 32, 52), top = Color3.fromRGB(17, 19, 34),
    accent = Color3.fromRGB(155, 119, 255), text = Color3.fromRGB(246, 247, 255),
    muted = Color3.fromRGB(160, 167, 190), off = Color3.fromRGB(51, 56, 78),
    danger = Color3.fromRGB(198, 72, 102), green = Color3.fromRGB(65, 197, 154),
}
GUI = new("ScreenGui", { Name = "DarkyHub_v4", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, nil)
if type(gethui) == "function" then pcall(function() GUI.Parent = gethui() end) end
if not GUI.Parent then
    pcall(function() GUI.Parent = game:GetService("CoreGui") end)
end
if not GUI.Parent then GUI.Parent = playerGui end
local cleanupRoots = { playerGui, game:GetService("CoreGui") }
if type(gethui) == "function" then
    local ok, root = pcall(gethui)
    if ok and root then table.insert(cleanupRoots, root) end
end
for _, root in ipairs(cleanupRoots) do
    for _, child in ipairs(root:GetChildren()) do
        if child ~= GUI and (child.Name == "DarkyHub_v3" or child.Name == "DarkyHub_v4") then
            pcall(function() child:Destroy() end)
        end
    end
end

-- Appearance presets are intentionally local to the view and never modify gameplay.
local appearancePresets = {
    Midnight = { bg = Color3.fromRGB(11,12,23), panel = Color3.fromRGB(22,24,40), section = Color3.fromRGB(29,32,52), top = Color3.fromRGB(17,19,34), accent = Color3.fromRGB(155,119,255), off = Color3.fromRGB(51,56,78) },
    Obsidian = { bg = Color3.fromRGB(9,10,12), panel = Color3.fromRGB(19,21,24), section = Color3.fromRGB(28,30,34), top = Color3.fromRGB(14,16,18), accent = Color3.fromRGB(255,184,94), off = Color3.fromRGB(52,54,59) },
    Ocean = { bg = Color3.fromRGB(9,19,29), panel = Color3.fromRGB(18,34,49), section = Color3.fromRGB(22,44,62), top = Color3.fromRGB(12,27,40), accent = Color3.fromRGB(62,197,230), off = Color3.fromRGB(44,71,88) },
    Emerald = { bg = Color3.fromRGB(10,20,19), panel = Color3.fromRGB(20,36,32), section = Color3.fromRGB(28,48,42), top = Color3.fromRGB(14,28,26), accent = Color3.fromRGB(83,224,160), off = Color3.fromRGB(47,75,64) },
    Rose = { bg = Color3.fromRGB(27,13,26), panel = Color3.fromRGB(44,24,43), section = Color3.fromRGB(57,33,54), top = Color3.fromRGB(34,18,34), accent = Color3.fromRGB(255,123,193), off = Color3.fromRGB(82,52,76) },
}
local function applyInitialPalette()
    local preset = appearancePresets[Store.settings.uiTheme] or appearancePresets.Midnight
    for key, value in pairs(preset) do C[key] = value end
end
applyInitialPalette()
local main = new("Frame", { Size = UDim2.fromOffset(880, 570),
    Position = UDim2.new(0.5, -440, 0.5, -285), BackgroundColor3 = C.bg,
    BorderSizePixel = 0, Active = true }, GUI)
corner(main, 12)
local mainScale = new("UIScale", { Scale = math.clamp(tonumber(Store.settings.uiScale) or 1, 0.75, 1.25) }, main)
local mainStroke = new("UIStroke", { Color = C.accent, Thickness = 1, Transparency = Store.settings.uiGlow == false and 0.9 or 0.35 }, main)
local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 44),
    BackgroundColor3 = C.top, BorderSizePixel = 0 }, main)
corner(bar, 12)
new("TextLabel", { Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(15, 0),
    Text = "DARKYHUB", Font = Enum.Font.GothamBold, TextSize = 20,
    TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1 }, bar)
new("TextLabel", { Size = UDim2.fromOffset(530, 40), Position = UDim2.fromOffset(147, 0),
    Text = "v5.9  |  " .. Store.playerName .. "  (@" .. player.Name .. ")", Font = Enum.Font.Gotham,
    TextSize = 11, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1 }, bar)
local close = new("TextButton", { Size = UDim2.fromOffset(38, 30),
    Position = UDim2.new(1, -43, 0, 6), BackgroundColor3 = C.danger,
    Text = "×", TextSize = 24, Font = Enum.Font.GothamBold, TextColor3 = C.text }, bar)
corner(close, 7)
connect(close.Activated, function() main.Visible = false end)
local sidePanel = new("Frame", { Position = UDim2.fromOffset(9, 53),
    Size = UDim2.new(0, 155, 1, -100), BackgroundColor3 = C.panel,
    BorderSizePixel = 0 }, main)
corner(sidePanel, 10)
new("UIStroke", { Color = C.off, Transparency = 0.7 }, sidePanel)
new("TextLabel", { Size = UDim2.new(1, -20, 0, 35),
    Position = UDim2.fromOffset(12, 9), BackgroundTransparency = 1,
    Text = "NAVIGATION", TextColor3 = C.muted,
    Font = Enum.Font.GothamBold, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left }, sidePanel)
local sidebar = new("ScrollingFrame", {
    Position = UDim2.fromOffset(7, 45),
    Size = UDim2.new(1, -14, 1, -54),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = C.accent,
    CanvasSize = UDim2.fromOffset(0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y }, sidePanel)
new("UIListLayout", { Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
local area = new("Frame", { Position = UDim2.fromOffset(172, 52),
    Size = UDim2.new(1, -183, 1, -96), BackgroundTransparency = 1 }, main)
local statusLine = new("TextLabel", { Position = UDim2.new(0, 12, 1, -34),
    Size = UDim2.new(1, -24, 0, 27), BackgroundColor3 = C.panel,
    TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.Gotham, TextSize = 11, Text = "Ready" }, main)
corner(statusLine, 6)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, statusLine)
local noteToken = 0
uiNotify = function(msg)
    log(msg)
    noteToken = noteToken + 1
    local token = noteToken
    if statusLine.Parent then statusLine.Text = tostring(msg) end
    task.delay(6, function()
        if Core.alive and token == noteToken and statusLine.Parent then
            statusLine.Text = "DarkyHub v5.9  |  RightShift to toggle"
        end
    end)
end

-- Drag, supporting mouse and touch.
local dragging, dragAt, origPos = false, nil, nil
-- PLACEMENT HUD MODULE (scoped to avoid Luau main-chunk register pressure).
-- Separate ScreenGui: remains visible even when the main hub is hidden for input playback.
do
    local hudGui = new("ScreenGui", {
        Name = "DarkyHubPlacementHUD", ResetOnSpawn = false,
        DisplayOrder = 1200, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    hudGui.Parent = GUI.Parent
    local panel = new("Frame", {
        Name = "PlacementStatus", Size = UDim2.fromOffset(296, 87),
        Position = UDim2.new(1, -312, 0, 64),
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
        Visible = false,
    }, hudGui)
    corner(panel, 9)
    new("UIStroke", { Color = C.accent, Transparency = 0.22, Thickness = 1 }, panel)
    local heading = new("TextLabel", {
        Size = UDim2.new(1, -18, 0, 25), Position = UDim2.fromOffset(9, 4),
        BackgroundTransparency = 1, Text = "DarkyHub  |  Placing Heroes",
        TextColor3 = C.accent, Font = Enum.Font.GothamBold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, panel)
    local details = new("TextLabel", {
        Size = UDim2.new(1, -18, 0, 47), Position = UDim2.fromOffset(9, 30),
        BackgroundTransparency = 1, Text = "Preparing placement...",
        TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 12,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, panel)
    local windowWasVisible = false
    local lastError = ""
    Macro.setPlacementHUD = function(active)
        if not Core.alive then return end
        if active then
            windowWasVisible = main.Visible
            if Store.settings.minimizeOnPlacement ~= false then main.Visible = false end
            panel.Visible = true
        else
            if Store.settings.minimizeOnPlacement ~= false then main.Visible = windowWasVisible end
            panel.Visible = false
        end
    end
    connect(game:GetService("RunService").Heartbeat, function()
        if not Core.alive or not panel.Visible then return end
        -- Throttle expensive text updates and preserve errors on the indicator.
        if not Macro._lastHud or os.clock() - Macro._lastHud > 0.35 then
            Macro._lastHud = os.clock()
            local message = tostring(Macro.step or "Placing...")
            local failure = tostring(Macro.lastFailure or "")
            if failure ~= "" and failure ~= lastError then lastError = failure end
            details.Text = message .. (lastError ~= "" and ("\n! " .. lastError) or "")
            heading.TextColor3 = lastError ~= "" and C.danger or C.accent
        end
    end)
    connect(panel.AncestryChanged, function(_, parent)
        if not parent then Macro.setPlacementHUD = nil end
    end)
    -- Ensure overlay disappears during unload; it is not a child of the main GUI.
    Core.placementHudGui = hudGui
end

connect(bar.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragAt, origPos = true, input.Position, main.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragAt
        main.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset + d.X,
            origPos.Y.Scale, origPos.Y.Offset + d.Y)
    end
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
connect(UIS.InputBegan, function(input, consumed)
    if not consumed and input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

local function column(parent, x, dx)
    local c = new("ScrollingFrame", { Size = UDim2.new(0.5, -5, 1, -1),
        Position = UDim2.new(x, dx, 0, 0), BackgroundTransparency = 1,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0 }, parent)
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, c)
    return c
end
function UI.pageCreate(name)
    local pane = new("Frame", { Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Visible = false }, area)
    UI.pages[name] = pane
    local icons = { Match = "◈", Macros = "▣", Home = "⌂", Raid = "◆",
        Shop = "◇", Discord = "◎", Spy = "◉", Player = "♙", Settings = "⚙" }
    local b = new("TextButton", { Size = UDim2.new(1, -3, 0, 39),
        BackgroundColor3 = C.section, Text = "  " .. (icons[name] or "•") .. "   " .. name,
        TextColor3 = C.muted, Font = Enum.Font.GothamBold,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = true, BorderSizePixel = 0 }, sidebar)
    corner(b, 8)
    local line = new("Frame", { Name = "SelectedIndicator",
        Size = UDim2.fromOffset(3, 23), Position = UDim2.new(0, 1, 0.5, -11),
        BackgroundColor3 = C.accent, BorderSizePixel = 0, Visible = false }, b)
    corner(line, 3)
    UI.tabButtons[name] = b
    connect(b.Activated, function() UI.show(name) end)
    return { L = column(pane, 0, 0), R = column(pane, 0.5, 5) }
end
function UI.show(name)
    UI.page = name
    Spy.enabled = (name == "Spy" or name == "Raid")
    for n, pane in pairs(UI.pages) do pane.Visible = n == name end
    for n, b in pairs(UI.tabButtons) do
        local selected = n == name
        b.BackgroundColor3 = selected and C.accent or C.section
        b.TextColor3 = selected and C.bg or C.muted
        local indicator = b:FindFirstChild("SelectedIndicator")
        if indicator then indicator.Visible = selected end
    end
end
local function initializeControls()
local function section(parent, title)
    local f = new("Frame", { Size = UDim2.new(1, -8, 0, 0),
        BackgroundColor3 = C.panel, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y }, parent)
    corner(f, 9)
    new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, f)
    new("UIListLayout", { Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder }, f)
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
        Text = title, TextColor3 = C.accent, Font = Enum.Font.GothamBold,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = -100 }, f)
    return f
end
local function label(parent, text, color)
    return new("TextLabel", { Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = text or "", TextColor3 = color or C.muted,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham,
        TextSize = 12 }, parent)
end
local function button(parent, title, fn, danger)
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 29),
        BackgroundColor3 = danger and C.danger or C.off,
        TextColor3 = C.text, Text = title, Font = Enum.Font.Gotham,
        TextSize = 12, AutoButtonColor = true }, parent)
    corner(btn, 5)
    connect(btn.Activated, function() safeCall(fn, btn) end)
    return btn
end
local toggles = {}
local function toggle(parent, title, key, callback)
    local t = new("TextButton", { Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, parent)
    new("TextLabel", { Size = UDim2.new(1, -53, 1, 0),
        BackgroundTransparency = 1, Text = title, TextColor3 = C.text,
        Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, t)
    local led = new("Frame", { Size = UDim2.fromOffset(43, 19),
        Position = UDim2.new(1, -43, 0.5, -9), BackgroundColor3 = C.off }, t)
    corner(led, 9)
    local dot = new("Frame", { Size = UDim2.fromOffset(15, 15),
        Position = UDim2.fromOffset(2, 2), BackgroundColor3 = C.text }, led)
    corner(dot, 8)
    local function sync()
        local v = Store.settings[key] == true
        led.BackgroundColor3 = v and C.accent or C.off
        dot.Position = v and UDim2.new(1, -17, 0, 2) or UDim2.fromOffset(2, 2)
    end
    toggles[key] = sync
    sync()
    connect(t.Activated, function()
        Store.settings[key] = not Store.settings[key]
        Store.saveSettings()
        sync()
        if callback then callback(Store.settings[key]) end
    end)
    return sync
end
local function refreshToggles()
    for _, sync in pairs(toggles) do sync() end
end
local function input(parent, title, initial, fn)
    label(parent, title, C.text)
    local tb = new("TextBox", { Size = UDim2.new(1, 0, 0, 27),
        BackgroundColor3 = C.off, BorderSizePixel = 0,
        Text = tostring(initial or ""), PlaceholderText = "Enter value",
        ClearTextOnFocus = false, TextColor3 = C.text,
        PlaceholderColor3 = C.muted, Font = Enum.Font.Gotham,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }, parent)
    corner(tb, 5)
    new("UIPadding", { PaddingLeft = UDim.new(0, 7) }, tb)
    connect(tb.FocusLost, function() safeCall(fn, trim(tb.Text)) end)
    return tb
end
local function numeric(parent, title, key, min, max)
    return input(parent, title, Store.settings[key], function(value)
        local v = tonumber(value)
        if not v then uiNotify("Invalid number for " .. title); return end
        Store.settings[key] = math.clamp(v, min, max)
        Store.saveSettings()
    end)
end
local function cycle(parent, title, optionsFn, onChange, preferred)
    label(parent, title, C.text)
    local btn = button(parent, "---", function() end)
    local active = nil
    local object = {}
    function object.refresh(preferred)
        local options = optionsFn()
        local desired = preferred or active
        if not desired or not table.find(options, desired) then desired = options[1] end
        active = desired
        btn.Text = active or "---"
        onChange(active)
    end
    function object.get() return active end
    -- Only one bound Activated handler controls cycling.
    -- The empty callback above is harmless and has no game effects.
    connect(btn.Activated, function()
        local options = optionsFn()
        if #options == 0 then object.refresh(nil); return end
        local index = table.find(options, active) or 0
        object.refresh(options[index % #options + 1])
    end)
    object.refresh(preferred)
    return object
end
local function learnButton(parent, title, store, key)
    return button(parent, title, function()
        Spy.learnNext(store, key)
    end)
end

-- MATCH TAB
local match = UI.pageCreate("Match")
local matchStatus = label(section(match.L, "Live match status"), "Scanning...", C.text)
local matchControls = section(match.L, "Wave and placement automation")
toggle(matchControls, "Auto Skip / Start Wave", "autoSkip")
toggle(matchControls, "Auto Upgrade AFTER placements", "autoUpgrade")
numeric(matchControls, "Upgrade interval (seconds)", "upgradeInterval", 0.5, 30)
numeric(matchControls, "Placement settle delay (seconds)", "placementDelay", 0.4, 15)
numeric(matchControls, "Minimum cash before trying placement", "minPlacementCash", 0, 1000000)
label(matchControls, "Failed placements retry every 10 seconds  Maximum 3 requests per position")
input(matchControls, "Tower unit folder (optional e.g. Units or Map.Units)", Store.settings.unitContainer, function(v)
    Store.settings.unitContainer = v; Store.saveSettings()
end)
label(matchControls, "If a unit folder is found, retries stop when a new tower spawns near the saved spot  Otherwise remote calls are unverified and not resent blindly")
label(matchControls, "Match type and raid behavior are controlled by the mode selector above.")
label(matchControls, "Upgrade All now uses the fast GUI button path. Macro completion or MANUAL confirmation is required.")
button(matchControls, "Confirm ALL manually placed units are ready", function()
    if not Detect.inMatch or Detect.result then
        uiNotify("Manual placement confirmation is only available in a match")
        return
    end
    if Macro.playing then
        uiNotify("Playback is still active; wait until it has placed all units")
        return
    end
    Macro.placementDone = true
    Macro.expectedPlacements = Store.settings.expectedPlacements
    Macro.step = "Manual confirmation: ALL units placed"
    uiNotify("Manual placement confirmed; auto upgrade now unlocked")
end)
label(matchControls, "Auto Upgrade unlocks after the first placement pass  Unconfirmed placement calls are not resent to avoid duplicate towers")
local infiniteSec = section(match.L, "Infinite mode: stop at wave & restart")
toggle(infiniteSec, "Stop at selected wave", "stopWaveEnabled")
numeric(infiniteSec, "Stop / sell all at wave", "stopWaveNumber", 1, 99999)
toggle(infiniteSec, "Sell saved towers at stop wave", "stopWaveSell")
toggle(infiniteSec, "Replay automatically after defeat", "stopWaveReplay")
numeric(infiniteSec, "Max sell attempts per saved tower", "stopWaveMaxSellAttempts", 1, 10)
numeric(infiniteSec, "Delay between sell attempts", "stopWaveSellDelay", 0.4, 10)
local infiniteState = label(infiniteSec, "Stop wave inactive", C.text)
label(infiniteSec, "When wave target arrives: disable skip/upgrade, sell towers at saved XYZ, then wait for enemies to end the run. If no known towers or button are available it will stop safely and report why. No instant restart remote is guessed.")
button(matchControls, "TEST Upgrade All ONE TIME now", function()
    if not Detect.inMatch then uiNotify("Upgrade test requires an active match"); return end
    local ok = performUpgradeAll()
    if not ok and Store.actions.slots.upgradeAll then ok = Actions.perform("upgradeAll", {}) end
    uiNotify(ok and "Upgrade All requested; check actual tower levels" or
        "Upgrade All not found: selected-unit UPGRADE is a different button")
end)
toggle(matchControls, "Fallback: upgrade one visible saved tower at a time", "individualUpgradeFallback")
numeric(matchControls, "Manual tower count to unlock upgrades (0 = off)", "manualUnitTarget", 0, 100)
label(matchControls, "If manual count is set, select the real tower folder above. Counts can be wrong if it contains enemies; use manual Confirm instead.")

local resultSec = section(match.R, "After each match")
local resultDD = cycle(resultSec, "Select ONE action", function()
    return { "Off", "Replay", "Next Stage", "Lobby" }
end, function(v)
    if v then Store.settings.resultMode = v; Store.saveSettings() end
end, Store.settings.resultMode)
toggle(resultSec, "Try Again automatically after defeat", "replayOnDefeat")
label(resultSec, "This choice OVERRIDES Raid and Challenge defaults. Next Stage on Raid: NEXT then POUR 1 BUG MILK then YES. Off never exits automatically.")
-- MODE SELECTOR: three workflows, with settings remembered separately for each mode.
-- This block remains within initializeControls to avoid main-chunk register pressure.
do
    local modes = { "INF / Story", "Challenge", "Raid" }
    local modeSection = section(match.L, "01  |  CHOOSE MATCH MODE")
    modeSection.LayoutOrder = -50
    local barRow = new("Frame", { Size = UDim2.new(1, 0, 0, 41),
        BackgroundTransparency = 1 }, modeSection)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, 5) }, barRow)
    local modeButtons = {}
    local explain = label(modeSection, "Choose a mode to show its controls", C.muted)
    local storyPanel = section(match.L, "STORY / INFINITE OPTIONS")
    storyPanel.LayoutOrder = -20
    label(storyPanel, "Stage-specific macros remain available from the Macros tab. Infinite wave-stop settings are shown below.")
    local challengePanel = section(match.L, "CHALLENGE OPTIONS")
    challengePanel.LayoutOrder = -20
    input(challengePanel, "Challenge card / stage name", Store.settings.challengeStage, function(v)
        Store.settings.challengeStage = v
        Store.saveSettings()
    end)
    toggle(challengePanel, "Auto Join Challenge", "autoChallenge")
    button(challengePanel, "Open advanced Challenge settings", function() UI.show("Home") end)
    local raidPanel = section(match.L, "RAID OPTIONS")
    raidPanel.LayoutOrder = -20
    toggle(raidPanel, "Auto open Halloween Raid", "autoRaid")
    toggle(raidPanel, "Enter raid automatically", "raidAutoEnter")
    toggle(raidPanel, "Join solo", "raidSolo")
    numeric(raidPanel, "Minimum Bug Milk", "raidMinMilk", 1, 500)
    button(raidPanel, "Open all Raid controls", function() UI.show("Raid") end)
    local keys = { "resultMode", "autoPlay", "autoSkip", "autoUpgrade",
        "autoRaid", "isRaidMatch", "autoChallenge", "autoJoin",
        "stopWaveEnabled", "raidAutoEnter", "raidSolo" }
    local defaults = {
        ["INF / Story"] = { resultMode = "Replay", autoRaid = false,
            isRaidMatch = false, autoChallenge = false, stopWaveEnabled = false },
        Challenge = { resultMode = "Lobby", autoRaid = false,
            isRaidMatch = false, autoChallenge = true, stopWaveEnabled = false },
        Raid = { resultMode = "Next Stage", autoRaid = false,
            isRaidMatch = true, autoChallenge = false, stopWaveEnabled = false },
    }
    if type(Store.settings.modeProfiles) ~= "table" then Store.settings.modeProfiles = {} end
    local profiles = Store.settings.modeProfiles
    local active = Store.settings.matchMode
    if not table.find(modes, active) then active = "INF / Story" end
    if not next(profiles) then
        if Store.settings.isRaidMatch or Store.settings.autoRaid then
            active = "Raid"
        elseif Store.settings.autoChallenge then
            active = "Challenge"
        end
    end
    local function snapshot()
        local state = {}
        for _, key in ipairs(keys) do state[key] = Store.settings[key] end
        profiles[active] = state
    end
    local function selectMode(target, initial)
        if not table.find(modes, target) then return end
        if not initial then snapshot() end
        active = target
        Store.settings.matchMode = active
        local saved = profiles[target]
        if type(saved) ~= "table" then
            saved = {}
            for key, val in pairs(defaults[target]) do saved[key] = val end
        end
        for key, val in pairs(saved) do
            if Store.settings[key] ~= nil and type(val) == type(Store.settings[key]) then
                Store.settings[key] = val
            end
        end
        -- A Raid is always a raid, regardless of stale saved toggles.
        Store.settings.isRaidMatch = target == "Raid"
        if target == "Challenge" then Store.settings.autoRaid = false end
        storyPanel.Visible = target == "INF / Story"
        infiniteSec.Visible = target == "INF / Story"
        challengePanel.Visible = target == "Challenge"
        raidPanel.Visible = target == "Raid"
        for name, btn in pairs(modeButtons) do
            local selected = name == target
            btn.BackgroundColor3 = selected and C.accent or C.off
            btn.TextColor3 = selected and C.bg or C.text
        end
        if target == "Raid" then
            explain.Text = "RAID  |  NEXT > POUR BUG MILK > YES after victory"
        elseif target == "Challenge" then
            explain.Text = "CHALLENGE  |  auto-select your challenge card and join"
        else
            explain.Text = "STORY / INFINITE  |  automatic placements, upgrades and wave skip"
        end
        refreshToggles()
        resultDD.refresh(Store.settings.resultMode)
        Store.saveSettings()
    end
    for _, name in ipairs(modes) do
        local b = new("TextButton", { Size = UDim2.new(0.32, -3, 1, 0),
            Text = name, BackgroundColor3 = C.off, TextColor3 = C.text,
            Font = Enum.Font.GothamBold, TextSize = 12,
            AutoButtonColor = false }, barRow)
        corner(b, 8)
        modeButtons[name] = b
        connect(b.Activated, function() selectMode(name, false) end)
    end
    selectMode(active, true)
end
local rewardSec = section(match.R, "Run tracker")
local rewardsInfo = label(rewardSec, "Runs 0", C.text)
button(rewardSec, "Reset run counters", function()
    Detect.runs, Detect.totalXP, Detect.rewards = 0, 0, {}
    Detect.wins, Detect.losses, Detect.history = 0, 0, {}
    uiNotify("Run counters reset")
end)

-- MACROS TAB
local macrosPage = UI.pageCreate("Macros")
local recSec = section(macrosPage.L, "Record placement macro")
-- A compact in-match macro selector is also available on the Match page.
-- It uses the same library and selected-name state as the Macros page.
local macroNameText = ""
input(recSec, "New macro name", "", function(v) macroNameText = v end)
local recordButton, macroDD
recordButton = button(recSec, "START RECORDING", function()
    if Macro.recording then
        if Macro.stopRecord() then
            macroDD.refresh(Macro.selected)
        end
        recordButton.Text = "START RECORDING"
    elseif Macro.startRecord(macroNameText) then
        recordButton.Text = "STOP AND SAVE RECORDING"
    end
end)
label(recSec, "Recording saves position markers even if no placement remote is captured. Only remote-based steps can replay without mouse movement. Enable click fallback before recording and select hotkey 1-6 before placing.")
local playSec = section(macrosPage.R, "Per-map macro playback")
toggle(playSec, "Prefer placement remotes", "remoteOnly")
toggle(playSec, "Hybrid fallback for marker-only placements", "allowScreenFallback")
toggle(playSec, "Minimize DarkyHub during placements", "minimizeOnPlacement")
toggle(playSec, "Restore recorded camera for input placement", "useRecordedCamera")
toggle(playSec, "Honor the wave each placement was recorded on", "placementByWave")
local mapInfo = label(playSec, "Current map: " .. Map.name, C.text)
macroDD = cycle(playSec, "Macro for current map", function()
    return sortedKeys(Macro.library())
end, function(v)
    if Macro.selected ~= v then Macro.select(v) end
end, Macro.selected)
local matchMacroSec = section(match.R, "Match macro controls")
local matchMacroDD = cycle(matchMacroSec, "Selected macro on current map", function()
    return sortedKeys(Macro.library())
end, function(v)
    if Macro.selected ~= v then Macro.select(v) end
    macroDD.refresh(v)
end, Macro.selected)
toggle(matchMacroSec, "Auto-start selected macro at wave 1", "autoPlay")
local macroPlayButton = button(matchMacroSec, "PLAY MACRO", function(btn)
    if Macro.playing then
        Macro.stopPlay()
        btn.Text = "PLAY MACRO"
        btn.BackgroundColor3 = C.green
        uiNotify("Macro stopped")
    else
        Macro.startPlay()
        btn.Text = Macro.playing and "STOP MACRO" or "PLAY MACRO"
        btn.BackgroundColor3 = Macro.playing and C.danger or C.green
    end
end)
macroPlayButton.BackgroundColor3 = C.green
-- Keep one button synchronized with automatic playback and match transitions.
task.spawn(function()
    local previous = nil
    while Core.alive do
        task.wait(0.5)
        if Macro.playing ~= previous and macroPlayButton.Parent then
            previous = Macro.playing
            macroPlayButton.Text = previous and "STOP MACRO" or "PLAY MACRO"
            macroPlayButton.BackgroundColor3 = previous and C.danger or C.green
        end
    end
end)
button(matchMacroSec, "Refresh map macros", function()
    Store.macros[Map.key] = nil
    Store.loadMap(Map.key)
    Macro.loadSelection()
    macroDD.refresh(Macro.selected)
    matchMacroDD.refresh(Macro.selected)
end)
label(matchMacroSec, "Current map and stage macros are saved in the Macros tab. The selected macro also appears here.")
toggle(playSec, "Auto Play on match start", "autoPlay", function(v)
    if v and Detect.inMatch and Detect.wave and Detect.wave <= 1 and not Macro.playing then Macro.startPlay() end
end)
local modeDD = cycle(playSec, "Playback timing", function() return { "Timed", "Fixed" } end,
    function(v)
        if v then Store.settings.playbackMode = v; Store.saveSettings() end
    end, Store.settings.playbackMode)
numeric(playSec, "Fixed action delay (seconds)", "fixedStepDelay", 0.05, 30)
toggle(playSec, "Save placement markers from clicks", "captureClickFallback")
numeric(playSec, "Current tower slot (1 to 6)", "selectedSlot", 1, 6)
label(playSec, "Hybrid mode first uses placement remotes if captured. Marker-only steps use simulated hotkeys and screen input at the saved XYZ. Saved camera data improves accuracy. Old macros without camera data need the same camera angle. Verify an actual tower spawned before relying on replay.")
button(playSec, "PLAY selected macro NOW", function() Macro.startPlay() end)
button(playSec, "STOP playback", function() Macro.stopPlay() end, true)
button(playSec, "Refresh macro list", function()
    Store.macros[Map.key] = nil
    Store.loadMap(Map.key)
    macroDD.refresh(Macro.selected)
    Markers.show(Macro.selected and Macro.library()[Macro.selected])
end)
button(playSec, "Delete selected macro", function()
    if Macro.selected then
        Store.deleteMacro(Map.key, Macro.selected)
        Macro.select(nil)
        macroDD.refresh(nil)
        uiNotify("Macro deleted")
    end
end, true)
local visualSec = section(macrosPage.L, "Placement markers")
toggle(visualSec, "Show placement markers in world", "showMarkers", function()
    Markers.show(Macro.selected and Macro.library()[Macro.selected])
end)
button(visualSec, "Refresh markers", function()
    Markers.show(Macro.selected and Macro.library()[Macro.selected])
end)
button(visualSec, "Clear markers", function() Markers.clear() end)
local placementsInfo = label(visualSec, "No placements saved for selected map", C.text)
button(visualSec, "SHOW saved placements + markers", function()
    local macro = Macro.selected and Macro.library()[Macro.selected]
    if not macro then uiNotify("Select a macro on this map first"); return end
    Markers.show(macro)
    local lines = {}
    for index, step in ipairs(macro.steps or {}) do
        local p = step.pos or {}
        table.insert(lines, string.format("#%d W%d $%d %s XYZ %.1f, %.1f, %.1f", index,
            step.wave or 1, step.minCash or 0, tostring(step.unit or "Tower"),
            p[1] or 0, p[2] or 0, p[3] or 0))
    end
    placementsInfo.Text = #lines > 0 and table.concat(lines, "\n") or "No placements"
end)
label(visualSec, "Markers show saved world XYZ. Edit placement wave/cash below if needed.")
local editingStepIndex, editingWave, editingCash = 1, 1, 0
input(visualSec, "Saved placement index to edit", "1", function(v)
    editingStepIndex = math.max(1, math.floor(tonumber(v) or 1))
end)
input(visualSec, "Place on wave number", "1", function(v)
    editingWave = math.max(1, math.floor(tonumber(v) or 1))
end)
input(visualSec, "Minimum cash for this placement (0 = no minimum)", "0", function(v)
    editingCash = math.max(0, math.floor(tonumber(v) or 0))
end)
button(visualSec, "SAVE wave/cash for selected placement", function()
    local m = Macro.selected and Macro.library()[Macro.selected]
    if not m or not m.steps or not m.steps[editingStepIndex] then
        uiNotify("No saved placement at index " .. editingStepIndex)
        return
    end
    local step = m.steps[editingStepIndex]
    step.wave = editingWave
    step.minCash = editingCash
    local _, saved = Store.saveMacro(Map.key, Macro.selected, m)
    uiNotify("Placement #" .. editingStepIndex .. " set to wave " .. editingWave
        .. " | cash " .. editingCash .. (saved and " (saved to disk)" or " (memory only)"))
    Markers.show(m)
end)
local mapSec = section(macrosPage.L, "MAP PROFILES — choose map BEFORE recording")
local namedMap = Store.settings.mapOverride ~= "" and Store.settings.mapOverride or Map.name
input(mapSec, "Dungeon / map name e.g. Frosty Fudge Pass", namedMap, function(v)
    namedMap = v
end)
local function selectMap(name)
    if trim(name) == "" then uiNotify("Enter a readable map name first"); return end
    Map.choose(name)
    Macro.stopPlay()
    Macro.loadSelection()
    macroDD.refresh(Macro.selected)
    uiNotify("Selected map profile: " .. Map.name)
end
button(mapSec, "USE / CREATE THIS MAP PROFILE", function() selectMap(namedMap) end)
local mapListReady = false
local savedMapDD = cycle(mapSec, "Saved map profiles (click to cycle)", function()
    return sortedKeys(Store.mapNames)
end, function(v)
    if mapListReady and v and v ~= Map.key then selectMap(v) end
end, Store.mapNames[Map.name] and Map.name or nil)
mapListReady = true
button(mapSec, "REFRESH MAP PROFILE LIST", function()
    savedMapDD.refresh(Map.key)
    macroDD.refresh(Macro.selected)
end)
button(mapSec, "AUTO DETECT MAP (remove manual selection)", function()
    Store.settings.mapOverride = ""
    Store.settings.activeMap = ""
    Store.saveSettings()
    Map.refresh(); Macro.loadSelection(); macroDD.refresh(Macro.selected)
    uiNotify("Auto map detection: " .. Map.name)
end)
label(mapSec, "The game may hide its dungeon name in scripts  Select a readable profile here and save macros inside that named map")

-- HOME TAB
local home = UI.pageCreate("Home")
local summonSec = section(home.L, "Summons")
toggle(summonSec, "Auto Summon", "autoSummon")
numeric(summonSec, "Summon interval (seconds)", "summonDelay", 1.5, 60)
numeric(summonSec, "Keep at least this many gems", "keepGems", 0, 999999999)
learnButton(summonSec, "Learn Summon action", Store.actions.slots, "summon")
local traitSec = section(home.L, "Trait rerolls")
toggle(traitSec, "Auto Trait Reroll", "autoTrait", function(v)
    if v then Auto.traitRolls = 0 end
end)
input(traitSec, "Target trait (optional)", Store.settings.traitTarget, function(v)
    Store.settings.traitTarget = v
    Store.saveSettings()
end)
numeric(traitSec, "Maximum rerolls per session", "traitMaxRolls", 1, 5000)
numeric(traitSec, "Seconds between rerolls", "traitDelay", 2, 60)
learnButton(traitSec, "Learn Trait Reroll action", Store.actions.slots, "trait")
label(traitSec, "Stops at the roll limit  Target detection needs a visible trait label containing both TRAIT and your chosen name")
local claimSec = section(home.L, "Rewards")
toggle(claimSec, "Auto Daily Claim", "claimDaily")
toggle(claimSec, "Auto Battlepass Claim", "claimBP")
toggle(claimSec, "Auto Level Claim", "claimLevel")
learnButton(claimSec, "Learn Daily claim", Store.actions.slots, "daily")
learnButton(claimSec, "Learn Battlepass claim", Store.actions.slots, "battlepass")
learnButton(claimSec, "Learn Level claim", Store.actions.slots, "level")

local profileSec = section(home.R, "Auto join and challenge")
input(profileSec, "Challenge card name from GUI (e.g. FROSTY FUDGE PASS)",
    Store.settings.challengeStage, function(v)
    Store.settings.challengeStage = v
    Store.saveSettings()
end)
label(profileSec, "Challenge card PLAY buttons are found automatically by the stage name shown on the Challenges screen - no learning needed")
local joinName, challengeName = "", ""
local joinDD = cycle(profileSec, "Saved join profile", function()
    return sortedKeys(Store.actions.join)
end, function(v) Auto.selectedJoin = v end)
input(profileSec, "New join profile name", "", function(v) joinName = v end)
button(profileSec, "Learn JOIN (then join manually)", function()
    if joinName == "" then uiNotify("Enter join profile name") return end
    Spy.learnNext(Store.actions.join, joinName, function() joinDD.refresh(joinName) end)
end)
toggle(profileSec, "Auto Join", "autoJoin")
local challengeDD = cycle(profileSec, "Saved challenge profile", function()
    return sortedKeys(Store.actions.challenge)
end, function(v) Auto.selectedChallenge = v end)
input(profileSec, "New challenge profile name", "", function(v) challengeName = v end)
button(profileSec, "Learn CHALLENGE (then start manually)", function()
    if challengeName == "" then uiNotify("Enter challenge profile name") return end
    Spy.learnNext(Store.actions.challenge, challengeName,
        function() challengeDD.refresh(challengeName) end)
end)
toggle(profileSec, "Auto Challenge", "autoChallenge")
label(profileSec, "Challenge has priority  If you set a card name it uses its PLAY button without any learned remote  Auto Join remains an optional learned profile for other lobby screens")
button(profileSec, "Delete selected join", function()
    if Auto.selectedJoin then Store.actions.join[Auto.selectedJoin] = nil end
    Store.saveActions(); joinDD.refresh(nil)
end, true)
button(profileSec, "Delete selected challenge", function()
    if Auto.selectedChallenge then Store.actions.challenge[Auto.selectedChallenge] = nil end
    Store.saveActions(); challengeDD.refresh(nil)
end, true)

-- RAID TAB
local raidPage = UI.pageCreate("Raid")
local raidOptions = section(raidPage.L, "Halloween Raid / Dungeon Raid")
toggle(raidOptions, "This match is a Raid (NEXT / Pour Milk)", "isRaidMatch")
toggle(raidOptions, "Auto open Halloween Raid", "autoRaid")
toggle(raidOptions, "Join alone / solo", "raidSolo")
toggle(raidOptions, "Auto ENTER (spends Bug Milk)", "raidAutoEnter")
numeric(raidOptions, "Minimum Bug Milk balance to start", "raidMinMilk", 1, 500)
numeric(raidOptions, "Bug Milk cost per NEXT STAGE", "raidMilkPerNextStage", 1, 5)
numeric(raidOptions, "Manual Bug Milk count (0 = read from UI)", "raidMilkManual", 0, 9999)
toggle(raidOptions, "Pause next stage if milk balance unknown", "raidRequireKnownMilk")
toggle(raidOptions, "Return to Hub when milk is insufficient", "raidReturnWhenOutOfMilk")
numeric(raidOptions, "Max next stage button retries", "raidMaxNextAttempts", 1, 8)
input(raidOptions, "Preferred raid stage name (optional)", Store.settings.raidStage, function(v)
    Store.settings.raidStage = v; Store.saveSettings()
end)
toggle(raidOptions, "Choose Next Stage after a raid win", "raidNextStage")
toggle(raidOptions, "Return to Hub after raid defeat", "raidReturnOnDefeat")
label(raidOptions, "Each Next Stage consumes Bug Milk (default 1). The SAME map macro plays again on its next wave 1. Balance after clicking Next Stage is an estimate until the game shows a new balance. Raid OPEN is free; ENTER uses milk and requires its own opt-in.")
local raidCurrent = label(section(raidPage.R, "Live raid state + milk budget"), "Not scanned", C.text)
button(raidPage.R, "REFRESH milk from visible game menu", function()
    Detect.scan()
    Raid.scanMilk()
    uiNotify(Raid.observedMilk ~= nil and
        ("Read Bug Milk: " .. Raid.observedMilk .. " (" .. Raid.source .. ")") or
        "No Bug Milk balance visible; open Halloween Raid menu and refresh")
end)
button(raidPage.R, "APPLY manual Bug Milk amount as estimate", function()
    local manual = math.floor(tonumber(Store.settings.raidMilkManual) or 0)
    if manual < 1 then
        uiNotify("Set a positive manual count first then APPLY")
        return
    end
    Raid.estimatedMilk = manual
    Raid.source = "Manual estimate (not verified by game)"
    persistRaidLedger()
    uiNotify("Raid Bug Milk estimate set to " .. manual)
end)
button(raidPage.R, "RESET stage counter to 1", function()
    Raid.stage = 1; Raid.stageAdvances = 0
    Raid.pendingResult = nil; Raid.pendingAttempts = 0
    persistRaidLedger()
    uiNotify("Raid stage counter reset; milk balance unchanged")
end)
button(raidPage.R, "EXPORT LIVE RAID / GUI DIAGNOSTICS", function()
    Diagnostics.export()
end)
label(raidPage.R, "While the raid screen is open, export diagnostics to DarkyHubV4/live_diagnostics.json. This records visible GUI labels and nearby raid prompts, without opening/spending milk.")
button(raidPage.R, "Open raid menu NOW", function()
    local found = Actions.perform("raidPage", { "HALLOWEEN RAID", "RAID" })
    uiNotify(found and "Clicked raid menu" or "Open the Raid Gate manually to expose the UI")
end)
button(raidPage.R, "Open raid NOW (does not spend milk)", function()
    if not Actions.perform("raidOpen", { "OPEN RAID" }) then
        uiNotify("OPEN RAID not found on screen")
    end
end)
button(raidPage.R, "ENTER RAID NOW (may spend milk)", function()
    local ok = Actions.perform("raidEnter", { "ENTER RAID", "ENTER", "START RAID" })
    uiNotify(ok and "Sent raid entry" or "No raid entry button visible")
end)

-- SHOP TAB
local shopPage = UI.pageCreate("Shop")
local shopConfig = section(shopPage.L, "Candy Shop auto buy")
toggle(shopConfig, "Auto buy selected Candy Shop items", "autoShop")
toggle(shopConfig, "Auto open Candy Shop menu", "shopAutoOpen")
input(shopConfig, "ITEM NAMES (comma separated; exact names)", Store.settings.shopItems, function(v)
    Store.settings.shopItems = v; Store.saveSettings()
end)
numeric(shopConfig, "Max purchase requests PER reset", "shopMaxPerReset", 1, 50)
numeric(shopConfig, "Check interval (seconds)", "shopInterval", 3, 60)
label(shopConfig, "It scans visible shop cards and the RESTOCK/RESET countdown. If timer jumps upward, the purchase quota resets. Confirm the exact item name first; attempts are capped per reset.")
local shopStatus = label(section(shopPage.R, "Stock and reset tracker"), "Candy Shop not scanned", C.text)
button(shopPage.R, "Scan visible Candy Shop NOW", function()
    Detect.scan(); Shop.tick(); uiNotify(Shop.status)
end)
button(shopPage.R, "Reset purchase quota manually", function()
    Shop.boughtThisReset = 0
    Shop.recent = {}
    uiNotify("Candy Shop purchase quota reset manually")
end)

-- DISCORD TAB
local discordPage = UI.pageCreate("Discord")
local discordConfig = section(discordPage.L, "Discord webhook (optional)")
toggle(discordConfig, "Send Discord notifications", "webhookEnabled", function(v)
    if v then Webhook.queue("Hub started", "Notifications enabled for this execution") end
end)
local webhookBox = input(discordConfig, "Discord Webhook URL (stored locally; hidden in exports)", "", function(value)
    if value == "" then return end
    if webhookValid(value) then
        Store.settings.webhookUrl = value
        Store.saveSettings()
        uiNotify("Webhook saved locally. It is not printed or exported.")
    else
        uiNotify("Invalid Discord webhook URL")
    end
end)
webhookBox.Text = "" -- never echo stored token into the GUI field
local webhookStatus = label(section(discordPage.R, "Webhook status"), "Not enabled", C.text)
toggle(discordConfig, "Send win / defeat + end rewards", "webhookResults")
toggle(discordConfig, "Send infinite-wave milestones", "webhookWaves")
numeric(discordConfig, "Notify every N waves", "webhookWaveEvery", 1, 100)
toggle(discordConfig, "Attempt disconnect alerts", "webhookDisconnect")
button(discordPage.L, "SEND TEST Discord message", function()
    Webhook.queue("Test notification", "Manual test from in-game hub")
    uiNotify("Test queued; see Discord status after a few seconds")
end)
button(discordPage.L, "CLEAR STORED WEBHOOK", function()
    Store.settings.webhookUrl = ""
    Store.settings.webhookEnabled = false
    writeJSON(Store.root .. "/settings.json", Store.settings)
    webhookBox.Text = ""
    uiNotify("Webhook cleared from current settings")
end, true)
label(discordConfig, "A network disconnect can prevent the outgoing HTTP request. Notifications are best effort, not guaranteed.")

-- SPY TAB
local spyPage = UI.pageCreate("Spy")
local eventsSec = section(spyPage.L, "Recent game remotes")
local spyState = label(eventsSec, Spy.available and "Listening for RemoteEvent / RemoteFunction calls"
    or "Executor cannot hook remotes", C.text)
local selectedEvent = label(eventsSec, "Select a remote event to inspect", C.muted)
local spyContainer = new("Frame", { Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y }, eventsSec)
new("UIListLayout", { Padding = UDim.new(0, 4) }, spyContainer)
local spyLastRevision = -1
local function refreshSpy()
    if spyLastRevision == Spy.changed then return end
    spyLastRevision = Spy.changed
    for _, child in ipairs(spyContainer:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    for i = 1, math.min(#Spy.events, 14) do
        local event = Spy.events[i]
        local item = button(spyContainer, i .. "  " .. event.name .. "  [" .. event.kind .. "]", function()
            Spy.selected = i
            Spy.selectedEvent = event
            selectedEvent.Text = event.name .. "  " .. (event.action.method or "")
                .. "\n" .. event.preview .. "\n" .. table.concat(event.action.path, ".")
        end)
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.TextSize = 10
    end
end
local spyControl = section(spyPage.R, "Spy / learning tools")
button(spyControl, "Clear remote list", function()
    Spy.events = {}; Spy.selected = 1; Spy.selectedEvent = nil; Spy.changed = Spy.changed + 1
    selectedEvent.Text = "Select a remote event"
    refreshSpy()
end)
button(spyControl, "Cancel learn mode", function()
    Spy.learn = nil; uiNotify("Learn cancelled")
end)
local slot = "upgradeAll"
cycle(spyControl, "Slot for selected event", function()
    return { "upgradeAll", "sellAll", "skipWave", "replay", "nextStage", "lobby",
        "summon", "trait", "daily", "battlepass", "level" }
end, function(v) slot = v or "upgradeAll" end)
button(spyControl, "SAVE selected remote into slot", function()
    Spy.selectAction(Store.actions.slots, slot)
end)
label(spyControl, "Spy records normal player remotes  If an incorrect remote was learned select the correct call here and save it into that action slot")
button(spyControl, "SET SELECTED CALL AS PLACEMENT", function()
    Spy.captureSelectedPlacement()
end)
label(spyControl, "Do this only if the game does not name its place remote  GUI result buttons require no learning")
local diagnostic = label(section(spyPage.R, "Diagnostics"), "...", C.text)

-- PLAYER TAB
local playerPage = UI.pageCreate("Player")
local moveSec = section(playerPage.L, "Movement")
toggle(moveSec, "Walk speed override", "walkEnabled")
numeric(moveSec, "Walk speed", "walkSpeed", 16, 250)
toggle(moveSec, "Infinite jump", "infiniteJump")
toggle(moveSec, "Noclip", "noclip")
local flySec = section(playerPage.R, "Flight")
toggle(flySec, "Fly (W A S D / Space / Ctrl)", "fly", function(v)
    if not v then Player.stopFly() end
end)
numeric(flySec, "Fly speed", "flySpeed", 5, 400)
local utilitySec = section(playerPage.R, "Client")
toggle(utilitySec, "Anti AFK", "antiAFK")
toggle(utilitySec, "Auto Reconnect", "autoReconnect")
button(utilitySec, "FPS Boost", function()
    Lighting.GlobalShadows = false
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Trail") then d.Enabled = false end
        if d:IsA("BasePart") then d.CastShadow = false end
    end
    uiNotify("Client-only FPS boost applied")
end)

-- SETTINGS TAB
local settingsPage = UI.pageCreate("Settings")
-- Scope appearance controls to avoid Luau 200-register limit.
do
    local visualSec = section(settingsPage.R, "Appearance  |  Make DarkyHub yours")
    label(visualSec, "Theme, glow and window scale are saved separately for each player")
    local function themeApply(name)
        local palette = appearancePresets[name]
        if not palette then return end
        local before = {}
        for k, newColor in pairs(palette) do
            before[k] = C[k]
            C[k] = newColor
        end
        -- Recolor only recognized UI theme colors, not player/game objects.
        for _, obj in ipairs(GUI:GetDescendants()) do
            if obj:IsA("GuiObject") then
                for k, prior in pairs(before) do
                    if obj.BackgroundColor3 == prior then obj.BackgroundColor3 = C[k]; break end
                end
                for k, prior in pairs(before) do
                    if obj.TextColor3 == prior then obj.TextColor3 = C[k]; break end
                end
                if obj:IsA("ScrollingFrame") then
                    for k, prior in pairs(before) do
                        if obj.ScrollBarImageColor3 == prior then obj.ScrollBarImageColor3 = C[k]; break end
                    end
                end
            elseif obj:IsA("UIStroke") then
                for k, prior in pairs(before) do
                    if obj.Color == prior then obj.Color = C[k]; break end
                end
            end
        end
        -- Match active tab highlights to the new accent.
        UI.show(UI.page)
    end
    cycle(visualSec, "Color theme", function()
        return { "Midnight", "Obsidian", "Ocean", "Emerald", "Rose" }
    end, function(name)
        if name then
            Store.settings.uiTheme = name
            themeApply(name)
            Store.saveSettings()
        end
    end, Store.settings.uiTheme)
    local preview = label(visualSec, "LIVE PREVIEW  |  DarkyHub", C.accent)
    local scaleDisplay = label(visualSec, "Window size: " .. tostring(math.floor(mainScale.Scale * 100 + 0.5)) .. "%", C.text)
    local function setScale(delta)
        local scaled = math.clamp(math.floor((mainScale.Scale + delta) * 20 + 0.5) / 20, 0.75, 1.25)
        mainScale.Scale = scaled
        Store.settings.uiScale = scaled
        scaleDisplay.Text = "Window size: " .. tostring(math.floor(scaled * 100 + 0.5)) .. "%"
        Store.saveSettings()
    end
    button(visualSec, "Smaller UI  -", function() setScale(-0.05) end)
    button(visualSec, "Larger UI  +", function() setScale(0.05) end)
    button(visualSec, "Toggle neon window border", function()
        Store.settings.uiGlow = not Store.settings.uiGlow
        mainStroke.Transparency = Store.settings.uiGlow and 0.35 or 0.9
        Store.saveSettings()
        uiNotify("Glow " .. (Store.settings.uiGlow and "enabled" or "disabled"))
    end)
    button(visualSec, "Reset appearance to default", function()
        Store.settings.uiTheme = "Midnight"
        Store.settings.uiGlow = true
        Store.settings.uiScale = 1
        mainScale.Scale = 1
        mainStroke.Transparency = 0.35
        scaleDisplay.Text = "Window size: 100%"
        themeApply("Midnight")
        Store.saveSettings()
        uiNotify("Appearance reset")
    end)
end
local settingsSec = section(settingsPage.L, "Data and configuration")
label(settingsSec, "Saves: workspace/DarkyHubV4/maps/<map name>/<macro name>.json\nEach map also saves its selected macro in map_settings.json\nRightShift toggles the hub  GUI results are auto-detected")
button(settingsSec, "Save settings + actions now", function()
    writeJSON(Store.settingsFile, Store.settings)
    Store.saveActions()
    uiNotify("Settings saved")
end)
button(settingsSec, "Clear ALL learned action slots", function()
    Store.actions.slots = {}
    Store.saveActions()
    uiNotify("Action slots cleared; join profiles remain")
end, true)
local importSec = section(settingsPage.L, "Backup / import / export")
button(importSec, "EXPORT config + all indexed map macros", function()
    Backup.exportAll()
end)
label(importSec, "Exports a JSON file and copies it to clipboard if supported. Webhook secret is omitted from exports.")
local importArea = new("TextBox", { Size = UDim2.new(1, 0, 0, 88),
    BackgroundColor3 = C.off, TextColor3 = C.text,
    Text = "", PlaceholderText = "Paste exported JSON here",
    ClearTextOnFocus = false, MultiLine = true, TextWrapped = true,
    TextSize = 11, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top }, importSec)
corner(importArea, 5)
button(importSec, "IMPORT pasted JSON (merge profiles)", function()
    Backup.importAll(importArea.Text)
    macroDD.refresh(Macro.selected)
end)
button(importSec, "IMPORT JSON from clipboard", function()
    if type(getclipboard) ~= "function" then uiNotify("Clipboard reading unavailable"); return end
    local ok, content = pcall(getclipboard)
    if ok and type(content) == "string" then
        importArea.Text = content
        Backup.importAll(content)
        macroDD.refresh(Macro.selected)
    end
end)
button(settingsPage.L, "EXPORT LIVE GUI / PLACEMENT DIAGNOSTICS", function()
    Diagnostics.export()
end)
local consoleSec = section(settingsPage.R, "Recent log")
local console = label(consoleSec, "No events yet", C.text)
button(settingsPage.L, "UNLOAD DarkyHub", function()
    env.DarkyHubUnload()
end, true)

-- ======================================================================
--  RUNTIME + REFRESH
-- ======================================================================
UI.show("Match")
local lastMap = Map.key
local lastUIRefresh = 0
local lastSpyRefresh = 0
local lastMacroSelection = nil
local lastResultMode = Store.settings.resultMode

connect(RunService.Heartbeat, function()
    local now = os.clock()
    if not Core.alive or now - lastUIRefresh < 1.5 then return end
    lastUIRefresh = now
    local waveText = Detect.wave and (tostring(Detect.wave) .. "/" .. tostring(Detect.maxWave or "?")) or "-"
    local money = getStat({ "Cash", "Money", "Gold", "Coins" })
    local phase = Detect.result and "RESULTS" or (Detect.inMatch and "MATCH" or "LOBBY/UNKNOWN")
    local placementStatus = Macro.placementDone and "FINISHED ALL STEPS / UPGRADES READY" or "LOCKED"
    if UI.page == "Match" then
    matchStatus.Text = "Map: " .. Map.name .. "\nPhase: " .. phase
        .. "    Wave: " .. waveText
        .. "\nMacro: " .. (Macro.selected or "None")
        .. "\nStep: " .. Macro.step
        .. "\nMacro pass: " .. tostring(Macro.pass or 0) .. "/" .. tostring(Store.settings.maxMacroPasses or 3)
        .. "\nPlacements: " .. Macro.dispatchedPlacements .. "/" .. Macro.expectedPlacements
        .. "   [" .. placementStatus .. "]"
        .. "\nMoney: " .. (money and fmtNumber(money) or "Unknown")
        .. (Store.settings.autoRaid and ("\nBug Milk: " .. tostring(Raid.balance() or "Unknown")
            .. " | Raid stage " .. Raid.stage .. " | Next cost " .. Store.settings.raidMilkPerNextStage) or "")
        .. "\n" .. Auto.waiting
    mapInfo.Text = "Current map: " .. Map.name .. "\nMap save ID: " .. Map.key
    infiniteState.Text = Infinite.status .. " | Sold " .. Infinite.sold .. " | Skipped " .. Infinite.skipped
        rewardsInfo.Text = "Completed runs: " .. Detect.runs
        .. "  Wins: " .. Detect.wins .. "  Losses: " .. Detect.losses
        .. "\nLast outcome: " .. (Detect.history[1] and Detect.history[1].outcome or "-")
        .. "  Wave: " .. (Detect.history[1] and tostring(Detect.history[1].wave or "?") or "-")
        .. "\nTotal tracked XP: " .. fmtNumber(Detect.totalXP)
        .. "\nLast stage rewards:\n" .. (#Detect.rewards > 0 and table.concat(Detect.rewards, "\n") or "No reward labels detected")
    end
    if UI.page == "Spy" then
    spyState.Text = (Spy.available and "Spy active" or "Spy not supported")
        .. " • " .. #Spy.events .. " recent calls"
        .. (Spy.learn and ("\nWaiting to learn: " .. Spy.learn.name) or "")
    diagnostic.Text = "Map: " .. Map.key
        .. "\nIn match: " .. tostring(Detect.inMatch)
        .. "\nResult: " .. tostring(Detect.result)
        .. "\nMacro playing: " .. tostring(Macro.playing)
        .. "\nPlacement gate: " .. placementStatus
        .. "\nAttempts: " .. Macro.attempts .. "  Skipped: " .. Macro.failures
        .. "  Unverified: " .. Macro.unverified
        .. "\nAuto wait: " .. (Auto.waiting ~= "" and Auto.waiting or "-")
    end
    if UI.page == "Settings" then console.Text = table.concat(Core.log, "\n", 1, math.min(12, #Core.log)) end
    if UI.page == "Raid" then
        local available = Raid.balance()
        local nextCost = math.max(1, math.floor(Store.settings.raidMilkPerNextStage or 1))
        local nextBalance = available and math.max(0, available - nextCost) or nil
        raidCurrent.Text = "State: " .. Raid.phase
            .. "\nCurrent Bug Milk: " .. tostring(available or "UNKNOWN")
            .. " (" .. Raid.source .. ")"
            .. "\nLast CONFIRMED count: " .. tostring(Raid.observedMilk or "UNKNOWN")
            .. "\nCost to enter NEXT STAGE: " .. nextCost
            .. "\nExpected balance AFTER next stage: " .. tostring(nextBalance or "UNKNOWN")
            .. "\nCurrent stage in this raid: " .. tostring(Raid.stage)
            .. "  | Successful advances: " .. Raid.stageAdvances
            .. "\nPending next-stage attempts: " .. Raid.pendingAttempts
            .. "\nSame map macro reused: " .. Map.key
    elseif UI.page == "Shop" then
        shopStatus.Text = Shop.status .. "\nResets detected: " .. Shop.resets
            .. "  Purchase requests: " .. Shop.boughtTotal
    elseif UI.page == "Discord" then
        webhookStatus.Text = "Session: " .. Webhook.id
            .. "\nEnabled: " .. tostring(Store.settings.webhookEnabled)
            .. "  URL: " .. (webhookValid(Store.settings.webhookUrl) and "configured" or "missing")
            .. "\nSent: " .. Webhook.sent .. "  Failed: " .. Webhook.failed
            .. "\nQueued: " .. #Webhook.queued
            .. "\n" .. Webhook.last
    end
    if UI.page == "Spy" and now - lastSpyRefresh > 0.8 then
        lastSpyRefresh = now; refreshSpy()
    end
    if Map.key ~= lastMap then
        lastMap = Map.key
        macroDD.refresh(Macro.selected)
    end
    if lastResultMode ~= Store.settings.resultMode then
        lastResultMode = Store.settings.resultMode
        resultDD.refresh(lastResultMode)
    end
    if lastMacroSelection ~= Macro.selected then
        lastMacroSelection = Macro.selected
        macroDD.refresh(Macro.selected)
    end
    refreshToggles()
end)

task.spawn(function()
    while Core.alive do
        safeCall(Auto.tick)
        task.wait(1.2)
    end
end)


end -- initializeControls
initializeControls()
View.UI, View.C, View.sidebar = UI, C, sidebar
end -- setupInterface
setupInterface()

-- UPGRADE MODULE: isolated private locals and scheduler.
do
local individualUpgradeCursor = 0
local function individualUpgradeOnce()
    local macro = Macro.selected and Macro.library()[Macro.selected]
    if not macro or not macro.steps then return false, "No placement positions available" end
    local candidates = {}
    for _, step in ipairs(macro.steps) do
        if step.kind == "place" and step.pos then table.insert(candidates, step) end
    end
    if #candidates == 0 then return false, "No valid saved positions" end
    local folder, cam = Verify.folder(), workspace.CurrentCamera
    if not folder or not cam then return false, "Need unit folder and camera" end
    for _ = 1, #candidates do
        individualUpgradeCursor = individualUpgradeCursor % #candidates + 1
        local step = candidates[individualUpgradeCursor]
        local point, onscreen = cam:WorldToViewportPoint(Vector3.new(unpack(step.pos)))
        if onscreen and point.Z > 0 and (Verify.countNear(folder, step.pos) or 0) > 0 then
            local selected = pcall(function()
                VIM:SendMouseButtonEvent(point.X, point.Y, 0, true, game, 0)
                VIM:SendMouseButtonEvent(point.X, point.Y, 0, false, game, 0)
            end)
            if selected then
                task.wait(0.18)
                local button = directGameButton({ "UPGRADE" })
                if button then
                    local buttonText = button:IsA("TextButton") and button.Text or ""
                    if clean(buttonText):find("MAX", 1, true) then
                        button = nil
                    end
                end
                if button then
                    local buttonText = button:IsA("TextButton") and button.Text or ""
                    local cost = clean(buttonText):match("UPGRADE%s*%(%s*([%d,]+)")
                    local cash = getStat({ "Cash", "Money", "Gold" })
                    if cost and cash and cash < (tonumber(cost:gsub(",", "")) or 0) then
                        return false, "Waiting for cash (need " .. cost .. ")"
                    end
                    if Actions.click(button) then
                        return true, "Requested tower #" .. individualUpgradeCursor .. " upgrade"
                    end
                end
            end
        end
    end
    return false, "No eligible visible tower upgrade"
end
-- Direct Upgrade All path from the user's standalone controller.
-- Runs independently of slower map/challenge/shop checks.
task.spawn(function()
    while Core.alive do
        task.wait(0.5)
        local s = Store.settings
        if s.autoUpgrade and Macro.placementDone and Detect.inMatch and not Detect.result
            and not (Infinite and Infinite.active)
            and allowed("upgrade_direct", math.max(0.5, s.upgradeInterval)) then
            local ok, upgradeReason = performUpgradeAll()
            if not ok and Store.actions.slots.upgradeAll then
                ok = Codec.call(Store.actions.slots.upgradeAll)
            end
            if not ok and s.individualUpgradeFallback then
                local upgraded, why = individualUpgradeOnce()
                ok = upgraded
                if not ok then Auto.waiting = "Upgrade fallback: " .. tostring(why) end
            end
            if not ok and Auto.waiting == "" then
                Auto.waiting = "Upgrade: " .. tostring(upgradeReason)
            end
        end
    end
end)

end -- UPGRADE MODULE

-- Reconnect only after a recognized Roblox error prompt; no kick bypass.
-- Isolate overlay locals inside a callback. The main Luau chunk was
-- exceeding the 200-register limit when allocating okOverlay/overlay.
-- This scope keeps those temporary registers out of the large main chunk.
pcall(function()
    local overlay = game:GetService("CoreGui").RobloxPromptGui.promptOverlay
    if not overlay then return end
    connect(overlay.ChildAdded, function(child)
        if child.Name == "ErrorPrompt" and Store.settings.webhookDisconnect then
            Webhook.queue("Roblox connection error", "Client displayed an ErrorPrompt; final send is best effort")
        end
        if child.Name == "ErrorPrompt" and Store.settings.autoReconnect then
            task.delay(3, function()
                if Core.alive then pcall(function()
                    TeleportService:Teleport(game.PlaceId, player)
                end) end
            end)
        end
    end)
end)

pcall(function()
    connect(TeleportService.TeleportInitFailed, function(_, result, message)
        if Core.alive and Store.settings.webhookDisconnect then
            Webhook.queue("Teleport failed", tostring(message or result))
        end
    end)
end)

-- COMPACT NAVIGATION: hide advanced tabs until explicitly requested.
do
    local advanced = { Home = true, Shop = true, Discord = true,
        Spy = true, Player = true, Settings = true }
    local expanded = false
    local more = new("TextButton", {
        Size = UDim2.new(1, -3, 0, 37), BackgroundColor3 = View.C.off,
        Text = "  +  MORE TOOLS", TextColor3 = View.C.text,
        Font = Enum.Font.GothamBold, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, View.sidebar)
    corner(more, 7)
    local function refresh()
        more.Text = expanded and "  −  FEWER TOOLS" or "  +  MORE TOOLS"
        for name, tab in pairs(View.UI.tabButtons) do
            if advanced[name] then tab.Visible = expanded end
        end
    end
    connect(more.Activated, function() expanded = not expanded; refresh() end)
    -- If an advanced page was last selected, move to the normal Match landing page.
    if advanced[View.UI.page] then View.UI.show("Match") end
    refresh()
end

env.DarkyHubUnload = function()
    if not Core.alive then return end
    Core.alive = false
    Macro.stopPlay()
    Macro.recording = nil
    Spy.learn = nil
    if env.DarkyHubRemoteRouter then env.DarkyHubRemoteRouter.handler = nil end
    Player.stopFly()
    Markers.clear()
    if Player.oldSpeed and humanoid() then humanoid().WalkSpeed = Player.oldSpeed end
    writeJSON(Store.settingsFile, Store.settings)
    Store.saveActions()
    for _, c in ipairs(Core.connections) do pcall(function() c:Disconnect() end) end
    if GUI then GUI:Destroy() end
    if Core.placementHudGui then Core.placementHudGui:Destroy(); Core.placementHudGui = nil end
    if env.DarkyHubUnload then env.DarkyHubUnload = nil end
    -- Installed __namecall hooks stay in the executor chain, but become inert.
end

uiNotify(Spy.available and "DarkyHub v5.9 ready • Remote Spy active"
    or "DarkyHub v5.9 ready • remote hook unavailable, GUI automations still work")
if not Store.hasFS then uiNotify("File APIs unavailable: macros will only exist in memory") end
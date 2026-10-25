-- DarkyHub Stage Reader 2.1 - passive sibling inspection and backup
local players=game:GetService("Players")
local plr=players.LocalPlayer
local gui=plr:WaitForChild("PlayerGui")
local hs=game:GetService("HttpService")
local env=type(getgenv)=="function" and getgenv() or _G
if type(env.DarkyStageReader)=="table" and type(env.DarkyStageReader.stop)=="function" then pcall(env.DarkyStageReader.stop) end
local reader={version="2.1",active=true,entries={},history={},lastSave=0}
env.DarkyStageReader=reader
env.DarkyStageCatalog=reader
local root="DarkyHubStageReader"
local url="https://raw.githubusercontent.com/DarkBoy-js/DarkBoy-js/main/darkyhub-test/reader.lua"
local function path(o) local t={} for i=1,16 do if not o or o==game then break end table.insert(t,1,o.Name);o=o.Parent end return table.concat(t,"/") end
local function text(o) if o:IsA("TextLabel") or o:IsA("TextButton") then return tostring(o.Text):sub(1,120) end return "" end
local function writable() return type(writefile)=="function" and type(readfile)=="function" end
local function mkdir() if type(makefolder)=="function" and type(isfolder)=="function" and not isfolder(root) then pcall(makefolder,root) end end
local function snapshot() return {version=reader.version,updated=os.time(),entries=reader.entries,history=reader.history} end
local function store(name)
 if not writable() then return false end
 mkdir()
 local ok,json=pcall(function() return hs:JSONEncode(snapshot()) end)
 if not ok then return false end
 local good=pcall(writefile,root.."/"..name,json)
 if good then reader.lastSave=os.time() end
 return good
end
mkdir()
if writable() then
 local ok,raw=pcall(readfile,root.."/latest.json")
 if ok then local good,data=pcall(function()return hs:JSONDecode(raw)end)
  if good and type(data)=="table" then
   reader.entries=type(data.entries)=="table" and data.entries or {}
   reader.history=type(data.history)=="table" and data.history or {}
  end
 end
end
local function changed(event,data)
 if #reader.history>1200 then table.remove(reader.history,1) end
 table.insert(reader.history,{event=event,data=data,placeId=game.PlaceId,at=os.time()})
end
local function attributes(o)
 local out={}
 for key,val in pairs(o:GetAttributes()) do
  if (type(val)=="string" or type(val)=="number" or type(val)=="boolean")
   and not tostring(key):lower():find("token") and not tostring(key):lower():find("secret") then
   out[key]=type(val)=="string" and val:sub(1,120) or val
  end
 end
 return out
end
local function relevant(o)
 local name=o.Name:lower()
 return name:match("^stage%d+$") or name:match("^car%d+$")
  or name:match("^act%d+$") or name:find("raid",1,true)
  or name:find("infinite",1,true) or name:find("challenge",1,true)
end
local function inspect(o)
 if not o or not o.Parent or not relevant(o) then return end
 local info={key=tostring(game.PlaceId).."|"..path(o),placeId=game.PlaceId,
  path=path(o),name=o.Name,parent=path(o.Parent),class=o.ClassName,
  attributes=attributes(o),buttons={},labels={},children={},at=os.time()}
 for _,child in ipairs(o:GetChildren()) do
  if #info.children<100 then table.insert(info.children,{name=child.Name,class=child.ClassName}) end
 end
 local n=0
 for _,child in ipairs(o:GetDescendants()) do
  n+=1;if n>450 then info.truncated=true;break end
  if child:IsA("GuiButton") and #info.buttons<80 then
   table.insert(info.buttons,{path=path(child),name=child.Name,label=text(child),attributes=attributes(child)})
  elseif child:IsA("TextLabel") and #info.labels<80 and text(child)~="" then
   table.insert(info.labels,{path=path(child),text=text(child)})
  end
 end
 local fingerprint=hs:JSONEncode({info.attributes,info.buttons,info.labels,info.children})
 for i,prior in ipairs(reader.entries) do
  if prior.key==info.key then
   if prior.fingerprint~=fingerprint then
    info.fingerprint=fingerprint
    reader.entries[i]=info
    changed("stage_updated",{path=info.path,name=info.name})
   end
   return
  end
 end
 if #reader.entries<3000 then
  info.fingerprint=fingerprint
  table.insert(reader.entries,info)
  changed("stage_discovered",{path=info.path,name=info.name})
 end
end
function reader.scan()
 if not reader.active then return end
 for _,o in ipairs(gui:GetDescendants()) do if relevant(o) then pcall(inspect,o) end end
 for _,container in ipairs({game:GetService("ReplicatedStorage"),workspace}) do
  for _,o in ipairs(container:GetDescendants()) do
   if relevant(o) then pcall(inspect,o) end
  end
 end
end
function reader.save() return store("latest.json") end
function reader.backup(label)
 reader.save()
 local name="backup_"..tostring(label or "manual"):gsub("[^%w_]","_").."_"..os.time().."_"..math.random(10000,99999)..".json"
 return store(name),name
end
reader.export=reader.backup
function reader.printAll()
 print("DarkyHub stage reader",reader.version,"items",#reader.entries)
 for i,e in ipairs(reader.entries) do print(i,e.name,e.path,"buttons",#(e.buttons or {})) end
end
function reader.healthcheck() print("Stage reader",reader.version,"active",reader.active,"items",#reader.entries,"lastSave",reader.lastSave,"file APIs",writable()) end
local connections={}
table.insert(connections,gui.DescendantAdded:Connect(function(o) if reader.active then task.defer(function()pcall(inspect,o)end) end end))
table.insert(connections,plr.OnTeleport:Connect(function(state,destination)
 changed("teleport",{state=tostring(state),destination=destination})
 reader.backup("teleport")
end))
local queue=queue_on_teleport or (type(syn)=="table" and syn.queue_on_teleport)
if type(queue)=="function" then
 reader.teleportQueued=pcall(queue,'local u="'..url..'";local ok,s=pcall(function()return game:HttpGet(u)end);if ok then local fn=loadstring(s);if fn then fn()end end')
end
function reader.stop() reader.active=false;for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end;reader.backup("stop") end
reader.scan();reader.save()
task.spawn(function()
 local n=0
 while reader.active do
  task.wait(5);pcall(reader.scan);pcall(reader.save)
  n+=1;if n%6==0 then pcall(reader.backup,"periodic") end
 end
end)
print("[DarkyHub Stage Reader] loaded |",#reader.entries,"entries | teleport",reader.teleportQueued)

-- DarkyHub TEST Journey Reader v1.0 - passive GUI + destination reconnaissance
local Players=game:GetService("Players")
local TeleportService=game:GetService("TeleportService")
local HS=game:GetService("HttpService")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")
local env=type(getgenv)=="function" and getgenv() or _G
if env.DarkyJourneyReader and env.DarkyJourneyReader.stop then pcall(env.DarkyJourneyReader.stop) end
local J={version="1.0",active=true,events={},states={},connections={},session=tostring(os.time()).."-"..math.random(1000,9999),lastSignature="",lastSave=0}
env.DarkyJourneyReader=J
local ROOT="DarkyHubJourney"
local URL="https://raw.githubusercontent.com/DarkBoy-js/DarkBoy-js/main/darkyhub-test/test-loader.lua"
local function dir()
 if type(makefolder)=="function" and type(isfolder)=="function" then
  local ok,yes=pcall(isfolder,ROOT);if ok and not yes then pcall(makefolder,ROOT) end
 end
end
local function limitText(s) return tostring(s or ""):gsub("%s+"," "):sub(1,180) end
local function path(o)
 local t={};while o and o~=game and #t<20 do table.insert(t,1,o.Name);o=o.Parent end
 return table.concat(t,"/")
end
local function snap()
 local data={placeId=game.PlaceId,jobId=game.JobId,at=os.time(),labels={},buttons={},menus={},remotes={},prompts={}}
 local gui=pg:FindFirstChild("HubWindows")
 if gui then
  for _,obj in ipairs(gui:GetDescendants()) do
   if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and #data.labels<160 then
    local s=limitText(obj.Text)
    if s~="" and (s:upper():find("ACT",1,true) or s:upper():find("STAGE",1,true) or s:upper():find("WAVE",1,true) or s:upper():find("HOST",1,true) or s:upper():find("LOBBY",1,true) or s:upper():find("CHALLENGE",1,true) or s:upper():find("CRYSTAL",1,true) or s:upper():find("PLAY",1,true)) then
     table.insert(data.labels,{path=path(obj),text=s,visible=obj.Visible})
    end
   end
   if obj:IsA("GuiButton") and #data.buttons<100 and
    (obj.Name:upper():find("START",1,true) or obj.Name:upper():find("PLAY",1,true) or obj.Name:upper():find("LEAVE",1,true) or obj.Name:upper():find("STAGE",1,true)) then
    table.insert(data.buttons,{path=path(obj),class=obj.ClassName,visible=obj.Visible,text=obj:IsA("TextButton") and limitText(obj.Text) or "",attributes=obj:GetAttributes()})
   end
  end
  for _,name in ipairs({"Stages","Challenges","Raid"}) do
   local w=gui:FindFirstChild(name)
   if w then
    table.insert(data.menus,{name=name,path=path(w),enabled=w:IsA("ScreenGui") and w.Enabled or nil})
    local pop=w:FindFirstChild("Pop");if pop and pop:IsA("GuiObject") then data.menus[#data.menus].popVisible=pop.Visible end
   end
  end
 end
 local rs=game:GetService("ReplicatedStorage")
 for _,o in ipairs(rs:GetDescendants()) do
  if #data.remotes>=90 then break end
  if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
   local p=path(o)
   if p:lower():find("match",1,true) or p:lower():find("lobby",1,true) or p:lower():find("stage",1,true) or p:lower():find("teleport",1,true) or p:lower():find("raid",1,true) or p:lower():find("place",1,true) then
    table.insert(data.remotes,{path=p,class=o.ClassName})
   end
  end
 end
 for _,o in ipairs(workspace:GetDescendants()) do
  if #data.prompts>=40 then break end
  if o:IsA("ProximityPrompt") then
   table.insert(data.prompts,{path=path(o),action=o.ActionText,object=o.ObjectText})
  end
 end
 return data
end
local function record(event,details)
 if not J.active then return end
 table.insert(J.events,{at=os.time(),placeId=game.PlaceId,jobId=game.JobId,event=event,data=details})
 if #J.events>1200 then table.remove(J.events,1)end
 print("[JourneyReader]",event)
end
local function persist(tag)
 if type(writefile)~="function" then return false,"No file API" end
 dir()
 local output={version=J.version,session=J.session,placeId=game.PlaceId,updated=os.time(),events=J.events,states=J.states}
 local ok,encoded=pcall(HS.JSONEncode,HS,output)
 if not ok then return false,tostring(encoded)end
 local name=ROOT.."/"..(tag or "latest")..".json"
 local good,msg=pcall(writefile,name,encoded)
 if good then J.lastSave=os.time()end
 return good,good and name or tostring(msg)
end
function J.export()
 local name="snapshot_"..os.time().."_"..math.random(10000,99999)
 return persist(name)
end
function J.scan(label)
 local state=snap()
 state.reason=label or "manual"
 table.insert(J.states,state)
 if #J.states>35 then table.remove(J.states,1)end
 record("snapshot",{reason=state.reason,menus=state.menus,placeId=game.PlaceId})
 persist("latest")
 return state
end
local previous
if type(readfile)=="function" then
 local ok,raw=pcall(readfile,ROOT.."/latest.json")
 if ok then
  local yes,data=pcall(HS.JSONDecode,HS,raw)
  if yes and type(data)=="table" then
   J.events=type(data.events)=="table" and data.events or {}
   J.states=type(data.states)=="table" and data.states or {}
  end
 end
end
J.scan("loaded")
local function bind(signal,fn)
 local ok,c=pcall(function()return signal:Connect(fn)end)
 if ok then table.insert(J.connections,c)end
end
bind(plr.OnTeleport,function(state,destination)
 record("teleport",{status=tostring(state),destination=destination})
 J.scan("teleport")
 J.export()
end)
bind(TeleportService.TeleportInitFailed,function(_,result,message)
 record("teleport_failed",{result=tostring(result),message=tostring(message)})
 J.export()
end)
local function watchButton(o)
 if not o:IsA("GuiButton") or o:IsDescendantOf(pg:FindFirstChild("DarkyHubStageTest") or Instance.new("Folder")) then return end
 local n=o.Name:upper()
 if not (n:find("START",1,true) or n:find("PLAY",1,true) or n:find("LEAVE",1,true)) then return end
 bind(o.Activated,function()
  record("game_button_activated",{path=path(o),name=o.Name,text=o:IsA("TextButton") and limitText(o.Text) or ""})
  task.delay(.3,function()if J.active then J.scan("after_button")end end)
  task.delay(1.2,function()if J.active then J.scan("after_button_delayed")end end)
 end)
end
for _,o in ipairs(pg:GetDescendants()) do watchButton(o)end
bind(pg.DescendantAdded,function(o)watchButton(o)end)
task.spawn(function()
 local n=0
 while J.active do
  task.wait(5)
  local st=snap()
  local sig=HS:JSONEncode({st.menus,st.buttons})
  if sig~=J.lastSignature then
   J.lastSignature=sig
   J.scan("menu_change")
  end
  n+=1
  if n%6==0 then J.export() else persist("latest")end
 end
end)
local queue=queue_on_teleport or (type(syn)=="table" and syn.queue_on_teleport)
if type(queue)=="function" then
 J.queued=pcall(queue,'local ok,code=pcall(function()return game:HttpGet("'..URL..'")end);if ok then local fn=loadstring(code);if fn then fn()end end')
end
function J.print()
 print("[JourneyReader] place",game.PlaceId,"events",#J.events,"snapshots",#J.states,"queue",J.queued)
 for _,event in ipairs(J.events) do print(event.event,HS:JSONEncode(event.data or {}))end
end
function J.stop()
 J.active=false
 for _,c in ipairs(J.connections) do pcall(function()c:Disconnect()end)end
 J.export()
end
print("[JourneyReader] Active. Commands: getgenv().DarkyJourneyReader.scan() / .export() / .print()")

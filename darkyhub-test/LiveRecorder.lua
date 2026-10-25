-- DarkyHub TEST Live Recorder v2.1
-- Passive client-visible interactions; never fires game remotes.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TS=game:GetService("TeleportService")
local HS=game:GetService("HttpService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local env=type(getgenv)=="function" and getgenv() or _G
if env.DarkyLiveRecorder and env.DarkyLiveRecorder.stop then pcall(env.DarkyLiveRecorder.stop) end
local R={version="2.1",active=true,events={},sequence=0,connections={},seen=setmetatable({}, {__mode="k"}),lastState="",session=tostring(os.time()).."-"..math.random(1000,9999),autosaves=0,lastGuiAction=nil,hookStatus={}}
env.DarkyLiveRecorder=R
local ROOT="DarkyHubLiveRecorder"
local URL="https://raw.githubusercontent.com/DarkBoy-js/DarkBoy-js/main/darkyhub-test/test-loader.lua"
local function folder()
 if type(isfolder)=="function" and type(makefolder)=="function" then
  local ok,has=pcall(isfolder,ROOT)
  if ok and not has then pcall(makefolder,ROOT)end
 end
end
folder()
local function name(s) return tostring(s or ""):gsub("[%c]"," "):sub(1,140)end
local function path(o)
 if typeof(o)~="Instance" then return tostring(o)end
 local a={}
 while o and o~=game and #a<18 do table.insert(a,1,o.Name);o=o.Parent end
 return table.concat(a,"/")
end
local private={"password","token","webhook","secret","cookie","authorization","chat","message","textinput","email","phone","sessionkey","payment"}
local function sensitive(s)
 s=tostring(s or ""):lower()
 for _,word in ipairs(private) do if s:find(word,1,true) then return true end end
 return false
end
local function encode(v,depth,key)
 if sensitive(key) then return "[REDACTED]"end
 depth=depth or 0
 if depth>3 then return "[DEPTH LIMIT]"end
 local ty=typeof(v)
 if ty=="string" then
  if #v>180 or v:find("https?://") then return "[REDACTED]"end
  return name(v)
 end
 if ty=="number" or ty=="boolean" then return v end
 if ty=="Instance" then return {type=v.ClassName,path=path(v)}end
 if ty=="Vector3" then return {type=ty,x=v.X,y=v.Y,z=v.Z}end
 if ty=="CFrame" then return {type=ty,components={v:GetComponents()}}end
 if ty=="Vector2" then return {type=ty,x=v.X,y=v.Y}end
 if ty=="EnumItem" then return tostring(v)end
 if ty=="table" then
  local out={};local n=0
  for k,item in pairs(v)do
   n+=1;if n>30 then out._truncated=true;break end
   local sk=tostring(k)
   if not sensitive(sk) then out[sk]=encode(item,depth+1,sk)end
  end
  return out
 end
 return ty
end
local function write(filename,data)
 if type(writefile)~="function" then return false end
 folder()
 local ok,raw=pcall(function()return HS:JSONEncode(data)end)
 if not ok then return false end
 return pcall(writefile,ROOT.."/"..filename,raw)
end
local function state()
 return {session=R.session,placeId=game.PlaceId,jobId=game.JobId,sequence=R.sequence,
  lastUpdated=os.time(),events=R.events}
end
local function snapshot(label)
 local file="snapshot_"..tostring(label or "manual"):gsub("[^%w_-]","_").."_"..os.time().."_"..math.random(10000,99999)..".json"
 return write(file,state()),file
end
function R.export()return snapshot("export")end
local function checkpoint(critical)
 if type(writefile)~="function" then return end
 write("latest.json",state())
 if critical or R.sequence%40==0 then
  snapshot(critical and "critical" or "periodic")
 end
end
local recent={}
local function record(kind,action,data,critical)
 if not R.active then return end
 local fingerprint=kind.."|"..action
 local t=os.clock()
 if recent[fingerprint] and t-recent[fingerprint]<0.12 then return end
 recent[fingerprint]=t
 R.sequence+=1
 local event={id=R.sequence,unix=os.time(),placeId=game.PlaceId,jobId=game.JobId,kind=kind,
  action=action,data=data}
 table.insert(R.events,event)
 if #R.events>1800 then table.remove(R.events,1)end
 -- Immediately write a separate JSONL event, before a teleport can discard this Lua state.
 if type(appendfile)=="function" then
  folder()
  local ok,raw=pcall(function()return HS:JSONEncode(event)end)
  if ok then pcall(appendfile,ROOT.."/events_"..R.session..".jsonl",raw.."\n")end
 end
 if critical then checkpoint(true)
 elseif R.sequence%4==0 then checkpoint(false) end
 print("[LiveRecorder]",R.sequence,kind,action)
end
local function connect(signal,callback)
 local ok,c=pcall(function()return signal:Connect(callback)end)
 if ok then table.insert(R.connections,c)end
end
local function visible(o)
 while o and o~=pg do
  if o:IsA("GuiObject") and not o.Visible then return false end
  o=o.Parent
 end
 return true
end
local function watch(o)
 if R.seen[o] then return end
 if not o:IsA("GuiButton") or sensitive(path(o)) then return end
 if path(o):find("DarkyHub",1,true) then return end
 R.seen[o]=true
 connect(o.Activated,function()
  if not visible(o) then return end
  local text=o:IsA("TextButton") and name(o.Text) or ""
  local action=path(o)
  R.lastGuiAction={path=action,text=text,at=os.clock()}
  record("gui","Activated:"..action,{name=o.Name,text=text,class=o.ClassName},true)
  task.defer(function()
   if R.active then
    local parent=o.Parent
    record("state","AfterGUI:"..o.Name,{parent=parent and path(parent),placeId=game.PlaceId},false)
   end
  end)
 end)
end
for _,o in ipairs(pg:GetDescendants())do watch(o)end
connect(pg.DescendantAdded,function(o)watch(o)end)
connect(game:GetService("ProximityPromptService").PromptTriggered,function(prompt,who)
 if who and who~=player then return end
 record("prompt","Triggered:"..path(prompt),{object=name(prompt.ObjectText),action=name(prompt.ActionText)},true)
end)
connect(player.OnTeleport,function(status,place)
 record("teleport",tostring(status),{destinationPlaceId=place},true)
 snapshot("before_teleport")
end)
connect(TS.TeleportInitFailed,function(_,result,message)
 record("teleport","failed",{result=tostring(result),message=name(message)},true)
end)
-- One persistent dispatcher for BOTH namecall and direct method interception.
-- Duplicate callbacks are suppressed when both hooks observe the same call.
local router=env.DarkyLiveRecorderRouter
if not router then router={current=R,recent={}};env.DarkyLiveRecorderRouter=router end
router.current=R
local function observe(self,method,args,via)
 local target=router.current
 if not target or not target.active or typeof(self)~="Instance" then return end
 local valid=(method=="FireServer" and self:IsA("RemoteEvent")) or (method=="InvokeServer" and self:IsA("RemoteFunction"))
 if not valid then return end
 local p=path(self)
 if sensitive(p) then return end
 local clock=os.clock()
 local signature=method..":"..p
 if router.recent[signature] and clock-router.recent[signature]<0.045 then return end
 router.recent[signature]=clock
 local out={}
 for i=1,math.min(args.n,20)do
  local ok,v=pcall(encode,args[i],0,tostring(i))
  out[i]=ok and v or "[SERIALIZATION ERROR]"
 end
 local gui=target.lastGuiAction
 local context=gui and clock-gui.at<8 and {path=gui.path,text=gui.text,secondsAfter=math.floor((clock-gui.at)*100)/100} or nil
 record("remote",method..":"..p,{argc=args.n,args=out,interception=via,precedingGui=context},true)
end
router.observe=observe
if not router.namecallInstalled and type(hookmetamethod)=="function" and type(getnamecallmethod)=="function" then
 local original
 local function intercept(self,...)
  local method=getnamecallmethod()
  if method=="FireServer" or method=="InvokeServer" then
   local args=table.pack(...)
   pcall(router.observe,self,method,args,"namecall")
  end
  return original(self,...)
 end
 local ok,err=pcall(function()
  original=hookmetamethod(game,"__namecall",type(newcclosure)=="function" and newcclosure(intercept) or intercept)
 end)
 router.namecallInstalled=ok
 if not ok then warn("[LiveRecorder] namecall hook failed",err)end
end
if (not router.directEvent or not router.directFunction) and type(hookfunction)=="function" then
 local remoteEvent=Instance.new("RemoteEvent")
 local remoteFunction=Instance.new("RemoteFunction")
 local oldEvent,oldFunction
 local function eventHook(self,...)
  pcall(router.observe,self,"FireServer",table.pack(...),"direct")
  return oldEvent(self,...)
 end
 local function functionHook(self,...)
  pcall(router.observe,self,"InvokeServer",table.pack(...),"direct")
  return oldFunction(self,...)
 end
 local ok1,err1=true,nil
 if not router.directEvent then ok1,err1=pcall(function()
  oldEvent=hookfunction(remoteEvent.FireServer,type(newcclosure)=="function" and newcclosure(eventHook) or eventHook)
 end) end
 local ok2,err2=true,nil
 if not router.directFunction then ok2,err2=pcall(function()
  oldFunction=hookfunction(remoteFunction.InvokeServer,type(newcclosure)=="function" and newcclosure(functionHook) or functionHook)
 end) end
 router.directInstalled=ok1 and ok2
 router.directEvent=ok1;router.directFunction=ok2
 if not ok1 then warn("[LiveRecorder] FireServer hook unavailable",err1)end
 if not ok2 then warn("[LiveRecorder] InvokeServer hook unavailable",err2)end
 remoteEvent:Destroy();remoteFunction:Destroy()
end
R.hookStatus={namecall=router.namecallInstalled==true,directFireServer=router.directEvent==true,directInvokeServer=router.directFunction==true}
function R.healthcheck()
 print("[LiveRecorder] v"..R.version,"hooks",HS:JSONEncode(R.hookStatus),"events",#R.events,"place",game.PlaceId)
 return R.hookStatus
end
-- Read useful changes only; ignore continuously changing countdown labels.
local function poll()
 local labels={}
 for _,o in ipairs(pg:GetDescendants())do
  if o:IsA("TextLabel") and visible(o) and not sensitive(path(o)) then
   local s=name(o.Text)
   local u=s:upper()
   if #s>2 and #s<90 and
    (u:find("CHALLENGE",1,true) or u:find("ACT ",1,true) or
     u:find("WAVE ",1,true) or u:find("LOBBY",1,true) or
     u:find("HOST",1,true) or u:find("VICTORY",1,true) or
     u:find("DEFEAT",1,true) or u:find("REWARD",1,true) or
     u:find("START",1,true)) and not s:match("%d%d:%d%d") then
    if #labels<70 then table.insert(labels,{path=path(o),text=s})end
   end
  end
 end
 table.sort(labels,function(a,b)return a.path<b.path end)
 local encoded=HS:JSONEncode(labels)
 if encoded~=R.lastState then
  R.lastState=encoded
  record("state","UIChange",{labels=labels},false)
 end
end
local resume
if type(readfile)=="function" then
 local ok,data=pcall(readfile,ROOT.."/latest.json")
 if ok then
  local yes,old=pcall(function()return HS:JSONDecode(data)end)
  if yes and type(old)=="table" and type(old.events)=="table" then
   R.events=old.events
   R.sequence=tonumber(old.sequence) or #old.events
   R.session=old.session or R.session
   resume=true
  end
 end
end
local queue=queue_on_teleport or (type(syn)=="table" and syn.queue_on_teleport)
if type(queue)=="function" then
 R.teleportQueued=pcall(queue,'local ok,s=pcall(function()return game:HttpGet("'..URL..'")end);if ok then local fn=loadstring(s);if fn then fn()end end')
end
function R.stop()
 if not R.active then return end
 record("system","Stopped",{},true)
 R.active=false
 for _,c in ipairs(R.connections)do pcall(function()c:Disconnect()end)end
 snapshot("stop")
end
function R.printAll()
 for _,e in ipairs(R.events)do print(e.id,e.kind,e.action,HS:JSONEncode(e.data or {}))end
end
record("system",resume and "Resumed" or "Started",{placeId=game.PlaceId,teleportQueued=R.teleportQueued,hooks=R.hookStatus},true)
task.spawn(function()
 while R.active do
  task.wait(2)
  pcall(poll)
  checkpoint(false)
 end
end)
print("[LiveRecorder] ACTIVE | live JSONL:",ROOT.."/events_"..R.session..".jsonl"," | exports:",ROOT)

-- DarkyHub TEST Remote Laboratory v1.0 (test repository only)
-- Passive recording of client-originated RemoteEvent/RemoteFunction calls
-- Record by manually clicking Play or placing a unit in game
local P=game:GetService("Players").LocalPlayer
local HS=game:GetService("HttpService")
local env=type(getgenv)=="function" and getgenv() or _G
if env.DarkyRemoteLab and env.DarkyRemoteLab.stop then pcall(env.DarkyRemoteLab.stop) end
local R={version="1.1",active=true,mode="off",calls={},last={},reports={},session=os.time()}
env.DarkyRemoteLab=R
local root="DarkyHubRemoteLab"
local function path(o)
 local parts={}
 while o and o~=game and #parts<18 do table.insert(parts,1,o.Name);o=o.Parent end
 return table.concat(parts,"/")
end
local function describe(v,depth)
 depth=depth or 0
 if depth>4 then return "[depth limit]" end
 local kind=typeof(v)
 if kind=="Instance" then return {type=kind,path=path(v),class=v.ClassName} end
 if kind=="Vector3" then return {type=kind,x=v.X,y=v.Y,z=v.Z} end
 if kind=="CFrame" then return {type=kind,components={v:GetComponents()}} end
 if kind=="Vector2" then return {type=kind,x=v.X,y=v.Y} end
 if kind=="Color3" then return {type=kind,r=v.R,g=v.G,b=v.B} end
 if kind=="EnumItem" then return {type=kind,name=tostring(v)} end
 if kind=="table" then
  local out={};local total=0
  for k,x in pairs(v) do
   total+=1;if total>45 then out._truncated=true;break end
   if type(k)=="string" then
    local lower=k:lower()
    if not lower:find("password",1,true) and not lower:find("token",1,true)
      and not lower:find("webhook",1,true) and not lower:find("secret",1,true)
      and not lower:find("cookie",1,true) and not lower:find("auth",1,true) then
       out[k]=describe(x,depth+1)
    end
   elseif type(k)=="number" then out[tostring(k)]=describe(x,depth+1) end
  end
  return out
 end
 if kind=="string" then return v:sub(1,220) end
 if kind=="number" or kind=="boolean" then return v end
 return tostring(kind)
end
local function ensureDir()
 if type(makefolder)=="function" and type(isfolder)=="function" then
  local ok,exists=pcall(isfolder,root)
  if ok and not exists then pcall(makefolder,root) end
 end
end
function R.export(label)
 if type(writefile)~="function" then return false,"writefile unavailable" end
 ensureDir()
 local filename=root.."/"..tostring(label or "snapshot"):gsub("[^%w_-]","_").."_"..os.time().."_"..math.random(10000,99999)..".json"
 local ok,err=pcall(function()
  writefile(filename,HS:JSONEncode({version=R.version,placeId=game.PlaceId,session=R.session,mode=R.mode,reports=R.reports}))
 end)
 return ok,ok and filename or tostring(err)
end
function R.arm(mode)
 if mode~="join" and mode~="place" then return false,"Mode must be join or place" end
 R.mode=mode;R.calls={};R.armedAt=os.clock()
 print("[RemoteLab] ARMED",mode,"Perform the action ONCE in game's original UI")
 return true
end
function R.stopCapture()
 R.mode="off"
 local result={}
 for _,c in ipairs(R.calls) do
  result[#result+1]={path=c.path,method=c.method,args=c.serialized,at=c.time,mode=c.mode,caller=c.caller}
 end
 table.insert(R.reports,{at=os.time(),placeId=game.PlaceId,mode="capture",calls=result})
 local ok,file=R.export("capture")
 print("[RemoteLab] CAPTURED",#R.calls,"calls. JSON:",ok and file or "failed")
 for i,c in ipairs(R.calls) do print("[RemoteLab]",i,c.method,c.path,HS:JSONEncode(c.serialized)) end
 return result
end
function R.replay(index)
 if R.mode~="off" then return false,"Stop recording before replay" end
 local item=R.calls[tonumber(index) or 1]
 if not item then return false,"No captured call in this session" end
 if not item.remote or not item.remote.Parent then return false,"Remote no longer exists" end
 R.replaying=true
 local ok,err=pcall(function()
  if item.method=="FireServer" then item.remote:FireServer(table.unpack(item.arguments,1,item.arguments.n))
  elseif item.method=="InvokeServer" then item.remote:InvokeServer(table.unpack(item.arguments,1,item.arguments.n))
  end
 end)
 R.replaying=false
 print("[RemoteLab] Replay",ok and "REQUEST SENT" or tostring(err))
 return ok,ok and "Request sent; game acceptance not verified" or tostring(err)
end
function R.printAll()
 for i,c in ipairs(R.calls) do print(i,c.method,c.path,HS:JSONEncode(c.serialized)) end
end
function R.stop() R.active=false;R.mode="off";pcall(R.export,"stop") end
-- Router survives re-execution so hooks never chain indefinitely.
local router=env.DarkyRemoteLabHook
if not router then
 if type(hookmetamethod)=="function" and type(getnamecallmethod)=="function" then
  router={receiver=R}
  local previous
  local function interception(self,...)
   local method=getnamecallmethod()
   local receiver=router.receiver
   if receiver and receiver.active and receiver.mode~="off" and not receiver.replaying
     and typeof(self)=="Instance"
     and ((method=="FireServer" and self:IsA("RemoteEvent")) or
          (method=="InvokeServer" and self:IsA("RemoteFunction"))) then
    local ourCall=false
    if type(checkcaller)=="function" then
     local ok,yes=pcall(checkcaller);ourCall=ok and yes or false
    end
    if true then
     local args=table.pack(...)
     local serial={}
     for i=1,math.min(args.n,18) do serial[i]=describe(args[i]) end
     local item={remote=self,method=method,path=path(self),arguments=args,serialized=serial,time=os.clock(),mode=receiver.mode,caller=ourCall}
     table.insert(receiver.calls,item)
     if #receiver.calls>40 then table.remove(receiver.calls,1) end
     print("[RemoteLab]",receiver.mode,method,item.path,"args",args.n)
    end
   end
   return previous(self,...)
  end
  local ok,err=pcall(function()
   previous=hookmetamethod(game,"__namecall",
    type(newcclosure)=="function" and newcclosure(interception) or interception)
  end)
  if ok then env.DarkyRemoteLabHook=router else warn("[RemoteLab] Hook failed:",err) end
 else warn("[RemoteLab] No namecall hook available; cannot observe original outbound remote calls") end
end
router=env.DarkyRemoteLabHook
if router then router.receiver=R end
print("[RemoteLab] Ready. Arm: getgenv().DarkyRemoteLab.arm('join') or .arm('place')")
print("[RemoteLab] Then perform action manually, .stopCapture(), .printAll(), or .export()")

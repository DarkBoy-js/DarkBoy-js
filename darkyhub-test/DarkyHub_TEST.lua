-- DarkyHub TEST ONLY | stage catalog navigation prototype
-- Loads the current public DarkyHub; private main repo is not modified.
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local HttpService=game:GetService("HttpService")
local rootUrl="https://raw.githubusercontent.com/DarkBoy-js/DarkBoy-js/main/darkyhub-test/"
local okay,src=pcall(function()return game:HttpGet(rootUrl.."DarkyHub.lua")end)
if not okay then error("Cannot load DarkyHub: "..tostring(src))end
local run,why=loadstring(src)
if not run then error("DarkyHub compile failed: "..tostring(why))end
local ok,err=pcall(run)
if not ok then warn("Core DarkyHub error: "..tostring(err))end

local env=type(getgenv)=="function" and getgenv() or _G
if env.DarkyStageTest and env.DarkyStageTest.cleanup then env.DarkyStageTest.cleanup() end
local T={selected=nil,mode="Story",catalog={},connections={}}
env.DarkyStageTest=T
local function add(c) table.insert(T.connections,c) end
local function color(r,g,b)return Color3.fromRGB(r,g,b)end
local C={bg=color(13,14,27),panel=color(26,29,48),accent=color(156,117,255),text=color(239,239,251),muted=color(173,178,205)}
local gui=Instance.new("ScreenGui")
gui.Name="DarkyHubStageTest"
gui.ResetOnSpawn=false
gui.Parent=pg
T.gui=gui
local main=Instance.new("Frame")
main.Size=UDim2.fromOffset(440,470)
main.Position=UDim2.new(0,20,0.5,-235)
main.BackgroundColor3=C.bg
main.BorderSizePixel=0
main.Active=true
main.Parent=gui
Instance.new("UICorner",main).CornerRadius=UDim.new(0,12)
local stroke=Instance.new("UIStroke",main)
stroke.Color=C.accent;stroke.Transparency=.45
local function label(parent,text,height)
 local t=Instance.new("TextLabel");t.Size=UDim2.new(1,-18,0,height or 24)
 t.BackgroundTransparency=1;t.Text=text;t.TextColor3=C.text;t.Font=Enum.Font.Gotham;t.TextSize=12
 t.TextXAlignment=Enum.TextXAlignment.Left;t.TextWrapped=true;t.Parent=parent;return t
end
local title=label(main,"  DARKYHUB   /   TEST STAGE NAVIGATOR",39)
title.Font=Enum.Font.GothamBold;title.TextSize=15;title.TextColor3=C.accent
local info=label(main,"Hub-only test • UI interaction, no unverified remotes",40)
info.Position=UDim2.fromOffset(9,38)
local mode=Instance.new("TextButton")
mode.Size=UDim2.new(1,-18,0,33);mode.Position=UDim2.fromOffset(9,82)
mode.Text="MODE: STORY (click to change)";mode.Font=Enum.Font.GothamBold;mode.TextColor3=C.text
mode.BackgroundColor3=C.panel;mode.Parent=main
Instance.new("UICorner",mode).CornerRadius=UDim.new(0,7)
local scroll=Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-18,0,274);scroll.Position=UDim2.fromOffset(9,124)
scroll.BackgroundColor3=C.panel;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=4
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;scroll.CanvasSize=UDim2.new()
scroll.Parent=main
Instance.new("UICorner",scroll).CornerRadius=UDim.new(0,7)
local list=Instance.new("UIListLayout",scroll)
list.Padding=UDim.new(0,3)
local launch=Instance.new("TextButton")
launch.Position=UDim2.fromOffset(9,406);launch.Size=UDim2.new(1,-18,0,43)
launch.BackgroundColor3=C.accent;launch.Font=Enum.Font.GothamBold;launch.TextColor3=C.bg
launch.Text="SELECT A STAGE";launch.Parent=main
Instance.new("UICorner",launch).CornerRadius=UDim.new(0,8)
local function textOf(node,relative)
 local o=node
 for bit in string.gmatch(relative,"[^/]+") do o=o and o:FindFirstChild(bit) end
 if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then return o.Text end
 return ""
end
local function find(root,relative)
 local o=root
 for bit in string.gmatch(relative,"[^/]+") do o=o and o:FindFirstChild(bit) end
 return o
end
local function stageRows()
 return find(pg,"HubWindows/Stages/Pop/Panel/Fill/Select/Levels/Row")
end
local function readStages()
 local rows=stageRows()
 if not rows then return end
 for _,node in ipairs(rows:GetChildren()) do
  if node:IsA("GuiButton") and (node.Name:match("^Stage%d+$") or node.Name:match("^Infinite_")) then
   local n=node.Name
   local entry={id=n,kind=n:match("^Infinite_") and "Infinite" or "Story",
     act=textOf(node,"Body/Face/Number/N/Label"),
     title=textOf(node,"Body/Face/Title/Label"),
     difficulty=textOf(node,"Body/Face/Difficulty/Fill/Text/Label"),
     waves=textOf(node,"Body/Face/Stats/Waves/Label")}
   if entry.kind=="Infinite" then
    entry.world=n:gsub("Infinite_","")
   else
    local num=tonumber(n:match("%d+")) or 0
    if num<=4 or num==21 then entry.world="candy"
    elseif num<=8 or num==22 then entry.world="ice"
    elseif num<=12 or num==23 then entry.world="fire"
    elseif num<=16 or num==24 then entry.world="mo"
    elseif num<=20 or num==25 then entry.world="lemon"
    elseif num<=32 then entry.world="nightosphere"
    else entry.world="crystal" end
   end
   T.catalog[n]=entry
  end
 end
end
local function readChallenges()
 local root=find(pg,"HubWindows/Challenges/Pop/Panel/Fill")
 if not root then return end
 for n=1,3 do
  local car=root:FindFirstChild("Car"..n)
  if car then T.catalog["Car"..n]={id="Car"..n,kind="Challenge",
      title=textOf(car,"Fill/Stage/Fill/Text/Label"),
      difficulty=textOf(car,"Fill/Difficulty/Fill/Text/Label"),
      world=textOf(car,"Fill/World/Fill/Text/Label")} end
 end
end
local function updateInfo(s) info.Text=s end
local function click(btn)
 if not btn or not btn:IsA("GuiButton") then return false,"Button not available" end
 if not btn.Visible then return false,"Open the game menu first" end
 local active=btn
 while active and active~=pg do
  if active:IsA("GuiObject") and not active.Visible then return false,"Game menu is hidden" end
  active=active.Parent
 end
 if type(getconnections)=="function" then
  local ok,cs=pcall(getconnections,btn.Activated)
  if ok and type(cs)=="table" then
   for _,c in ipairs(cs) do
    if c.Function and type(c.Function)=="function" then
     local good=pcall(c.Function)
     if good then return true,"Activated button callback" end
    end
   end
  end
 end
 return false,"No supported activation callback; select the stage manually"
end
function T.scan()
 readStages();readChallenges()
 return T.catalog
end
function T.save()
 if type(writefile)~="function" then return false,"writefile unavailable" end
 local file="DarkyHubStageTest_"..tostring(player.UserId)..".json"
 local ok,err=pcall(function()writefile(file,HttpService:JSONEncode({catalog=T.catalog,selected=T.selected,mode=T.mode}))end)
 return ok,ok and file or tostring(err)
end
function T.refresh()
 T.scan()
 for _,child in ipairs(scroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy()end end
 local items={}
 for _,entry in pairs(T.catalog) do
  if entry.kind==T.mode then table.insert(items,entry)end
 end
 table.sort(items,function(a,b)
  local na=tonumber(a.id:match("%d+")) or 1000
  local nb=tonumber(b.id:match("%d+")) or 1000
  return na==nb and a.id<b.id or na<nb
 end)
 for _,e in ipairs(items) do
  local b=Instance.new("TextButton")
  b.Size=UDim2.new(1,-8,0,42);b.BackgroundColor3=e.id==T.selected and C.accent or C.panel
  b.TextColor3=C.text;b.Font=Enum.Font.Gotham;b.TextSize=12
  b.TextXAlignment=Enum.TextXAlignment.Left
  b.Text="  "..e.id.."  | "..(e.title~="" and e.title or e.world or "").."  "..(e.waves or "")
  b.Parent=scroll
  Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
  add(b.Activated:Connect(function()
   T.selected=e.id;T.refresh()
   updateInfo(e.id.." | "..(e.title or "").." | "..(e.difficulty or ""))
   launch.Text="SELECT "..e.id.." IN GAME MENU"
   T.save()
  end))
 end
 if #items==0 then updateInfo("No "..T.mode.." entries loaded yet. Visit the hub to expose its GUI.")end
end
local modeList={"Story","Infinite","Challenge"}
add(mode.Activated:Connect(function()
 local i=table.find(modeList,T.mode) or 1
 T.mode=modeList[i%#modeList+1]
 mode.Text="MODE: "..string.upper(T.mode).." (click to change)"
 T.selected=nil;T.refresh()
end))
add(launch.Activated:Connect(function()
 if game.PlaceId~=111053011787075 then updateInfo("Stage selection is hub-only. Return to hub first.");return end
 local e=T.catalog[T.selected]
 if not e then T.refresh();return end
 local button
 if e.kind=="Challenge" then
  button=find(pg,"HubWindows/Challenges/Pop/Panel/Fill/"..e.id.."/Fill/Play")
 else button=stageRows() and stageRows():FindFirstChild(e.id) end
 local ok,why=click(button)
 updateInfo(ok and ("Requested "..e.id.."; confirm game selection manually") or why)
 if ok and e.kind~="Challenge" then
  local play=find(pg,"HubWindows/Stages/Pop/Panel/Fill/Select/Play")
  launch.Text=play and "SELECTED: press game's PLAY to enter lobby" or "STAGE SELECTED"
 end
end))
function T.cleanup()
 for _,c in ipairs(T.connections)do pcall(function()c:Disconnect()end)end
 if gui then gui:Destroy()end
end
T.refresh()
task.spawn(function()
 while gui.Parent do task.wait(8);T.scan() end
end)
print("[DarkyHub TEST] catalog navigator ready |",game.PlaceId)

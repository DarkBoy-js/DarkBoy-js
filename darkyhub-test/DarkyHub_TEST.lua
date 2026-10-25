-- DarkyHub TEST ONLY | stage catalog navigation prototype v1.2
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
local function isVisible(node)
 if not node then return false end
 while node and node~=pg do
  if node:IsA("GuiObject") and not node.Visible then return false end
  node=node.Parent
 end
 return true
end
local function click(btn)
 if not btn or not btn:IsA("GuiButton") then return false,"Button missing" end
 if not isVisible(btn) then return false,"Game menu is hidden" end
 if type(getconnections)=="function" then
  for _,signal in ipairs({btn.Activated,btn.MouseButton1Click}) do
   local ok,connections=pcall(getconnections,signal)
   if ok and type(connections)=="table" then
    for _,connection in ipairs(connections) do
     if type(connection.Fire)=="function" then
      if pcall(function() connection:Fire() end) then return true,"Connection fired" end
     elseif type(connection.Function)=="function" then
      if pcall(connection.Function) then return true,"Callback requested" end
     end
    end
   end
  end
 end
 if type(firesignal)=="function" then
  if pcall(firesignal,btn.Activated) then return true,"Activated signal sent" end
  if pcall(firesignal,btn.MouseButton1Click) then return true,"Click signal sent" end
 end
 local vim=game:GetService("VirtualInputManager")
 local point=btn.AbsolutePosition+btn.AbsoluteSize/2
 local ok=pcall(function()
  vim:SendMouseButtonEvent(point.X,point.Y,0,true,game,0)
  task.wait(0.08)
  vim:SendMouseButtonEvent(point.X,point.Y,0,false,game,0)
 end)
 return ok,ok and "Screen click requested" or "Executor cannot activate this button"
end
local function showGameMenu(kind)
 local root=kind=="Challenge" and find(pg,"HubWindows/Challenges/Pop")
  or find(pg,"HubWindows/Stages/Pop")
 if root and root:IsA("GuiObject") and root.Visible then return true end
 -- Request opening through the game's own accessible hub controls.
 local menu=kind=="Challenge" and find(pg,"HubHUD/Areas") or
  (find(pg,"HubHUD/Play") or find(pg,"HubHUD/Areas"))
 local ok,reason=click(menu)
 if ok then task.wait(0.7) end
 root=kind=="Challenge" and find(pg,"HubWindows/Challenges/Pop")
  or find(pg,"HubWindows/Stages/Pop")
 return root and root.Visible or false,ok and "Open the "..kind.." panel (Areas or world portal)" or reason
end
local function locatePlay(container)
 if not container then return nil end
 for _,obj in ipairs(container:GetDescendants()) do
  if obj:IsA("GuiButton") and isVisible(obj) then
   local name=obj.Name:upper()
   local title=obj:IsA("TextButton") and obj.Text:upper() or ""
   if name=="PLAY" or name=="START" or title=="PLAY!" or title=="PLAY" or title=="START" then
    return obj
   end
  end
 end
 return nil
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
local running=false
add(launch.Activated:Connect(function()
 if running then return end
 if game.PlaceId~=111053011787075 then updateInfo("Only available in the hub.");return end
 local entry=T.catalog[T.selected]
 if not entry then T.refresh();updateInfo("Choose a stage first.");return end
 running=true
 launch.Text="JOINING "..entry.id.." ..."
 task.spawn(function()
  local ok,err=pcall(function()
   local opened,why=showGameMenu(entry.kind)
   if not opened then
    updateInfo("Open the "..entry.kind.." menu in the game, then press Join again. "..tostring(why))
    return
   end
   local button
   if entry.kind=="Challenge" then
    local card=find(pg,"HubWindows/Challenges/Pop/Panel/Fill/"..entry.id)
    button=card and locatePlay(card)
    if not button then updateInfo("Challenge "..entry.id.." has no visible Play button. Open its card.");return end
    local yes,reason=click(button)
    updateInfo(yes and ("Challenge "..entry.id.." Play requested — check lobby status") or tostring(reason))
   else
    button=stageRows() and stageRows():FindFirstChild(entry.id)
    local selected,reason=click(button)
    if not selected then updateInfo("Stage selection failed: "..tostring(reason));return end
    task.wait(0.35)
    local picker=find(pg,"HubWindows/Stages/Pop/Panel/Fill/Select")
    local play=picker and locatePlay(picker)
    if not play then updateInfo(entry.id.." selected. Open the game Play confirmation and try again.");return end
    local yes,why=click(play)
    updateInfo(yes and (entry.id.." Play requested — check stage lobby") or tostring(why))
   end
   T.save()
  end)
  if not ok then updateInfo("TEST join error: "..tostring(err)) end
  running=false
  launch.Text="JOIN SELECTED "..string.upper(T.mode)
 end)
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

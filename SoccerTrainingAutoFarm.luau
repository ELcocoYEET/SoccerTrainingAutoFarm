--[[
    AUTO FARM — Soccer Training ⚽
    PlaceId: 15308782509  |  Frostyy Studio
    -----------------------------------------------------------------------
    Tabs:  MAIN     — auto train, auto kick, auto rebirth, auto equip pets,
                      auto craft pets
           UPGRADES — 10 gem-upgrade auto-buys with per-level cost check
           MISC     — claim all season pass rewards (Free + Premium)
           TP       — World 1-4 + 3 persistent custom spots

    RightShift → toggle GUI visibility
    Draggable title bar   |   – / + to minimise   |   X to close + cleanup
    -----------------------------------------------------------------------
]]

local CoreGui = game:GetService("CoreGui")
for _,n in ipairs({"SoccerFarmGUI","DIAG"}) do local e=CoreGui:FindFirstChild(n); if e then e:Destroy() end end

local RS          = game:GetService("ReplicatedStorage")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local TweenService= game:GetService("TweenService")
local Players     = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local lp          = Players.LocalPlayer
local conns       = {}

-- ── REMOTES ──────────────────────────────────────────────────────────────────
local Knit = RS.Library.Knit.Services

local TrainRE       = Knit.TrainingService.RE.Train
local ThrowRE       = Knit.ThrowService.RE.Throw
local BoostRE       = Knit.ThrowService.RE.ClickBoost
local FinishRE      = Knit.ThrowService.RE.Finish
local RebirthRE     = Knit.RebirthService.RE.Rebirth
local UpgradeRE     = Knit.UpgradesService.RE.Upgrade
local EquipBestRE   = Knit.PetsService.RE.EquipBest
local CraftPetRE    = Knit.PetsService.RE.Craft
local TeleportRE    = Knit.MapsService.RE.Teleport
local BuyBallRE     = Knit.ItemsService.RE.Buy
local EquipBallRE   = Knit.ItemsService.RE.Equip
local UseItemRE     = Knit.InventoryService.RE.Use
local DailyRE       = Knit.DailyRewardsService.RE.Claim
local ChestRE       = Knit.ChestService.RE.Claim
local SpinRE        = Knit.SpinsService.RE.Spin
local PlaytimeRE    = Knit.PlaytimeRewardService.RE.Claim
local GroupRE       = Knit.MiscService.RE.GroupReward
local HatchEggRE    = Knit.EggsService.RE.HatchEgg
local JuiceCraftRE  = Knit.JuiceMachineService.RE.Craft
local SeasonpassRE  = Knit.SeasonpassService.RE.Claim
local AchievementRE = Knit.AchievementService.RE.Claim
local getDataRF     = Knit.HandlerService.RF.getData

-- ── CONFIGS ───────────────────────────────────────────────────────────────────
local MiscConfig, UpgradesConfig, SeasonpassConfig, ItemsConfig, CraftingConfig, EggsConfig
pcall(function() MiscConfig      = require(RS.Configs.MiscConfig)      end)
pcall(function() UpgradesConfig  = require(RS.Configs.UpgradesConfig)  end)
pcall(function() SeasonpassConfig= require(RS.Configs.SeasonpassConfig) end)
pcall(function() ItemsConfig     = require(RS.Configs.ItemsConfig)      end)
pcall(function() CraftingConfig  = require(RS.Configs.CraftingConfig)   end)
pcall(function() EggsConfig      = require(RS.Configs.EggsConfig)       end)

local UPGRADES = {
    {key="upRebirth",  label="Rebirth Buttons", id="RebirthButton",col=Color3.fromRGB(255,160,40)},
    {key="upCash",     label="Cash Boost",       id="CashBoost",    col=Color3.fromRGB(80,220,120)},
    {key="upPower",    label="Power Boost",      id="PowerBoost",   col=Color3.fromRGB(255,200,50)},
    {key="upPetEquip", label="Pet Equip Slots",  id="PetEquip",     col=Color3.fromRGB(200,100,255)},
    {key="upEggLuck",  label="Egg Luck",         id="EggsLuck",     col=Color3.fromRGB(120,200,255)},
    {key="upGold",     label="Gold Chance",      id="GoldChance",   col=Color3.fromRGB(255,215,80)},
    {key="upHatch",    label="Hatch Speed",      id="HatchSpeed",   col=Color3.fromRGB(100,255,180)},
    {key="upPetStore", label="Pet Storage",      id="PetStorage",   col=Color3.fromRGB(255,100,100)},
    {key="upTrain",    label="Train Speed",      id="TrainSpeed",   col=Color3.fromRGB(100,180,255)},
    {key="upWalk",     label="Walk Speed",       id="WalkSpeed",    col=Color3.fromRGB(200,255,150)},
}

local COLS = {
    main     = Color3.fromRGB(255,180,50),
    upgrades = Color3.fromRGB(140,100,255),
    misc     = Color3.fromRGB(80,180,255),
    tp       = Color3.fromRGB(255,120,200),
}

local toggles = {
    autoTrain=false, autoKick=false, autoRebirth=false,
    autoEquipPets=false, autoCraftPets=false, autoBuyBall=false, autoHatchEgg=false,
    autoSeasonpass=false, autoAchieve=false, noKickFX=false,
    autoUseFruits=false, autoDaily=false, autoJuiceMachine=false,
}
for _,u in UPGRADES do toggles[u.key]=false end

-- ── STATE ─────────────────────────────────────────────────────────────────────
local cachedData  = nil
local customSpots = {{name="Spot 1",pos=nil},{name="Spot 2",pos=nil},{name="Spot 3",pos=nil}}

local SPOTS_FILE = "SoccerFarm_spots.json"
local function saveSpots()
    pcall(function()
        local t={}
        for i,s in ipairs(customSpots) do t[i]=s.pos and {s.pos.X,s.pos.Y,s.pos.Z} or false end
        writefile(SPOTS_FILE, HttpService:JSONEncode(t))
    end)
end
pcall(function()
    if isfile and isfile(SPOTS_FILE) then
        local t = HttpService:JSONDecode(readfile(SPOTS_FILE))
        for i,v in ipairs(t) do if v and customSpots[i] then customSpots[i].pos=Vector3.new(v[1],v[2],v[3]) end end
    end
end)

-- ── HELPERS ───────────────────────────────────────────────────────────────────
local SUF = {{1e33,"Dc"},{1e30,"No"},{1e27,"Oc"},{1e24,"Sp"},{1e21,"Sx"},{1e18,"Qi"},{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
local function fmtNum(n) n=tonumber(n)or 0; for _,s in ipairs(SUF) do if n>=s[1] then return string.format("%.2f%s",n/s[1],s[2]) end end; return tostring(math.floor(n)) end

local function refreshData()
    pcall(function() cachedData = getDataRF:InvokeServer() end)
end

-- leaderstats Cash is a formatted STRING like "7.25T" — always use cachedData for math
local function getCash()    return cachedData and tonumber(cachedData.Cash)    or 0 end
local function getPower()   return cachedData and cachedData.Power             or 0 end
local function getRebirth() return cachedData and cachedData.Rebirth           or 0 end
local function getGems()    return cachedData and cachedData.Gems              or 0 end
local AREA_LABEL = {["1"]="W1",["2"]="W2",["3"]="W3",["4"]="W4",["Event"]="EVT"}
local function getWorld()
    local a = tostring(lp:GetAttribute("CurrentArea") or "")
    return AREA_LABEL[a] or a ~= "" and a or "?"
end
local function getCostPer1()
    if not MiscConfig then return math.huge end
    local ok,c = pcall(function() return MiscConfig.Functions.getCostOfRebirth(getRebirth(),1) end)
    return ok and c or math.huge
end
local function getHRP() local c=lp.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function tpTo(pos) local hrp=getHRP(); if hrp and pos then hrp.CFrame=CFrame.new(pos+Vector3.new(0,4,0)) end end

-- Build craft groups sorted by tier priority: Gold first (→Diamond), then Classic (→Gold)
-- Server resolves output tier from what you send; same Craft remote for both machines.
local CRAFT_PRIORITY = {Gold=1, Classic=2, Diamond=3}
local function buildCraftGroups()
    if not cachedData or not cachedData.Pets then return {} end
    local groups = {}
    for id, p in pairs(cachedData.Pets) do
        if type(p) == "table" and not p.Locked then
            local sig = (p.Name or "") .. "|" .. (p.Type or "")
            if not groups[sig] then groups[sig] = {petType=(p.Type or ""), ids={}} end
            table.insert(groups[sig].ids, id)
        end
    end
    local list = {}
    for _, g in pairs(groups) do
        if #g.ids >= 5 then table.insert(list, g) end
    end
    table.sort(list, function(a,b)
        return (CRAFT_PRIORITY[a.petType] or 99) < (CRAFT_PRIORITY[b.petType] or 99)
    end)
    return list
end

-- EGG_NAMES — set of inventory item names that are eggs (from EggsConfig)
local EGG_NAMES = {}
pcall(function()
    if EggsConfig then for k in pairs(EggsConfig) do EGG_NAMES[k] = true end end
end)

-- JUICE MACHINE craft helpers
-- Bottom-up order: craft raw-fruit potions first, combine up to Cocktail, then Royal Potion
local JUICE_ORDER = {
    "Cash Potion","Power Potion","Luck Potion",
    "Cocktail Potion",
    "Royal Potion",
    "Golden Banana Fruit","Golden Apple Fruit","Golden Carrot Fruit",
    "Golden Orange Fruit","Golden Blueberry Fruit",
}
local function canCraftItem(name)
    if not CraftingConfig or not cachedData or not cachedData.Inventory then return false end
    local recipe = CraftingConfig[name]; if not recipe then return false end
    for _, ing in ipairs(recipe) do
        if (cachedData.Inventory[ing.Name] or 0) < ing.Amount then return false end
    end
    return true
end
local function doCraftItem(name)
    if not canCraftItem(name) then return false end
    pcall(function() JuiceCraftRE:FireServer(name) end)
    -- optimistic local deduction so we can chain-craft without waiting for data refresh
    local inv = cachedData.Inventory
    for _, ing in ipairs(CraftingConfig[name]) do
        inv[ing.Name] = (inv[ing.Name] or 0) - ing.Amount
    end
    inv[name] = (inv[name] or 0) + 1
    return true
end

-- POTIONS & FRUITS we want to auto-use (server rejects if buff already active)
local USE_ITEMS = {
    "Royal Potion","Cocktail Potion","Cash Potion","Power Potion","Luck Potion",
    "Golden Banana Fruit","Golden Apple Fruit","Golden Carrot Fruit",
    "Golden Orange Fruit","Golden Blueberry Fruit",
    "Banana Fruit","Apple Fruit","Carrot Fruit","Orange Fruit","Blueberry Fruit",
}

-- Build the ball upgrade chain (non-Robux, non-Hidden) by following Required links
local BALL_CHAIN = {}
pcall(function()
    if not ItemsConfig then return end
    -- index by Required so we can walk forward
    local byRequired = {}
    for name, data in pairs(ItemsConfig) do
        if not data.Robux and not data.Hide then
            if data.Required then
                byRequired[data.Required] = name
            end
        end
    end
    local cur = "Basic Ball"
    while cur do
        table.insert(BALL_CHAIN, cur)
        cur = byRequired[cur]
    end
end)

-- ── GUI PRIMITIVE HELPERS ─────────────────────────────────────────────────────
local function Corner(p,r)   local c=Instance.new("UICorner",p); c.CornerRadius=UDim.new(0,r or 8); return c end
local function Stroke(p,col,th) local s=Instance.new("UIStroke",p); s.Color=col; s.Thickness=th or 1; return s end
local function F(par,sz,pos,bg,a)
    local f=Instance.new("Frame",par); f.Size=sz; f.Position=pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3=bg or Color3.fromRGB(14,14,24); f.BackgroundTransparency=a or 0
    f.BorderSizePixel=0; return f
end
local function L(par,txt,sz,pos,col,ts,font,xa)
    local l=Instance.new("TextLabel",par); l.Text=txt; l.Size=sz
    l.Position=pos or UDim2.new(0,0,0,0); l.BackgroundTransparency=1
    l.TextColor3=col or Color3.new(1,1,1); l.TextSize=ts or 12
    l.Font=font or Enum.Font.GothamBold; l.TextXAlignment=xa or Enum.TextXAlignment.Left
    l.BorderSizePixel=0; return l
end
local function B(par,txt,sz,pos,bg,tc)
    local b=Instance.new("TextButton",par); b.Text=txt; b.Size=sz
    b.Position=pos or UDim2.new(0,0,0,0); b.BackgroundColor3=bg or Color3.fromRGB(30,30,50)
    b.TextColor3=tc or Color3.new(1,1,1); b.TextSize=12; b.Font=Enum.Font.GothamBold
    b.BorderSizePixel=0; return b
end

-- ── MAIN WINDOW ───────────────────────────────────────────────────────────────
local W,H = 360, 600
local sg = Instance.new("ScreenGui")
sg.Name="SoccerFarmGUI"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.DisplayOrder=999; sg.Parent=CoreGui

local main = F(sg, UDim2.new(0,W,0,H), UDim2.new(0,20,0.5,-H/2), Color3.fromRGB(10,10,16))
main.ClipsDescendants=true; Corner(main,12)
local bgG = Instance.new("UIGradient",main)
bgG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(15,15,26)),ColorSequenceKeypoint.new(1,Color3.fromRGB(8,8,14))}
bgG.Rotation=135
local rgbS = Stroke(main, Color3.fromRGB(80,120,255), 2.5)

-- Title bar
local tb = F(main, UDim2.new(1,0,0,48), nil, Color3.fromRGB(14,14,24)); Corner(tb,12)
F(tb, UDim2.new(1,0,0.5,0), UDim2.new(0,0,0.5,0), Color3.fromRGB(14,14,24))
local aL = F(tb, UDim2.new(1,0,0,2), UDim2.new(0,0,1,-2), Color3.new(1,1,1))
local aG = Instance.new("UIGradient",aL)
aG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(80,120,255)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(200,80,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(80,220,255))}
local dot = F(tb, UDim2.new(0,9,0,9), UDim2.new(0,13,0.5,-4), Color3.fromRGB(80,200,255)); Corner(dot,5)
local tLbl = L(tb, "Soccer Training \226\154\189", UDim2.new(1,-100,0,28), UDim2.new(0,30,0,4), nil, 17)
local tG = Instance.new("UIGradient",tLbl)
tG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(200,220,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(100,150,255))}
L(tb, "Made by Claude with Love", UDim2.new(1,-100,0,14), UDim2.new(0,30,0,30), Color3.fromRGB(70,90,160), 10, Enum.Font.Gotham)
local minB = B(tb,"-",UDim2.new(0,28,0,28),UDim2.new(1,-62,0.5,-14),Color3.fromRGB(28,28,46),Color3.fromRGB(160,160,255)); Corner(minB,6)
local clsB = B(tb,"X",UDim2.new(0,28,0,28),UDim2.new(1,-30,0.5,-14),Color3.fromRGB(150,28,28),Color3.new(1,1,1)); Corner(clsB,6)

clsB.MouseButton1Click:Connect(function()
    for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    sg:Destroy()
end)
local minimized = false
minB.MouseButton1Click:Connect(function()
    minimized=not minimized; minB.Text=minimized and "+" or "-"
    TweenService:Create(main,TweenInfo.new(0.22,Enum.EasingStyle.Quad),{Size=UDim2.new(0,W,0,minimized and 48 or H)}):Play()
end)

-- Dragging
local dg,dS,dP = false
tb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dg=true;dS=i.Position;dP=main.Position end end)
table.insert(conns, UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dg=false end end))
table.insert(conns, UIS.InputChanged:Connect(function(i) if dg and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-dS; main.Position=UDim2.new(dP.X.Scale,dP.X.Offset+d.X,dP.Y.Scale,dP.Y.Offset+d.Y) end end))

-- Anti-AFK
table.insert(conns, lp.Idled:Connect(function()
    pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
end))

-- RightShift to toggle visibility
table.insert(conns, UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.RightShift then main.Visible=not main.Visible end
end))

-- Body
local body = F(main, UDim2.new(1,0,1,-48), UDim2.new(0,0,0,48), Color3.new(0,0,0), 1)

-- Stats chips
local sBar = F(body, UDim2.new(1,-16,0,58), UDim2.new(0,8,0,8), Color3.fromRGB(14,14,24)); Corner(sBar,8); Stroke(sBar,Color3.fromRGB(28,28,50))
local function chip(lbl,idx,col)
    local c=F(sBar,UDim2.new(0.2,-6,1,-10),UDim2.new(0.2*idx,3,0,5),Color3.fromRGB(17,17,30)); Corner(c,6); Stroke(c,col)
    L(c,lbl,UDim2.new(1,0,0.42,0),UDim2.new(0,0,0,4),Color3.fromRGB(90,90,130),9,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    return L(c,"...",UDim2.new(1,0,0.5,0),UDim2.new(0,0,0.46,0),col,12,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
end
local sCash  = chip("CASH",   0, Color3.fromRGB(80,220,120))
local sPow   = chip("POWER",  1, Color3.fromRGB(255,180,50))
local sReb   = chip("REBIRTH",2, Color3.fromRGB(120,160,255))
local sGems  = chip("GEMS",   3, Color3.fromRGB(200,80,255))
local sWorld = chip("WORLD",  4, Color3.fromRGB(255,215,80))

-- Tab bar
local tabBar = F(body, UDim2.new(1,-16,0,30), UDim2.new(0,8,0,74), Color3.fromRGB(14,14,24)); Corner(tabBar,8)
local TABS   = {"MAIN","UPGRADES","MISC","TP"}
local tBtns  = {}
for i,n in ipairs(TABS) do
    local b=B(tabBar,n,UDim2.new(0.25,-5,1,-6),UDim2.new((i-1)*0.25,3,0,3),Color3.fromRGB(18,18,30),Color3.fromRGB(100,100,130))
    Corner(b,6); b.TextSize=11; tBtns[n]=b
end

local cnt = F(body, UDim2.new(1,-16,1,-112), UDim2.new(0,8,0,112), Color3.new(0,0,0), 1); cnt.ClipsDescendants=true
local pages = {}
for _,n in TABS do local p=F(cnt,UDim2.new(1,0,1,0),nil,Color3.new(0,0,0),1); p.Visible=n=="MAIN"; pages[n]=p end

local function tabKey(n) return (n=="TP") and "tp" or n:lower() end
local function switchTab(name)
    for n,p in pages do p.Visible=(n==name) end
    for n,bBtn in tBtns do
        local on=n==name; local col=COLS[tabKey(n)]
        TweenService:Create(bBtn,TweenInfo.new(0.15),{
            BackgroundColor3 = on and (col or Color3.fromRGB(50,80,180)) or Color3.fromRGB(18,18,30),
            TextColor3       = on and Color3.new(1,1,1) or Color3.fromRGB(100,100,130),
        }):Play()
    end
end
for n,bBtn in tBtns do bBtn.MouseButton1Click:Connect(function() switchTab(n) end) end
switchTab("MAIN")

-- ── TOGGLE ROW BUILDER ────────────────────────────────────────────────────────
local function tRow(par, lbl, sub, key, yp, col)
    local row=F(par,UDim2.new(1,0,0,50),UDim2.new(0,0,0,yp),Color3.fromRGB(14,14,24)); Corner(row,8)
    local rs=Stroke(row,Color3.fromRGB(24,24,42))
    F(row,UDim2.new(0,3,0.65,0),UDim2.new(0,0,0.175,0),col); Corner(F(row,UDim2.new(0,3,0.65,0),UDim2.new(0,0,0.175,0),col),2)
    L(row,lbl,UDim2.new(1,-92,0,22),UDim2.new(0,12,0,8),Color3.fromRGB(225,225,235),14)
    L(row,sub,UDim2.new(1,-92,0,14),UDim2.new(0,12,0,29),Color3.fromRGB(65,65,95),10,Enum.Font.Gotham)
    local track=F(row,UDim2.new(0,54,0,26),UDim2.new(1,-64,0.5,-13),Color3.fromRGB(28,28,46)); Corner(track,13)
    local ts=Stroke(track,Color3.fromRGB(45,45,72))
    local knob=F(track,UDim2.new(0,20,0,20),UDim2.new(0,3,0.5,-10),Color3.fromRGB(70,70,100)); Corner(knob,10)
    local cb=B(track,"",UDim2.new(1,0,1,0),nil,Color3.new(0,0,0),Color3.new(0,0,0)); cb.BackgroundTransparency=1
    cb.MouseButton1Click:Connect(function()
        toggles[key]=not toggles[key]; local on=toggles[key]; local tw=TweenInfo.new(0.18)
        TweenService:Create(knob,tw,{Position=on and UDim2.new(0,31,0.5,-10) or UDim2.new(0,3,0.5,-10),BackgroundColor3=on and Color3.new(1,1,1) or Color3.fromRGB(70,70,100)}):Play()
        TweenService:Create(track,tw,{BackgroundColor3=on and col or Color3.fromRGB(28,28,46)}):Play()
        TweenService:Create(ts,tw,{Color=on and col or Color3.fromRGB(45,45,72)}):Play()
        TweenService:Create(rs,tw,{Color=on and col or Color3.fromRGB(24,24,42)}):Play()
    end)
    return row
end

-- ── MAIN TAB (scrollable) ────────────────────────────────────────────────────
local MAIN_ROWS = {
    {"AUTO TRAIN",     "Power training (server debounce 1s)",         "autoTrain",    COLS.main},
    {"AUTO KICK",      "Throw → ClickBoost → Finish for cash",        "autoKick",     Color3.fromRGB(80,220,120)},
    {"AUTO REBIRTH",   "Most rebirths first → cheapest (no Robux)",   "autoRebirth",  Color3.fromRGB(120,160,255)},
    {"EQUIP BEST PETS","Auto equip strongest pets every 5s",          "autoEquipPets",Color3.fromRGB(200,80,255)},
    {"AUTO CRAFT PETS","Craft 5 same pets (Classic→Gold→Diamond)",    "autoCraftPets",Color3.fromRGB(120,255,180)},
    {"AUTO BUY BALL",  "Buy & equip best affordable ball (no Robux)", "autoBuyBall",  Color3.fromRGB(255,200,50)},
    {"AUTO HATCH EGGS","Hatch all eggs found in inventory",           "autoHatchEgg", Color3.fromRGB(255,120,50)},
}
local mScr = Instance.new("ScrollingFrame", pages.MAIN)
mScr.Size=UDim2.new(1,0,1,0); mScr.BackgroundTransparency=1; mScr.BorderSizePixel=0
mScr.ScrollBarThickness=3; mScr.CanvasSize=UDim2.new(0,0,0,#MAIN_ROWS*54)
mScr.ScrollBarImageColor3=Color3.fromRGB(80,180,255)
for i,r in ipairs(MAIN_ROWS) do tRow(mScr,r[1],r[2],r[3],(i-1)*54,r[4]) end

-- ── UPGRADES TAB ──────────────────────────────────────────────────────────────
local uScr = Instance.new("ScrollingFrame",pages.UPGRADES)
uScr.Size=UDim2.new(1,0,1,0); uScr.BackgroundTransparency=1; uScr.BorderSizePixel=0
uScr.ScrollBarThickness=3; uScr.CanvasSize=UDim2.new(0,0,0,#UPGRADES*54)
uScr.ScrollBarImageColor3=Color3.fromRGB(140,100,255)
for i,u in ipairs(UPGRADES) do
    tRow(uScr, u.label, "Auto buy with Gems (checks price per level)", u.key, (i-1)*54, u.col)
end

-- ── MISC TAB (scrollable) ────────────────────────────────────────────────────
local MISC_ROWS = {
    {"CLAIM SEASON PASS","Claim all Free rewards (5s retry)",              "autoSeasonpass", Color3.fromRGB(255,160,80)},
    {"AUTO ACHIEVEMENTS","Claim all achievements (5s retry)",             "autoAchieve",    Color3.fromRGB(100,220,255)},
    {"NO KICK FX",       "Remove loot debris + cash pop-ups",             "noKickFX",       Color3.fromRGB(180,100,255)},
    {"AUTO USE FRUITS",  "Use all potions & fruits in inventory",         "autoUseFruits",  Color3.fromRGB(100,255,120)},
    {"AUTO DAILY",       "Claim daily/chest/spin/playtime/group rewards", "autoDaily",      Color3.fromRGB(255,215,50)},
    {"JUICE MACHINE",    "Craft fruits → potions (Royal first)",          "autoJuiceMachine",Color3.fromRGB(255,100,160)},
}
local miscScr = Instance.new("ScrollingFrame", pages.MISC)
miscScr.Size=UDim2.new(1,0,1,0); miscScr.BackgroundTransparency=1; miscScr.BorderSizePixel=0
miscScr.ScrollBarThickness=3; miscScr.CanvasSize=UDim2.new(0,0,0,#MISC_ROWS*54)
miscScr.ScrollBarImageColor3=Color3.fromRGB(80,180,255)
for i,r in ipairs(MISC_ROWS) do tRow(miscScr,r[1],r[2],r[3],(i-1)*54,r[4]) end

-- ── TP TAB ────────────────────────────────────────────────────────────────────
local tpPage = pages.TP
L(tpPage,"WORLDS",UDim2.new(1,0,0,16),UDim2.new(0,2,0,0),Color3.fromRGB(255,120,200),11,Enum.Font.GothamBold)

-- Maps: key is a STRING ("1","2","3","4","Event") — NOT a number
local WORLDS = {
    {"Spawn (W1)",       "1",     Color3.fromRGB(80,220,120)},
    {"Desert (W2)",      "2",     Color3.fromRGB(120,200,255)},
    {"Farm (W3)",        "3",     Color3.fromRGB(255,160,40)},
    {"Atlantis (W4)",    "4",     Color3.fromRGB(200,100,255)},
    {"World Cup (Event)","Event", Color3.fromRGB(255,215,50)},
}
for i,d in ipairs(WORLDS) do
    local col=(i-1)%2; local rowi=math.floor((i-1)/2)
    local isLast = (i==#WORLDS) and (#WORLDS%2~=0)
    local bSz = isLast and UDim2.new(1,-2,0,34) or UDim2.new(0.5,-5,0,34)
    local bPos = isLast and UDim2.new(0,0,0,20+rowi*40) or UDim2.new(col*0.5,col==0 and 0 or 10,0,20+rowi*40)
    local b=B(tpPage,d[1],bSz,bPos,Color3.fromRGB(18,18,30),d[3])
    Corner(b,7); Stroke(b,d[3],1); b.TextSize=12
    b.MouseButton1Click:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=d[3]}):Play()
        task.spawn(function()
            pcall(function() TeleportRE:FireServer(d[2]) end)
            task.wait(0.15)
            TweenService:Create(b,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(18,18,30)}):Play()
        end)
    end)
end

local worldRows = math.ceil(#WORLDS/2)
L(tpPage,"CUSTOM SPOTS  (walk to location, hit SET)",UDim2.new(1,0,0,16),UDim2.new(0,2,0,20+worldRows*40+8),Color3.fromRGB(255,120,200),10,Enum.Font.GothamBold)
for i,spot in ipairs(customSpots) do
    local y = 20+worldRows*40+28+(i-1)*40
    local row=F(tpPage,UDim2.new(1,0,0,34),UDim2.new(0,0,0,y),Color3.fromRGB(16,16,28)); Corner(row,7)
    local nm=L(row,spot.name..(spot.pos and "  (saved)" or "  (empty)"),UDim2.new(0.5,-6,1,0),UDim2.new(0,10,0,0),spot.pos and Color3.fromRGB(120,220,150) or Color3.fromRGB(150,150,180),12)
    local setB=B(row,"SET",UDim2.new(0.22,-4,0.74,0),UDim2.new(0.52,0,0.13,0),Color3.fromRGB(40,40,70),Color3.fromRGB(200,200,255)); Corner(setB,5); setB.TextSize=12
    local goB =B(row,"GO", UDim2.new(0.22,-4,0.74,0),UDim2.new(0.76,0,0.13,0),Color3.fromRGB(30,80,120),Color3.fromRGB(180,220,255)); Corner(goB,5);  goB.TextSize=12
    setB.MouseButton1Click:Connect(function()
        local hrp=getHRP(); if hrp then
            spot.pos=hrp.Position; nm.Text=spot.name.."  (saved)"; nm.TextColor3=Color3.fromRGB(120,220,150); saveSpots()
            TweenService:Create(setB,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(40,140,70)}):Play()
            task.wait(0.15); TweenService:Create(setB,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(40,40,70)}):Play()
        end
    end)
    goB.MouseButton1Click:Connect(function()
        if spot.pos then
            tpTo(spot.pos)
            TweenService:Create(goB,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(40,140,200)}):Play()
            task.wait(0.15); TweenService:Create(goB,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(30,80,120)}):Play()
        end
    end)
end

-- ══ LOOPS ════════════════════════════════════════════════════════════════════

-- RGB border
local hue = 0
table.insert(conns, RunService.Heartbeat:Connect(function(dt)
    if not sg or not sg.Parent then return end
    hue=(hue+dt*0.4)%1; rgbS.Color=Color3.fromHSV(hue,1,1); dot.BackgroundColor3=Color3.fromHSV(hue,0.7,1)
end))

-- Data refresh every 2s
task.spawn(function() while sg and sg.Parent do refreshData(); task.wait(2) end end)

-- Stats display
task.spawn(function() while sg and sg.Parent do
    sCash.Text=fmtNum(getCash()); sPow.Text=fmtNum(getPower())
    sReb.Text=fmtNum(getRebirth()); sGems.Text=fmtNum(getGems()); sWorld.Text=tostring(getWorld())
    task.wait(0.5)
end end)

-- AUTO TRAIN
task.spawn(function() while sg and sg.Parent do
    if toggles.autoTrain then
        pcall(function() TrainRE:FireServer() end)
        task.wait(0.001)
    else
        task.wait(0.05)
    end
end end)

-- AUTO KICK — Throw → ClickBoost(1) → Finish
task.spawn(function() while sg and sg.Parent do
    if toggles.autoKick then
        pcall(function()
            ThrowRE:FireServer()
            BoostRE:FireServer(1)
            FinishRE:FireServer()
        end)
        task.wait(0.001)
    else
        task.wait(0.05)
    end
end end)

-- AUTO REBIRTH — iterate from most rebirths (highest amount) down to cheapest; never fires index 0 (Robux)
task.spawn(function() while sg and sg.Parent do
    if toggles.autoRebirth and MiscConfig then
        local cash = getCash()
        local cost = getCostPer1()
        if cash > 0 and cost > 0 then
            local fired = false

            -- Check Rebirth Button upgrade tiers first (higher amounts, unlocked by Upgrades.RebirthButton)
            local upgradeSlots = (cachedData and cachedData.Upgrades and cachedData.Upgrades.RebirthButton) or 0
            for j = upgradeSlots, 1, -1 do
                local amount = MiscConfig.RebirthUpgradesAmountTable[j]
                if amount and cash >= cost * amount then
                    pcall(function() RebirthRE:FireServer(j, "Upgrades") end)
                    fired = true
                    break
                end
            end

            -- Then check default table (1→1000 rebirths, index 1=1rb, 9=1000rb)
            if not fired then
                for i = #MiscConfig.RebirthDefaultAmountTable, 1, -1 do
                    local amount = MiscConfig.RebirthDefaultAmountTable[i]
                    if cash >= cost * amount then
                        pcall(function() RebirthRE:FireServer(i) end)
                        fired = true
                        break
                    end
                end
            end

            task.wait(fired and 0.3 or 0.001)
        else
            task.wait(0.05)
        end
    else
        task.wait(0.05)
    end
end end)

-- AUTO EQUIP PETS
task.spawn(function() while sg and sg.Parent do
    if toggles.autoEquipPets then pcall(function() EquipBestRE:FireServer() end) end
    task.wait(5)
end end)

-- AUTO CRAFT PETS — prioritises Gold→Diamond over Classic→Gold; drains all groups per cycle
task.spawn(function() while sg and sg.Parent do
    if toggles.autoCraftPets then
        local crafted = false
        local groups = buildCraftGroups()
        for _, g in ipairs(groups) do
            while #g.ids >= 5 do
                local batch = {g.ids[1],g.ids[2],g.ids[3],g.ids[4],g.ids[5]}
                pcall(function() CraftPetRE:FireServer(batch) end)
                -- remove consumed ids and refresh data
                for i = 1, 5 do table.remove(g.ids, 1) end
                crafted = true
                task.wait(0.5)
                refreshData()
                -- rebuild remaining from fresh data
                local fresh = buildCraftGroups()
                g = (function()
                    for _, ng in ipairs(fresh) do
                        if ng.petType == g.petType then return ng end
                    end
                    return {ids={}}
                end)()
            end
        end
        task.wait(crafted and 1 or 2)
    else
        task.wait(0.5)
    end
end end)

-- AUTO BUY BALL — walks chain, buys next affordable ball, equips highest owned
task.spawn(function() while sg and sg.Parent do
    if toggles.autoBuyBall and ItemsConfig and #BALL_CHAIN > 0 then
        pcall(function()
            local owned  = (cachedData and cachedData.Items)         or {}
            local cash   = getCash()
            local bestIdx = 0

            for i, name in ipairs(BALL_CHAIN) do
                if owned[name] then bestIdx = i end
            end

            -- buy every next ball in chain we can now afford
            local i = bestIdx + 1
            while i <= #BALL_CHAIN do
                local name = BALL_CHAIN[i]
                local cfg  = ItemsConfig[name]
                if cfg and cash >= (cfg.Price or math.huge) then
                    pcall(function() BuyBallRE:FireServer(name) end)
                    owned[name] = true
                    bestIdx = i
                    cash = cash - cfg.Price
                    task.wait(0.3)
                    i = i + 1
                else
                    break
                end
            end

            -- equip the best owned ball
            if bestIdx > 0 then
                local best = BALL_CHAIN[bestIdx]
                if (cachedData and cachedData.EquippedItem) ~= best then
                    pcall(function() EquipBallRE:FireServer(best) end)
                end
            end
        end)
    end
    task.wait(5)
end end)

-- AUTO HATCH EGGS — hatch any egg found in inventory
task.spawn(function() while sg and sg.Parent do
    if toggles.autoHatchEgg then
        pcall(function()
            local inv = cachedData and cachedData.Inventory
            if not inv then return end
            for name, count in pairs(inv) do
                if EGG_NAMES[name] and (type(count) == "number") and count > 0 then
                    for _ = 1, count do
                        pcall(function() HatchEggRE:FireServer(name) end)
                        task.wait(0.15)
                    end
                end
            end
        end)
    end
    task.wait(3)
end end)

-- AUTO DAILY REWARDS — fire all daily/chest/spin/playtime/group remotes; server rejects if on cooldown
task.spawn(function() while sg and sg.Parent do
    if toggles.autoDaily then
        pcall(function() DailyRE:FireServer()    end) task.wait(0.2)
        pcall(function() ChestRE:FireServer()    end) task.wait(0.2)
        pcall(function() SpinRE:FireServer()     end) task.wait(0.2)
        pcall(function() PlaytimeRE:FireServer() end) task.wait(0.2)
        pcall(function() GroupRE:FireServer()    end)
    end
    task.wait(60)
end end)

-- AUTO USE FRUITS/POTIONS — skip item if buff is already active (Potions/Fruits track remaining seconds)
task.spawn(function() while sg and sg.Parent do
    if toggles.autoUseFruits then
        pcall(function()
            local inv     = cachedData and cachedData.Inventory or {}
            local potions = cachedData and cachedData.Potions   or {}
            local fruits  = cachedData and cachedData.Fruits    or {}
            for _, name in ipairs(USE_ITEMS) do
                local alreadyActive = (potions[name] or 0) > 0 or (fruits[name] or 0) > 0
                if not alreadyActive and (inv[name] or 0) > 0 then
                    pcall(function() UseItemRE:FireServer(name) end)
                    task.wait(0.1)
                end
            end
        end)
    end
    task.wait(5)
end end)

-- JUICE MACHINE — round-robin base potions so shared ingredients (Carrot etc.) split evenly,
-- then combine up to Cocktail → Royal Potion
task.spawn(function() while sg and sg.Parent do
    if toggles.autoJuiceMachine and CraftingConfig then
        -- Phase 1: craft Cash/Power/Luck one-at-a-time in rotation so no ingredient gets hogged
        local anyBase = true
        while anyBase do
            anyBase = false
            for _, name in ipairs({"Cash Potion","Power Potion","Luck Potion"}) do
                if canCraftItem(name) then
                    doCraftItem(name)
                    anyBase = true
                end
            end
        end
        -- Phase 2: combine base potions into Cocktail Potions
        while canCraftItem("Cocktail Potion") do doCraftItem("Cocktail Potion") end
        -- Phase 3: craft all Royal Potions
        while canCraftItem("Royal Potion") do doCraftItem("Royal Potion") end
        -- Phase 4: golden fruits from leftover raw fruits
        for _, name in ipairs({"Golden Banana Fruit","Golden Apple Fruit","Golden Carrot Fruit","Golden Orange Fruit","Golden Blueberry Fruit"}) do
            while canCraftItem(name) do doCraftItem(name) end
        end
        refreshData()
    end
    task.wait(0.5)
end end)

-- AUTO UPGRADES
task.spawn(function() while sg and sg.Parent do
    pcall(function()
        if not cachedData or not UpgradesConfig then return end
        local gems = getGems()
        local ownedUpgrades = cachedData.Upgrades or {}
        local area = tostring(lp:GetAttribute("CurrentArea") or 1)
        for _,u in UPGRADES do
            if toggles[u.key] then
                local cfg = UpgradesConfig[u.id]; if not cfg then continue end
                local worldCfg = cfg["World"..area]; if not worldCfg then continue end
                local lvl = math.clamp(ownedUpgrades[u.id] or 0, 0, worldCfg.MaxLevel)
                if lvl >= worldCfg.MaxLevel then continue end
                local price = cfg.Data and cfg.Data[lvl+1] and cfg.Data[lvl+1].Price
                if price and gems >= price then
                    UpgradeRE:FireServer(u.id)
                    task.wait(0.4)
                end
            end
        end
    end)
    task.wait(2)
end end)

-- CLAIM SEASON PASS — Free tier only (no PremiumPass); server rejects already-claimed
task.spawn(function() while sg and sg.Parent do
    if toggles.autoSeasonpass and SeasonpassConfig then
        pcall(function()
            local rewards = SeasonpassConfig.Rewards
            for k = 1, #rewards do
                pcall(function() SeasonpassRE:FireServer("Free", k) end)
                task.wait(0.1)
            end
        end)
    end
    task.wait(5)
end end)

-- AUTO ACHIEVEMENTS — fires all 9 achievement keys; server rejects already-maxed or not-ready
local ACHIEVE_KEYS = {
    "TotalThrows","TotalPower","TotalCash","EggsHatched",
    "LegendarysHatched","GoldPetsCrafted","DiamondPetsCrafted",
    "SecretsHatched","TimePlayed",
}
task.spawn(function() while sg and sg.Parent do
    if toggles.autoAchieve then
        for _, k in ipairs(ACHIEVE_KEYS) do
            pcall(function() AchievementRE:FireServer(k) end)
            task.wait(0.1)
        end
    end
    task.wait(5)
end end)

-- NO KICK FX — suppress 3D debris + UI reward cards + cash pop-up animations
local fxConn     = nil   -- hooks GameItems.Temp.ChildAdded (colored parts / Crash model)
local promptConn = nil   -- hooks Prompts.Window.ChildAdded (item reward cards)
local popupConn  = nil   -- hooks PlayerGui.PopUps.ChildAdded (CashPopUp / currency animations)
local tempFolder   = workspace:WaitForChild("GameItems"):WaitForChild("Temp")
local promptWindow = lp.PlayerGui:WaitForChild("Prompts"):WaitForChild("Window")
local popupsGui    = lp.PlayerGui:WaitForChild("PopUps")
task.spawn(function() while sg and sg.Parent do
    if toggles.noKickFX then
        if not fxConn then
            fxConn = tempFolder.ChildAdded:Connect(function(c)
                if toggles.noKickFX then pcall(function() c:Destroy() end) end
            end)
            table.insert(conns, fxConn)
            for _, c in ipairs(tempFolder:GetChildren()) do pcall(function() c:Destroy() end) end
        end
        if not promptConn then
            -- reward cards have a Display child; text messages have TextLabel1 — only kill reward cards
            promptConn = promptWindow.ChildAdded:Connect(function(c)
                if toggles.noKickFX and c:FindFirstChild("Display") then
                    pcall(function() c:Destroy() end)
                end
            end)
            table.insert(conns, promptConn)
            for _, c in ipairs(promptWindow:GetChildren()) do
                if c:FindFirstChild("Display") then pcall(function() c:Destroy() end) end
            end
        end
        if not popupConn then
            -- CashPopUp/PowerPopUp clones land in PlayerGui.PopUps — destroy immediately
            popupConn = popupsGui.ChildAdded:Connect(function(c)
                if toggles.noKickFX then pcall(function() c:Destroy() end) end
            end)
            table.insert(conns, popupConn)
            for _, c in ipairs(popupsGui:GetChildren()) do pcall(function() c:Destroy() end) end
        end
    else
        if fxConn    then fxConn:Disconnect();    fxConn    = nil end
        if promptConn then promptConn:Disconnect(); promptConn = nil end
        if popupConn  then popupConn:Disconnect();  popupConn  = nil end
    end
    task.wait(0.2)
end end)

warn("Soccer Training AutoFarm loaded! | RightShift to toggle GUI")

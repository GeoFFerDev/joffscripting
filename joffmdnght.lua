--[[
  JOSEPEDOV V42 — MIDNIGHT CHASERS
  Highway AutoRace exploit | Fluent UI | Ultimate Edition

  ══════════════════════════════════════════════════════════════
  V40 — GAME CONTENT PRELOADER
  ══════════════════════════════════════════════════════════════
  The loading screen now preloads real game assets (180 mesh +
  texture IDs extracted from the place XML) via
  ContentProvider:PreloadAsync() before the UI appears.

  This eliminates the "game paused" / pop-in stutter that occurs
  on slow connections because assets were streaming in during
  active gameplay. The loading bar now reflects actual download
  progress, not arbitrary task.wait() timers.

  Progress phases:
    5  %  — Script init
    5–55%  — ContentProvider:PreloadAsync (CDN asset download)
   55–60%  — RequestStreamAroundAsync (workspace spatial streaming)
    60  %  — Config & world setup
    70  %  — Race engine calibration
    80  %  — UI build
    95  %  — System hooks
   100  %  — Ready

  Camera fix (from V25): tween cancelled before CameraType restore;
  always restores to Custom to avoid camera lock on mobile.

  All V39 features retained unchanged.
  ══════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────
--  SERVICES & PLAYER
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser      = game:GetService("VirtualUser")
local CoreGui          = game:GetService("CoreGui")
local StarterGui       = game:GetService("StarterGui")
local player           = Players.LocalPlayer

-- Force landscape on mobile
pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() player.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

-- GUI mount target
local guiTarget = (type(gethui)=="function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and CoreGui)
    or player:WaitForChild("PlayerGui")

-- Anti-overlap: destroy any previous instances
if guiTarget:FindFirstChild("MC_V22") then 
    guiTarget.MC_V22:Destroy() 
end
if guiTarget:FindFirstChild("MC_V22_Load") then 
    guiTarget.MC_V22_Load:Destroy() 
end

-- ─────────────────────────────────────────────────────────────
--  LOADING SCREEN
-- ─────────────────────────────────────────────────────────────
local loadGui = Instance.new("ScreenGui")
loadGui.Name = "MC_V22_Load"
loadGui.IgnoreGuiInset = true
loadGui.ResetOnSpawn   = false
loadGui.Parent         = guiTarget

local bg = Instance.new("Frame", loadGui)
bg.Size = UDim2.new(1,0,1,0)
bg.BackgroundColor3 = Color3.fromRGB(4,5,9)
bg.BorderSizePixel  = 0

local vig = Instance.new("UIGradient", bg)
vig.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,0,0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6,8,14)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
}
vig.Rotation = 45
vig.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,   0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1,   0.6),
}

local titleLbl = Instance.new("TextLabel", bg)
titleLbl.Size   = UDim2.new(1,0,0,50)
titleLbl.Position = UDim2.new(0,0,0.22,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text  = "MIDNIGHT CHASERS"
titleLbl.TextColor3 = Color3.fromRGB(0,170,120)
titleLbl.Font  = Enum.Font.GothamBlack
titleLbl.TextSize = 38

local subLbl = Instance.new("TextLabel", bg)
subLbl.Size   = UDim2.new(1,0,0,24)
subLbl.Position = UDim2.new(0,0,0.36,0)
subLbl.BackgroundTransparency = 1
subLbl.Text   = "JOSEPEDOV V42  ·  MOTO + STREAM EDITION"
subLbl.TextColor3 = Color3.fromRGB(60,130,100)
subLbl.Font   = Enum.Font.GothamBold
subLbl.TextSize = 14

local routeY = 0.50
local ROUTE_LABELS = {"🚦 QUEUE","◆ CP 27","◆ CP 28","◆ CP 29","🏁 FINISH"}
local routeDots = {}

for i, label in ipairs(ROUTE_LABELS) do
    local xpct = (i-1)/(#ROUTE_LABELS-1)*0.7+0.15
    if i > 1 then
        local prevX = (i-2)/(#ROUTE_LABELS-1)*0.7+0.15
        local lf = Instance.new("Frame",bg)
        lf.Size  = UDim2.new(xpct-prevX,-4,0,2)
        lf.Position = UDim2.new(prevX,6,routeY,4)
        lf.BackgroundColor3 = Color3.fromRGB(20,40,30)
        lf.BorderSizePixel = 0
        routeDots[i] = routeDots[i] or {}
        routeDots[i].line = lf
    end
    
    local dot = Instance.new("Frame",bg)
    dot.Size = UDim2.new(0,10,0,10)
    dot.Position = UDim2.new(xpct,-5,routeY,0)
    dot.BackgroundColor3 = Color3.fromRGB(20,40,30)
    dot.BorderSizePixel = 0
    Instance.new("UICorner",dot).CornerRadius = UDim.new(0,5)
    
    local lbl2 = Instance.new("TextLabel",bg)
    lbl2.Size = UDim2.new(0,80,0,16)
    lbl2.Position = UDim2.new(xpct,-40,routeY,14)
    lbl2.BackgroundTransparency=1
    lbl2.Text = label
    lbl2.TextColor3 = Color3.fromRGB(30,55,40)
    lbl2.Font = Enum.Font.Code
    lbl2.TextSize = 10
    
    routeDots[i] = routeDots[i] or {}
    routeDots[i].dot = dot
    routeDots[i].lbl = lbl2
end

local barTrack = Instance.new("Frame",bg)
barTrack.Size = UDim2.new(0.5,0,0,5)
barTrack.Position = UDim2.new(0.25,0,0.68,0)
barTrack.BackgroundColor3 = Color3.fromRGB(14,18,28)
barTrack.BorderSizePixel = 0
Instance.new("UICorner",barTrack).CornerRadius = UDim.new(0,3)

local barFill = Instance.new("Frame",barTrack)
barFill.Size = UDim2.new(0,0,1,0)
barFill.BackgroundColor3 = Color3.fromRGB(0,170,120)
barFill.BorderSizePixel = 0
Instance.new("UICorner",barFill).CornerRadius = UDim.new(0,3)

local barTxt = Instance.new("TextLabel",bg)
barTxt.Size = UDim2.new(1,0,0,18)
barTxt.Position = UDim2.new(0,0,0.72,0)
barTxt.BackgroundTransparency=1
barTxt.TextColor3 = Color3.fromRGB(40,90,65)
barTxt.Font = Enum.Font.Code
barTxt.TextSize = 12

local speedLines = {}
math.randomseed(42)
for i=1,12 do
    local ln = Instance.new("Frame",bg)
    local yp = math.random(10,90)/100
    local w  = math.random(60,160)/1000
    local xp = math.random(0,80)/100
    ln.Size = UDim2.new(w,0,0,1)
    ln.Position = UDim2.new(xp,0,yp,0)
    ln.BackgroundColor3 = Color3.fromRGB(0,170,120)
    ln.BorderSizePixel = 0
    ln.BackgroundTransparency = 0.6+math.random()*0.3
    speedLines[i] = {frame=ln, speed=math.random(40,120)/100, x=xp, w=w}
end

local loadAnimConn = RunService.Heartbeat:Connect(function(dt)
    for _,sl in ipairs(speedLines) do
        sl.x = sl.x + sl.speed*dt*0.15
        if sl.x>1 then sl.x=-sl.w end
        sl.frame.Position = UDim2.new(sl.x,0,sl.frame.Position.Y.Scale,0)
    end
end)

local cam = Workspace.CurrentCamera
local prevCamType = cam.CameraType
cam.CameraType = Enum.CameraType.Scriptable
local CAM_ROUTE = {
    {CFrame.lookAt(Vector3.new(3180,75,1100),  Vector3.new(2900,0,700))},
    {CFrame.lookAt(Vector3.new(2900,40,600),   Vector3.new(2513,0,411))},
    {CFrame.lookAt(Vector3.new(2650,55,480),   Vector3.new(2981,0,537))},
}
cam.CFrame = CAM_ROUTE[1][1]

local function SetProg(pct, msg, activeDot)
    TweenService:Create(barFill, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Size=UDim2.new(pct/100,0,1,0)}):Play()
    barTxt.Text = string.format("  %d%%  —  %s", math.floor(pct), msg)
    
    local ci = math.max(1,math.min(#CAM_ROUTE, math.round(pct/100*#CAM_ROUTE+0.5)))
    TweenService:Create(cam, TweenInfo.new(1.2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        {CFrame=CAM_ROUTE[ci][1]}):Play()
        
    for i,d in ipairs(routeDots) do
        local on = activeDot and i<=activeDot
        local col = on and Color3.fromRGB(0,170,120) or Color3.fromRGB(20,40,30)
        local tc  = on and Color3.fromRGB(0,200,140) or Color3.fromRGB(30,55,40)
        if d.dot then 
            TweenService:Create(d.dot,TweenInfo.new(0.25),{BackgroundColor3=col}):Play() 
        end
        if d.lbl then 
            d.lbl.TextColor3 = tc 
        end
        if d.line then 
            TweenService:Create(d.line,TweenInfo.new(0.25),{BackgroundColor3=col}):Play() 
        end
    end
end

-- ─────────────────────────────────────────────────────────────
--  CONFIG & STATE
-- ─────────────────────────────────────────────────────────────
SetProg(5, "Initialising...", 1)
task.wait(0.1)

-- ─────────────────────────────────────────────────────────────
--  GAME CONTENT PRELOADER  (V40)
-- ─────────────────────────────────────────────────────────────
--  Preloads 180 mesh + texture IDs from the place XML via
--  ContentProvider:PreloadAsync(). This runs before any gameplay
--  starts so assets don't stream in mid-race on slow connections.
--
--  ContentProvider:PreloadAsync(assets, callback) fires the
--  callback for each asset as it finishes. We use that to drive
--  the loading bar from 5% → 55% with real download progress.
-- ─────────────────────────────────────────────────────────────
do
    local ContentProvider = game:GetService("ContentProvider")

    local GAME_ASSETS = {
    "rbxassetid://14596824377",
    "rbxassetid://15694239990",
    "rbxassetid://14916031176",
    "rbxassetid://14916031762",
    "rbxassetid://14916031498",
    "rbxassetid://14573638321",
    "rbxassetid://14573641912",
    "rbxassetid://14573638882",
    "rbxassetid://3557627978",
    "rbxassetid://15179434724",
    "rbxassetid://7598115762",
    "rbxassetid://17363357783",
    "rbxassetid://17363363505",
    "rbxassetid://17363358725",
    "rbxassetid://17363364909",
    "rbxassetid://17363362508",
    "rbxassetid://17363359610",
    "rbxassetid://15612489676",
    "rbxassetid://15612489007",
    "rbxassetid://15612486885",
    "rbxassetid://15618247443",
    "rbxassetid://15618246166",
    "rbxassetid://15618248516",
    "rbxassetid://15619659905",
    "rbxassetid://15619658757",
    "rbxassetid://15619661379",
    "rbxassetid://15619661930",
    "rbxassetid://15619660554",
    "rbxassetid://14321936910",
    "rbxassetid://14321895433",
    "rbxassetid://17532595840",
    "rbxassetid://14322193920",
    "rbxassetid://17532707928",
    "rbxassetid://17532696203",
    "rbxassetid://9032941519",
    "rbxassetid://17532733590",
    "rbxassetid://17532606253",
    "rbxassetid://14322027695",
    "rbxassetid://17532702579",
    "rbxassetid://14322159481",
    "rbxassetid://17532725538",
    "rbxassetid://14322039547",
    "rbxassetid://17532664747",
    "rbxassetid://14322051218",
    "rbxassetid://17532684382",
    "rbxassetid://9032942634",
    "rbxassetid://17532626845",
    "rbxassetid://14322168910",
    "rbxassetid://17532125441",
    "rbxassetid://14322007262",
    "rbxassetid://17532654358",
    "rbxassetid://9032943009",
    "rbxassetid://17532638483",
    "rbxassetid://14322125716",
    "rbxassetid://17532689859",
    "rbxassetid://14925232957",
    "rbxassetid://15617404429",
    "rbxassetid://15617560642",
    "rbxassetid://15617510215",
    "rbxassetid://15617468676",
    "rbxassetid://15617507385",
    "rbxassetid://15617505891",
    "rbxassetid://15617496872",
    "rbxassetid://15617508688",
    "rbxassetid://15617526680",
    "rbxassetid://15617522136",
    "rbxassetid://15617525633",
    "rbxassetid://15617524779",
    "rbxassetid://15617539348",
    "rbxassetid://15617534625",
    "rbxassetid://15617537624",
    "rbxassetid://15617538473",
    "rbxassetid://16312766199",
    "rbxassetid://15617545616",
    "rbxassetid://15617544384",
    "rbxassetid://15617543339",
    "rbxassetid://15617541164",
    "rbxassetid://14957237522",
    "rbxassetid://14957237982",
    "rbxassetid://14957238172",
    "rbxassetid://14957237399",
    "rbxassetid://9476531852",
    "rbxassetid://15694239989",
    "rbxassetid://14618309042",
    "rbxassetid://14618307636",
    "rbxassetid://15694240604",
    "rbxassetid://15694240576",
    "rbxassetid://15694240587",
    "rbxassetid://15694240578",
    "rbxassetid://15694240571",
    "rbxassetid://15694240594",
    "rbxassetid://15388429560",
    "rbxassetid://15393966002",
    "rbxassetid://15393967431",
    "rbxassetid://15393968021",
    "rbxassetid://15393967076",
    "rbxassetid://15393968246",
    "rbxassetid://15393966261",
    "rbxassetid://15393970067",
    "rbxassetid://15393969220",
    "rbxassetid://15449028050",
    "rbxassetid://15449007806",
    "rbxassetid://15653762686",
    "rbxassetid://15653759179",
    "rbxassetid://15653753678",
    "rbxassetid://8396779051",
    "rbxassetid://8396780191",
    "rbxassetid://8396780453",
    "rbxassetid://8396778565",
    "rbxassetid://8396779426",
    "rbxassetid://8396779674",
    "rbxassetid://120668255183486",
    "rbxassetid://11985298197",
    "rbxassetid://14084476116",
    "rbxassetid://8709286869",
    "rbxassetid://8709287168",
    "rbxassetid://8709287027",
    "rbxassetid://10491935094",
    "rbxassetid://10491936526",
    "rbxassetid://8709291137",
    "rbxassetid://14729082457",
    "rbxassetid://17363388470",
    "rbxassetid://17363388781",
    "rbxassetid://17363389661",
    "rbxassetid://17363390479",
    "rbxassetid://17363381009",
    "rbxassetid://17363384221",
    "rbxassetid://17363385928",
    "rbxassetid://17363386673",
    "rbxassetid://17362258044",
    "rbxassetid://17362018483",
    "rbxassetid://17043030320",
    "rbxassetid://1847258023",
    "rbxassetid://17532034425",
    "rbxassetid://15082168287",
    "rbxassetid://15312718183",
    "rbxassetid://77050110569160",
    "rbxassetid://104599847429296",
    "rbxassetid://100152166184167",
    "rbxassetid://119787688051772",
    "rbxassetid://79445842296116",
    "rbxassetid://108745456784727",
    "rbxassetid://82787593992844",
    "rbxassetid://138377290276713",
    "rbxassetid://128118509350496",
    "rbxassetid://77998940993647",
    "rbxassetid://18136917681",
    "rbxassetid://94273197515900",
    "rbxassetid://113063094688016",
    "rbxassetid://16919833005",
    "rbxassetid://96049226272732",
    "rbxassetid://14925227270",
    "rbxassetid://16451871194",
    "rbxassetid://16300409953",
    "rbxassetid://16451859860",
    "rbxassetid://16451861018",
    "rbxassetid://17650728678",
    "rbxassetid://17650714317",
    "rbxassetid://14957237811",
    "rbxassetid://17096710296",
    "rbxassetid://17096647872",
    "rbxassetid://15432308718",
    "rbxassetid://15432258970",
    "rbxassetid://107446590373859",
    "rbxassetid://15449007949",
    "rbxassetid://75828128041115",
    "rbxassetid://1215682739",
    "rbxassetid://96634592210750",
    "rbxassetid://82152734060733",
    "rbxassetid://14912709455",
    "rbxassetid://14912709288",
    "rbxassetid://14912985134",
    "rbxassetid://110875201838207",
    "rbxassetid://128440026726435",
    "rbxassetid://73224221203377",
    "rbxassetid://105497871223784",
    "rbxassetid://90650963888802",
    "rbxassetid://85145094489827",
    "rbxassetid://106260443677301",
    "rbxassetid://129299302881069"
}

    -- Build Instance wrappers — ContentProvider needs Instance or string
    -- For string asset IDs the simplest wrapper is a Sound (audio) or
    -- a MeshPart for mesh IDs; but the cleanest cross-type approach is
    -- just passing the string IDs directly — PreloadAsync accepts strings.
    local total   = #GAME_ASSETS
    local loaded  = 0
    local BAR_MIN = 5    -- bar % when preload starts
    local BAR_MAX = 55   -- bar % when preload ends

    SetProg(BAR_MIN, string.format("Preloading game assets... 0/%d", total), 1)

    -- PreloadAsync is blocking and fires callback per asset.
    -- Wrap in pcall so a failed asset doesn't halt loading.
    pcall(function()
        ContentProvider:PreloadAsync(GAME_ASSETS, function(assetId, status)
            loaded = loaded + 1
            local pct = BAR_MIN + (loaded / total) * (BAR_MAX - BAR_MIN)
            local statusStr = (status == Enum.AssetFetchStatus.Success)
                and string.format("Loaded %d/%d", loaded, total)
                or  string.format("Loaded %d/%d  (%s)", loaded, total, tostring(status))
            -- Update bar text and fill — use the same TweenService path SetProg uses
            TweenService:Create(barFill,
                TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(pct/100, 0, 1, 0)}):Play()
            barTxt.Text = string.format("  %.0f%%  —  %s", pct, statusStr)
            -- Advance camera route proportionally
            local ci = math.max(1, math.min(#CAM_ROUTE,
                math.round(pct/100 * #CAM_ROUTE + 0.5)))
            TweenService:Create(cam,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {CFrame = CAM_ROUTE[ci][1]}):Play()
        end)
    end)

    SetProg(55, string.format("Assets ready!  %d preloaded", loaded), 1)
    task.wait(0.2)

    -- ── WORKSPACE SPATIAL STREAMING (V42) ──────────────────────
    -- ContentProvider:PreloadAsync downloads CDN binary data but
    -- does NOT stream workspace Parts/Models (StreamingEnabled).
    -- player:RequestStreamAroundAsync(pos) asks the server to
    -- send workspace content near each position to this client.
    -- We request 16 positions covering the full race route so
    -- the map is pre-streamed before gameplay starts.
    -- Each call yields until the server confirms the area is sent.
    local STREAM_POSITIONS = {
        -- Race route: extracted from place XML (X:2464-3762)
        Vector3.new(2464,  5, 583),
        Vector3.new(2575,  5, 469),
        Vector3.new(2663,  5, 389),
        Vector3.new(2771,  5, 501),
        Vector3.new(2852,  5, 566),
        Vector3.new(2900,  5, 700),   -- race start area
        Vector3.new(2975,  5, 674),
        Vector3.new(3087,  5, 636),
        Vector3.new(3190,  5, 637),
        Vector3.new(3260,  12,1016),  -- queue position
        Vector3.new(3276,  5, 847),
        Vector3.new(3326,  5, 988),
        Vector3.new(3414,  5, 742),
        Vector3.new(3474,  5, 715),
        Vector3.new(3485,  5, 622),
        Vector3.new(3599,  5, 648),
    }
    local streamTotal = #STREAM_POSITIONS
    for si, spos in ipairs(STREAM_POSITIONS) do
        local spct = 55 + (si / streamTotal) * 5   -- drives bar 55% → 60%
        barTxt.Text = string.format(
            "  %.0f%%  —  Streaming map area %d/%d...", spct, si, streamTotal)
        TweenService:Create(barFill,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(spct/100, 0, 1, 0)}):Play()
        pcall(function()
            player:RequestStreamAroundAsync(spos, 10)  -- 10s timeout
        end)
    end

    SetProg(60, "Map streaming complete!", 1)
    task.wait(0.15)
end

-- ─────────────────────────────────────────────────────────────
--  CONFIG & STATE  (continues from 55%)
-- ─────────────────────────────────────────────────────────────
SetProg(60, "Loading Configurations...", 1)
task.wait(0.2)

local Config = {
    AutoRace       = false,
    SpeedFarm      = false,
    FarmSpeed      = 250, -- NEW: Separate Speed for Auto-Farm
    AntiAFK        = false,
    GhostMode      = false,
    SpeedHack      = false,
    InfNitro       = false,
    TrafficBlocked = false,
    FPS_Boosted    = false,
    FullBright     = false,
    Acceleration   = 3.0,
    MaxSpeed       = 320,
    AutoRaceSpeed  = 350,
    Deadzone       = 0.1,
    TireGrip       = false,
    -- Motorcycle features
    MotoSpeedHack  = false,  -- horizontal-only boost (no flip)
    MotoMaxSpeed   = 200,    -- top speed for moto boost (st/s)
    MotoAccel      = 2.0,    -- boost increment per frame
    NoCrashDeath   = false,  -- keep health full, prevent ragdoll on collision
}
local AR_SPEED_CAP = 600

local OriginalTech    = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoor = Lighting.OutdoorAmbient
local OriginalClock   = Lighting.ClockTime

local currentSeat    = nil
local currentCar     = nil
local disabledCar    = nil
local AR_STATE       = "IDLE"
local raceThread     = nil
local raceOwnsStatus = false
local lastModsState  = false

local QUEUE_POS = Vector3.new(3260.5, 12, 1015.7)
local FARM_POS  = Vector3.new(0, 10000, 0)

-- ─────────────────────────────────────────────────────────────
--  SPEED FARM INFINITE ROAD
-- ─────────────────────────────────────────────────────────────
SetProg(65, "Building Infinite Sky Road...", 2)
task.wait(0.3)

local farmRoad = Instance.new("Part")
farmRoad.Name = "Joff_SpeedFarmRoad"
farmRoad.Size = Vector3.new(2000, 5, 2000)
farmRoad.Anchored = true
farmRoad.CanCollide = true
farmRoad.Transparency = 0.5
farmRoad.Color = Color3.fromRGB(30, 30, 35)
farmRoad.Material = Enum.Material.SmoothPlastic
farmRoad.Position = Vector3.new(0, 9995, 0)
farmRoad.Parent = nil

-- ─────────────────────────────────────────────────────────────
--  ANTI-AFK
-- ─────────────────────────────────────────────────────────────
player.Idled:Connect(function()
    if Config.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- ─────────────────────────────────────────────────────────────
--  WORLD & PERFORMANCE HELPERS (RESTORED IN V39)
-- ─────────────────────────────────────────────────────────────
SetProg(70, "Restoring World Modifiers...", 3)
task.wait(0.2)

local function ToggleTraffic()
    Config.TrafficBlocked = not Config.TrafficBlocked
    local ev = ReplicatedStorage:FindFirstChild("CreateNPCVehicle")
    if Config.TrafficBlocked then
        pcall(function()
            if ev and getconnections then 
                for _,c in pairs(getconnections(ev.OnClientEvent)) do c:Disable() end 
            end
        end)
        for _,n in ipairs({"NPCVehicles","Traffic","Vehicles"}) do
            local f = Workspace:FindFirstChild(n)
            if f then f:ClearAllChildren() end
        end
    else
        pcall(function()
            if ev and getconnections then 
                for _,c in pairs(getconnections(ev.OnClientEvent)) do c:Enable() end 
            end
        end)
    end
    return Config.TrafficBlocked
end

local function ToggleFPSBoost()
    Config.FPS_Boosted = not Config.FPS_Boosted
    pcall(function()
        if Config.FPS_Boosted then
            Lighting.GlobalShadows = false
            if sethiddenproperty then 
                pcall(function() sethiddenproperty(Lighting,"Technology",Enum.Technology.Voxel) end)
            end
            for _,v in ipairs(workspace:GetDescendants()) do 
                pcall(function()
                    if v:IsA("BasePart") then v.CastShadow=false
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false end
                end) 
            end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then 
                pcall(function() sethiddenproperty(Lighting,"Technology",OriginalTech) end)
            end
            for _,v in ipairs(workspace:GetDescendants()) do 
                pcall(function()
                    if v:IsA("BasePart") then v.CastShadow=true
                    elseif v:IsA("Trail") or v:IsA("ParticleEmitter") then v.Enabled=true end
                end) 
            end
        end
    end)
    return Config.FPS_Boosted
end

local function ToggleFullBright()
    Config.FullBright = not Config.FullBright
    if not Config.FullBright then
        Lighting.Ambient = OriginalAmbient
        Lighting.OutdoorAmbient = OriginalOutdoor
        Lighting.ClockTime = OriginalClock
    end
    return Config.FullBright
end

-- ─────────────────────────────────────────────────────────────
--  PHYSICS & COLLISIONS
-- ─────────────────────────────────────────────────────────────
local function ManagePhysicsMods(car)
    if not car then return end
    local root = car.PrimaryPart or car:FindFirstChild("DriveSeat", true) or currentSeat
    if not root then return end

    local vf = root:FindFirstChild("Joff_PhysicsMod")
    local att = root:FindFirstChild("Joff_Att")
    
    if Config.TireGrip then
        if not att then
            att = Instance.new("Attachment", root)
            att.Name = "Joff_Att"
        end
        if not vf then
            vf = Instance.new("VectorForce", root)
            vf.Name = "Joff_PhysicsMod"
            vf.Attachment0 = att
            vf.RelativeTo = Enum.ActuatorRelativeTo.World
        end
        
        local mass = 0
        for _, p in ipairs(car:GetDescendants()) do
            if p:IsA("BasePart") and not p.Massless then
                mass = mass + p.Mass
            end
        end
        
        local g = Workspace.Gravity
        vf.Force = Vector3.new(0, -mass * g * 2.0, 0)
    else
        if vf then vf:Destroy() end
        if att then att:Destroy() end
    end
end

local function DisableCollisions(car)
    if not car then return end
    disabledCar = car
    for _,p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then 
            p.CanCollide = false 
        end
    end
    local ch = player.Character
    if ch then
        for _,p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then 
                p.CanCollide = false 
            end
        end
    end
end

local function RestoreCollisions()
    local car = disabledCar or currentCar
    if not car then return end
    for _,p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then 
            p.CanCollide = true 
        end
    end
    local ch = player.Character
    if ch then
        for _,p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then 
                p.CanCollide = true 
            end
        end
    end
    disabledCar = nil
end

-- ─────────────────────────────────────────────────────────────
--  MOTORCYCLE DETECTION
-- ─────────────────────────────────────────────────────────────
--  Motorcycles confirmed in place XML (Tarvo SVR, Duc Desedomeci,
--  Charlette R6, etc.) all use the same A-Chassis VehicleSeat as
--  cars. Detection is purely by model name keywords.
--  SpeedHack boosts along the horizontal XZ plane — NOT the full
--  3D LookVector. When a bike is leaning the LookVector tilts
--  downward; boosting along it pushes the front wheel into the
--  ground and flips the bike. XZ projection avoids this entirely.
local MOTO_KEYS = {
    "bike","moto","cycle","svr","duc","cbr","cbf","cb5","cb6","cb7",
    "r1","r6","r3","r25","gsx","ninja","z800","z900","z1000",
    "mt07","mt09","s1000","triumph","harley","scrambl","chopper",
    "tarvo","charlette","desedomeci","aprilia","ktm","husqvarna",
}
local function IsMoto(vehicle)
    if not vehicle then return false end
    local n = vehicle.Name:lower()
    for _, kw in ipairs(MOTO_KEYS) do
        if n:find(kw, 1, true) then return true end
    end
    return false
end

local function FlipCar()
    local c = currentCar
    if c and c.PrimaryPart then
        local cf = c:GetPivot()
        local pos = cf.Position
        local look = cf.LookVector
        local flatCFrame = CFrame.lookAt(pos + Vector3.new(0, 5, 0), pos + Vector3.new(look.X, 0, look.Z))
        c:PivotTo(flatCFrame)
        c.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
        c.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
    end
end

-- ─────────────────────────────────────────────────────────────
--  RACE HELPERS
-- ─────────────────────────────────────────────────────────────
SetProg(75, "Calibrating Race Route Logic...", 4)
task.wait(0.3)

local function FindPlayerRaceFolder()
    local racesWS = Workspace:FindFirstChild("Races")
    if not racesWS then return nil,nil end
    for _,raceN in ipairs(racesWS:GetChildren()) do
        local container = raceN:FindFirstChild("Races")
        if container then
            for _,uuidF in ipairs(container:GetChildren()) do
                local racers = uuidF:FindFirstChild("Racers")
                if racers and racers:FindFirstChild(player.Name) then
                    return uuidF, uuidF:FindFirstChild("State")
                end
            end
        end
    end
    return nil,nil
end

local function FindNextCP(raceFolder, clearedSet, skipIdx)
    local cpVal = raceFolder:FindFirstChild("Checkpoints")
    if not cpVal then return nil,nil end
    local best, bestIdx = nil, math.huge
    local fallbackPart = nil
    
    for _,child in ipairs(cpVal:GetChildren()) do
        if child:IsA("BasePart") then
            local idx = tonumber(child.Name)
            if idx then
                if not (clearedSet and clearedSet[idx]) and idx ~= skipIdx then
                    if idx < bestIdx then 
                        best, bestIdx = child, idx 
                    end
                end
            else
                if not (clearedSet and clearedSet[child.Name]) and child.Name ~= skipIdx then
                    fallbackPart = child
                end
            end
        end
    end
    if best then return best, bestIdx end
    if fallbackPart then return fallbackPart, fallbackPart.Name end
    return nil, nil
end

local _statusLbl = nil
local function SetStatus(text, r, g, b)
    if _statusLbl then
        _statusLbl.Text = "  " .. text
        _statusLbl.TextColor3 = (r and Color3.fromRGB(r,g,b)) or Color3.fromRGB(150,150,150)
    end
end

-- ─────────────────────────────────────────────────────────────
--  AUTO-RACE ENGINE
-- ─────────────────────────────────────────────────────────────
SetProg(80, "Hooking Auto-Queue Engine...", 4)
task.wait(0.3)

local GATE_INSIDE  = 0.10 
local TRIGGER_DIST = 25   

local function DoRaceLoop(uuidFolder)
    raceOwnsStatus = true
    DisableCollisions(currentCar)

    local clearedSet = {}
    local skipIdx    = nil
    local lastDirXZ  = nil 
    local rcParams = RaycastParams.new()
    rcParams.FilterType = Enum.RaycastFilterType.Exclude

    while Config.AutoRace and AR_STATE == "RACING" do
        local arSpeed   = math.clamp(Config.AutoRaceSpeed, 50, AR_SPEED_CAP)
        local clearDist = math.max(28, arSpeed * 0.07)
        local gatePart, cpIdx
        local waitForCP = tick() + 45 
        
        repeat
            if not uuidFolder or not uuidFolder:IsDescendantOf(Workspace) then break end
            local stateV = uuidFolder:FindFirstChild("State")
            if stateV and stateV.Value ~= "Racing" then break end

            gatePart, cpIdx = FindNextCP(uuidFolder, clearedSet, skipIdx)
            
            if not gatePart then 
                if currentCar then
                    local tempRoot = currentCar.PrimaryPart or currentSeat
                    if tempRoot then
                        if lastDirXZ then
                            SetStatus("📡 Map Loading... Coasting ahead", 255, 180, 50)
                            tempRoot.AssemblyLinearVelocity = Vector3.new(lastDirXZ.X * arSpeed, 0, lastDirXZ.Z * arSpeed)
                        else
                            SetStatus("⏳ Waiting for first checkpoint...", 255, 152, 0)
                            tempRoot.AssemblyLinearVelocity = Vector3.zero
                        end
                        tempRoot.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                RunService.Heartbeat:Wait()
            end
        until gatePart or tick() > waitForCP or not Config.AutoRace or AR_STATE ~= "RACING"

        if not gatePart then
            SetStatus("🏁 Race Finished! Returning to queue...", 0, 220, 130)
            task.wait(1.5) 
            RestoreCollisions()
            raceOwnsStatus = false
            
            local ch2 = player.Character
            if ch2 and ch2:FindFirstChild("Humanoid") then
                local seat2 = ch2.Humanoid.SeatPart
                if seat2 and seat2:IsA("VehicleSeat") then
                    local car2  = seat2.Parent
                    local root2 = car2.PrimaryPart or seat2
                    if root2 then
                        car2:PivotTo(CFrame.new(QUEUE_POS))
                        task.wait(0.1)
                        root2.AssemblyLinearVelocity  = Vector3.zero
                        root2.AssemblyAngularVelocity = Vector3.zero
                        SetStatus("⏎ Back at queue — waiting for start!", 0, 190, 255)
                    end
                end
            end
            if Config.AutoRace then 
                AR_STATE = "QUEUING" 
            end
            break
        end

        skipIdx = nil
        local cpCleared = false
        local cpConn    = nil
        local cpParent  = gatePart.Parent
        if cpParent then
            cpConn = cpParent.ChildRemoved:Connect(function(removed)
                if removed == gatePart then 
                    cpCleared = true 
                end
            end)
        end

        local gateTargetY = gatePart.Position.Y + (gatePart.Size.Y * GATE_INSIDE)
        local targetPos = Vector3.new(gatePart.Position.X, gateTargetY, gatePart.Position.Z)
        local flyLimit  = tick() + 30

        while tick() < flyLimit do
            if not Config.AutoRace or AR_STATE ~= "RACING" then break end
            if cpCleared then break end
            if not gatePart.Parent then cpCleared = true; break end

            local car  = currentCar
            if not car then task.wait(0.05); continue end
            local root = car.PrimaryPart or currentSeat
            if not root then task.wait(0.05); continue end

            local ch = player.Character
            rcParams.FilterDescendantsInstances = ch and {car, ch} or {car}

            local myPos = root.Position
            local myXZ  = Vector3.new(myPos.X, 0, myPos.Z)
            local targetXZ = Vector3.new(targetPos.X, 0, targetPos.Z)
            local distXZ = (targetXZ - myXZ).Magnitude

            if distXZ > 15 then 
                lastDirXZ = (targetXZ - myXZ).Unit 
            end

            if distXZ <= TRIGGER_DIST then
                pcall(function()
                    if firetouchinterest then
                        firetouchinterest(root, gatePart, 0)
                        task.wait()
                        firetouchinterest(root, gatePart, 1)
                    end
                end)
                cpCleared = true
                break
            end

            if distXZ <= clearDist then 
                cpCleared = true
                break 
            end

            local dir3D = (targetPos - myPos).Unit
            local desiredVelX = dir3D.X * arSpeed
            local desiredVelY = dir3D.Y * arSpeed
            local desiredVelZ = dir3D.Z * arSpeed
            
            local yErr = targetPos.Y - myPos.Y
            desiredVelY = desiredVelY + (yErr * 1.5)

            if distXZ > 150 then
                local dirXZ = (targetXZ - myXZ).Unit
                local aheadPos = myPos + (dirXZ * 40) + Vector3.new(0, 50, 0)
                local floorRay = Workspace:Raycast(aheadPos, Vector3.new(0, -150, 0), rcParams)
                if floorRay then
                    local roadY = floorRay.Position.Y
                    local safeY = roadY + 8
                    if myPos.Y < safeY then
                        local pushUp = (safeY - myPos.Y) * 5
                        desiredVelY = math.max(desiredVelY, pushUp)
                    end
                end
            end

            root.AssemblyLinearVelocity = Vector3.new(desiredVelX, desiredVelY, desiredVelZ)
            root.AssemblyAngularVelocity = Vector3.zero

            SetStatus(string.format("→ CP #%s  %.0f studs  Y%.1f▶%.1f", tostring(cpIdx), distXZ, myPos.Y, targetPos.Y), 0, 190, 255)
            task.wait()
        end

        if cpConn then pcall(function() cpConn:Disconnect() end) end
        if not Config.AutoRace or AR_STATE ~= "RACING" then break end

        if cpCleared then
            clearedSet[cpIdx] = true
            SetStatus(string.format("✓ CP #%s cleared  Y=%.1f", tostring(cpIdx), gateTargetY), 0, 230, 100)
            task.wait(0.2)
        else
            SetStatus(string.format("CP #%s timed out — skipping", tostring(cpIdx)), 255, 150, 0)
            skipIdx = cpIdx
            task.wait(0.2)
        end
    end

    RestoreCollisions()
    raceOwnsStatus = false
    if Config.AutoRace and AR_STATE == "RACING" then 
        AR_STATE = "QUEUING" 
    end
    raceThread = nil
end

-- ─────────────────────────────────────────────────────────────
--  UI BUILDER
-- ─────────────────────────────────────────────────────────────
SetProg(85, "Assembling Fluent UI...", 5)
task.wait(0.2)

local Theme = {
    Background = Color3.fromRGB(24, 24, 28),
    Sidebar    = Color3.fromRGB(18, 18, 22),
    Accent     = Color3.fromRGB(0, 170, 120),
    AccentDim  = Color3.fromRGB(0, 110, 78),
    Text       = Color3.fromRGB(240, 240, 240),
    SubText    = Color3.fromRGB(150, 150, 150),
    Button     = Color3.fromRGB(35, 35, 40),
    Stroke     = Color3.fromRGB(60, 60, 65),
    Red        = Color3.fromRGB(215, 55, 55),
    Orange     = Color3.fromRGB(255, 152, 0),
    Green      = Color3.fromRGB(0, 210, 100),
}

local ScreenGui = Instance.new("ScreenGui", guiTarget)
ScreenGui.Name          = "MC_V22"
ScreenGui.ResetOnSpawn  = false
ScreenGui.IgnoreGuiInset = true

local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size   = UDim2.new(0,45,0,45)
ToggleIcon.Position = UDim2.new(0.5,-22,0.05,0)
ToggleIcon.BackgroundColor3 = Theme.Background
ToggleIcon.BackgroundTransparency = 0.1
ToggleIcon.Text   = "🏁"
ToggleIcon.TextSize = 22
ToggleIcon.Visible = false

local ToggleIconCorner = Instance.new("UICorner",ToggleIcon)
ToggleIconCorner.CornerRadius = UDim.new(1,0)

local IconStroke = Instance.new("UIStroke",ToggleIcon)
IconStroke.Color = Theme.Accent
IconStroke.Thickness = 2

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size   = UDim2.new(0,420,0,280)
MainFrame.Position = UDim2.new(0.5,-210,0.5,-140)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BackgroundTransparency = 0.08
MainFrame.Active = true

local MainFrameCorner = Instance.new("UICorner",MainFrame)
MainFrameCorner.CornerRadius = UDim.new(0,10)

local MainStroke = Instance.new("UIStroke",MainFrame)
MainStroke.Color = Theme.Stroke
MainStroke.Transparency = 0.4

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1,0,0,32)
TopBar.BackgroundTransparency = 1

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size   = UDim2.new(0.6,0,1,0)
TitleLbl.Position = UDim2.new(0,14,0,0)
TitleLbl.Text   = "🏁  MIDNIGHT CHASERS  V42"
TitleLbl.Font   = Enum.Font.GothamBold
TitleLbl.TextColor3 = Theme.Accent
TitleLbl.TextSize = 12
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.BackgroundTransparency = 1

local Sep = Instance.new("Frame",MainFrame)
Sep.Size = UDim2.new(1,-20,0,1)
Sep.Position = UDim2.new(0,10,0,32)
Sep.BackgroundColor3 = Theme.Stroke
Sep.BorderSizePixel = 0

local function AddCtrl(text, pos, color, cb)
    local b = Instance.new("TextButton", TopBar)
    b.Size   = UDim2.new(0,28,0,22)
    b.Position = pos
    b.BackgroundTransparency = 1
    b.Text = text
    b.TextColor3 = color
    b.Font   = Enum.Font.GothamBold
    b.TextSize = 12
    b.MouseButton1Click:Connect(cb)
    return b
end

AddCtrl("✕", UDim2.new(1,-32,0.5,-11), Color3.fromRGB(255,80,80), function() 
    ScreenGui:Destroy() 
end)

AddCtrl("—", UDim2.new(1,-62,0.5,-11), Theme.SubText, function() 
    MainFrame.Visible = false
    ToggleIcon.Visible = true 
end)

ToggleIcon.MouseButton1Click:Connect(function() 
    MainFrame.Visible = true
    ToggleIcon.Visible = false 
end)

local function EnableDrag(obj, handle)
    local drag, ipt, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag = true
            start = i.Position
            startPos = obj.Position
            i.Changed:Connect(function() 
                if i.UserInputState==Enum.UserInputState.End then 
                    drag = false 
                end 
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position - start
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end
EnableDrag(MainFrame, TopBar)
EnableDrag(ToggleIcon, ToggleIcon)

local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size   = UDim2.new(0,108,1,-33)
Sidebar.Position = UDim2.new(0,0,0,33)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.4
Sidebar.BorderSizePixel = 0

local SidebarCorner = Instance.new("UICorner",Sidebar)
SidebarCorner.CornerRadius = UDim.new(0,10)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0,5)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local SidebarPadding = Instance.new("UIPadding",Sidebar)
SidebarPadding.PaddingTop = UDim.new(0,10)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size   = UDim2.new(1,-118,1,-38)
ContentArea.Position = UDim2.new(0,113,0,38)
ContentArea.BackgroundTransparency = 1

local AllTabs    = {}
local AllTabBtns = {}

local function CreateTab(name, icon)
    local tf = Instance.new("ScrollingFrame", ContentArea)
    tf.Size = UDim2.new(1,0,1,0)
    tf.BackgroundTransparency = 1
    tf.ScrollBarThickness = 2
    tf.ScrollBarImageColor3 = Theme.AccentDim
    tf.Visible = false
    tf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tf.CanvasSize = UDim2.new(0,0,0,0)
    tf.BorderSizePixel = 0
    
    local lay = Instance.new("UIListLayout",tf)
    lay.Padding = UDim.new(0,7)
    
    local pad = Instance.new("UIPadding",tf)
    pad.PaddingTop = UDim.new(0,6)

    local tb = Instance.new("TextButton", Sidebar)
    tb.Size   = UDim2.new(0.92,0,0,30)
    tb.BackgroundColor3 = Theme.Accent
    tb.BackgroundTransparency = 1
    tb.Text   = "  "..icon.." "..name
    tb.TextColor3 = Theme.SubText
    tb.Font   = Enum.Font.GothamMedium
    tb.TextSize = 12
    tb.TextXAlignment = Enum.TextXAlignment.Left
    
    local tbCorner = Instance.new("UICorner",tb)
    tbCorner.CornerRadius = UDim.new(0,6)

    local ind = Instance.new("Frame", tb)
    ind.Size  = UDim2.new(0,3,0.6,0)
    ind.Position = UDim2.new(0,2,0.2,0)
    ind.BackgroundColor3 = Theme.Accent
    ind.Visible = false
    
    local indCorner = Instance.new("UICorner",ind)
    indCorner.CornerRadius = UDim.new(1,0)

    tb.MouseButton1Click:Connect(function()
        for _,t in pairs(AllTabs) do 
            t.Frame.Visible = false 
        end
        for _,b in pairs(AllTabBtns) do 
            b.Btn.BackgroundTransparency = 1
            b.Btn.TextColor3 = Theme.SubText
            b.Ind.Visible = false 
        end
        tf.Visible = true
        tb.BackgroundTransparency = 0.82
        tb.TextColor3 = Theme.Text
        ind.Visible = true
    end)
    
    table.insert(AllTabs, {Frame = tf})
    table.insert(AllTabBtns, {Btn = tb, Ind = ind})
    return tf
end

local function Section(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size   = UDim2.new(0.98,0,0,18)
    lbl.BackgroundTransparency = 1
    lbl.Text   = text
    lbl.TextColor3 = Theme.AccentDim
    lbl.Font   = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function AddButton(parent, text, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size = UDim2.new(0.98,0,0,35)
    btn.BackgroundColor3 = Theme.Button
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Theme.Text
    btn.TextSize = 12
    
    local corner = Instance.new("UICorner",btn)
    corner.CornerRadius = UDim.new(0,7)
    
    local stroke = Instance.new("UIStroke",btn)
    stroke.Color = Theme.Stroke
    
    btn.MouseButton1Click:Connect(cb)
end

local function FluentToggle(parent, title, desc, callback)
    local state = false
    local btn = Instance.new("TextButton", parent)
    btn.Size   = UDim2.new(0.98,0,0,48)
    btn.BackgroundColor3 = Theme.Button
    btn.Text   = ""
    btn.AutoButtonColor = false
    
    local btnCorner = Instance.new("UICorner",btn)
    btnCorner.CornerRadius = UDim.new(0,7)
    
    local btnStroke = Instance.new("UIStroke",btn)
    btnStroke.Color = Theme.Stroke

    local tx = Instance.new("TextLabel",btn)
    tx.Size   = UDim2.new(0.72,0,0.5,0)
    tx.Position = UDim2.new(0,10,0,5)
    tx.Text   = title
    tx.Font = Enum.Font.GothamMedium
    tx.TextColor3 = Theme.Text
    tx.TextSize = 12
    tx.TextXAlignment = Enum.TextXAlignment.Left
    tx.BackgroundTransparency = 1

    local sub = Instance.new("TextLabel",btn)
    sub.Size  = UDim2.new(0.72,0,0.5,0)
    sub.Position = UDim2.new(0,10,0.5,0)
    sub.Text  = desc
    sub.Font = Enum.Font.Gotham
    sub.TextColor3 = Theme.SubText
    sub.TextSize = 10
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.BackgroundTransparency = 1

    local pill = Instance.new("Frame",btn)
    pill.Size   = UDim2.new(0,42,0,22)
    pill.Position = UDim2.new(1,-52,0.5,-11)
    pill.BackgroundColor3 = Theme.Button
    
    local pillCorner = Instance.new("UICorner",pill)
    pillCorner.CornerRadius = UDim.new(1,0)
    
    local ps = Instance.new("UIStroke",pill)
    ps.Color = Theme.Stroke
    ps.Thickness = 1

    local pillTxt = Instance.new("TextLabel",pill)
    pillTxt.Size = UDim2.new(1,0,1,0)
    pillTxt.Text = "OFF"
    pillTxt.Font = Enum.Font.GothamBold
    pillTxt.TextColor3 = Theme.SubText
    pillTxt.TextSize = 9
    pillTxt.BackgroundTransparency = 1

    local function setV(on)
        state = on
        pill.BackgroundColor3  = on and Theme.Accent or Theme.Button
        ps.Color               = on and Theme.Accent or Theme.Stroke
        pillTxt.Text           = on and "ON"  or "OFF"
        pillTxt.TextColor3     = on and Color3.new(1,1,1) or Theme.SubText
        btn.BackgroundColor3   = on and Color3.fromRGB(30,42,36) or Theme.Button
    end
    
    setV(false)
    
    btn.MouseButton1Click:Connect(function() 
        local res = callback(not state)
        setV(res ~= nil and res or not state) 
    end)
    
    return setV
end

local function FluentSlider(parent, label, minV, maxV, defaultV, sweetspot, getV, setV)
    local row = Instance.new("Frame", parent)
    row.Size  = UDim2.new(0.98,0,0,62)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel  = 0
    
    local rowCorner = Instance.new("UICorner",row)
    rowCorner.CornerRadius = UDim.new(0,7)
    
    local rowStroke = Instance.new("UIStroke",row)
    rowStroke.Color = Theme.Stroke

    local nameLbl = Instance.new("TextLabel",row)
    nameLbl.Size  = UDim2.new(0.55,0,0,20)
    nameLbl.Position = UDim2.new(0,10,0,6)
    nameLbl.BackgroundTransparency=1
    nameLbl.Text  = label
    nameLbl.TextColor3 = Theme.Text
    nameLbl.Font  = Enum.Font.GothamMedium
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel",row)
    valLbl.Size  = UDim2.new(0.40,0,0,20)
    valLbl.Position = UDim2.new(0.58,0,0,6)
    valLbl.BackgroundTransparency=1
    valLbl.Font  = Enum.Font.GothamBold
    valLbl.TextSize = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame",row)
    track.Size  = UDim2.new(1,-20,0,6)
    track.Position = UDim2.new(0,10,0,36)
    track.BackgroundColor3 = Color3.fromRGB(14,18,28)
    track.BorderSizePixel = 0
    
    local trackCorner = Instance.new("UICorner",track)
    trackCorner.CornerRadius = UDim.new(0,3)

    local fill = Instance.new("Frame",track)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0,0,1,0)
    
    local fillCorner = Instance.new("UICorner",fill)
    fillCorner.CornerRadius = UDim.new(0,3)

    local knob = Instance.new("Frame",track)
    knob.Size = UDim2.new(0,14,0,14)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    
    local knobCorner = Instance.new("UICorner",knob)
    knobCorner.CornerRadius = UDim.new(0,7)

    local minTxt = Instance.new("TextLabel",row)
    minTxt.Size = UDim2.new(0,30,0,10)
    minTxt.Position=UDim2.new(0,10,0,48)
    minTxt.BackgroundTransparency=1
    minTxt.Text=tostring(minV)
    minTxt.TextColor3=Theme.SubText
    minTxt.Font=Enum.Font.Code
    minTxt.TextSize=8
    minTxt.TextXAlignment = Enum.TextXAlignment.Left

    local maxTxt = Instance.new("TextLabel",row)
    maxTxt.Size = UDim2.new(0,40,0,10)
    maxTxt.Position=UDim2.new(1,-50,0,48)
    maxTxt.BackgroundTransparency=1
    maxTxt.Text=tostring(maxV).." MAX"
    maxTxt.TextColor3=Theme.Red
    maxTxt.Font=Enum.Font.Code
    maxTxt.TextSize=8
    maxTxt.TextXAlignment = Enum.TextXAlignment.Right

    local function updateFromPct(pct)
        pct = math.clamp(pct,0,1)
        local raw = minV + pct*(maxV-minV)
        local val = math.clamp(math.round(raw/10)*10, minV, maxV)
        setV(val)
        
        local rp  = (val-minV)/(maxV-minV)
        fill.Size = UDim2.new(rp,0,1,0)
        knob.Position = UDim2.new(rp,-7,0.5,-7)
        
        local col = (val >= maxV) and Theme.Red or Theme.Accent
        valLbl.Text = val..""
        valLbl.TextColor3 = col
        fill.BackgroundColor3 = col
        knob.BackgroundColor3 = (val>=maxV) and Theme.Red or Color3.new(1,1,1)
    end
    updateFromPct((defaultV-minV)/(maxV-minV))

    local dragging = false
    local function applyInput(inp)
        local ax = track.AbsolutePosition.X
        local aw = track.AbsoluteSize.X
        updateFromPct((inp.Position.X-ax)/aw)
    end
    
    knob.InputBegan:Connect(function(i) 
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then 
            dragging=true 
        end 
    end)
    track.InputBegan:Connect(function(i) 
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then 
            dragging=true
            applyInput(i) 
        end 
    end)
    UserInputService.InputChanged:Connect(function(i) 
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then 
            applyInput(i) 
        end 
    end)
    UserInputService.InputEnded:Connect(function(i) 
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then 
            dragging=false 
        end 
    end)
end

local function FluentStepper(parent, label, fmt, getV, decV, incV)
    local row = Instance.new("Frame",parent)
    row.Size  = UDim2.new(0.98,0,0,38)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel  = 0
    
    local rowCorner = Instance.new("UICorner",row)
    rowCorner.CornerRadius = UDim.new(0,7)
    
    local rowStroke = Instance.new("UIStroke",row)
    rowStroke.Color = Theme.Stroke

    local lbl2 = Instance.new("TextLabel",row)
    lbl2.Size  = UDim2.new(0.52,0,1,0)
    lbl2.Position = UDim2.new(0,10,0,0)
    lbl2.BackgroundTransparency=1
    lbl2.Text  = string.format(fmt, getV())
    lbl2.TextColor3 = Theme.Text
    lbl2.Font  = Enum.Font.GothamMedium
    lbl2.TextSize = 11
    lbl2.TextXAlignment = Enum.TextXAlignment.Left

    local function mkB(t, xoff)
        local b = Instance.new("TextButton",row)
        b.Size  = UDim2.new(0,28,0,26)
        b.Position = UDim2.new(1,xoff,0.5,-13)
        b.BackgroundColor3 = Color3.fromRGB(45,45,52)
        b.TextColor3 = Theme.Text
        b.Text  = t
        b.Font  = Enum.Font.GothamBold
        b.TextSize = 14
        
        local bCorner = Instance.new("UICorner",b)
        bCorner.CornerRadius = UDim.new(0,6)
        return b
    end
    
    local btnDec = mkB("<",-62)
    btnDec.MouseButton1Click:Connect(function() 
        decV()
        lbl2.Text=string.format(fmt,getV()) 
    end)
    
    local btnInc = mkB(">", -30)
    btnInc.MouseButton1Click:Connect(function() 
        incV()
        lbl2.Text=string.format(fmt,getV()) 
    end)
end

-- ── TABS ──────────────────────────────────────────────────────
local TabRace  = CreateTab("Race",  "🏁")
local TabFarm  = CreateTab("Farm",  "🚜")
local TabCar   = CreateTab("Car",   "🚗")
local TabWorld = CreateTab("World", "🌍")
local TabMisc  = CreateTab("Misc",  "⚙️")

-- ── RACE TAB ──────────────────────────────────────────────────
Section(TabRace, "  AUTO RACE")

local arRow = Instance.new("TextButton", TabRace)
arRow.Size  = UDim2.new(0.98,0,0,52)
arRow.BackgroundColor3 = Theme.Button
arRow.Text  = ""
arRow.AutoButtonColor = false

local arRowCorner = Instance.new("UICorner",arRow)
arRowCorner.CornerRadius = UDim.new(0,8)

local arStroke = Instance.new("UIStroke",arRow)
arStroke.Color = Theme.Stroke

local arMain = Instance.new("TextLabel",arRow)
arMain.Size  = UDim2.new(0.75,0,0.52,0)
arMain.Position = UDim2.new(0,12,0.04,0)
arMain.BackgroundTransparency=1
arMain.Text  = "AutoRace: OFF"
arMain.TextColor3 = Theme.SubText
arMain.Font  = Enum.Font.GothamBlack
arMain.TextSize = 13
arMain.TextXAlignment = Enum.TextXAlignment.Left

local arSub = Instance.new("TextLabel",arRow)
arSub.Size   = UDim2.new(0.75,0,0.44,0)
arSub.Position = UDim2.new(0,12,0.56,0)
arSub.BackgroundTransparency=1
arSub.Text   = "City Highway Race  ·  V39"
arSub.TextColor3 = Theme.SubText
arSub.Font   = Enum.Font.Gotham
arSub.TextSize = 10
arSub.TextXAlignment = Enum.TextXAlignment.Left

local arDot = Instance.new("Frame",arRow)
arDot.Size  = UDim2.new(0,10,0,10)
arDot.Position = UDim2.new(1,-18,0.5,-5)
arDot.BackgroundColor3 = Theme.SubText

local arDotCorner = Instance.new("UICorner",arDot)
arDotCorner.CornerRadius = UDim.new(0,5)

local statRow = Instance.new("Frame", TabRace)
statRow.Size  = UDim2.new(0.98,0,0,32)
statRow.BackgroundColor3 = Color3.fromRGB(20,20,24)
statRow.BorderSizePixel  = 0

local statRowCorner = Instance.new("UICorner",statRow)
statRowCorner.CornerRadius = UDim.new(0,6)

local statRowStroke = Instance.new("UIStroke",statRow)
statRowStroke.Color = Theme.Stroke

local statLbl = Instance.new("TextLabel", statRow)
statLbl.Size  = UDim2.new(1,-6,1,0)
statLbl.Position = UDim2.new(0,3,0,0)
statLbl.BackgroundTransparency=1
statLbl.Text  = "  Status: Idle"
statLbl.TextColor3 = Theme.SubText
statLbl.Font  = Enum.Font.Code
statLbl.TextSize = 10
statLbl.TextWrapped = true
statLbl.TextXAlignment = Enum.TextXAlignment.Left
_statusLbl = statLbl

Section(TabRace, "  FLIGHT SPEED")
FluentSlider(TabRace, "AutoRace Speed", 50, AR_SPEED_CAP, Config.AutoRaceSpeed, 500, 
    function() return Config.AutoRaceSpeed end, 
    function(v) Config.AutoRaceSpeed = math.clamp(v, 50, AR_SPEED_CAP) end)

local function UpdateARVisual()
    local map = {
        IDLE     = {txt="AutoRace: OFF",      col=Theme.SubText, bg=Theme.Button},
        QUEUING  = {txt="AutoRace: QUEUING",  col=Theme.Orange,  bg=Color3.fromRGB(35,28,15)},
        STARTING = {txt="AutoRace: STANDBY",  col=Theme.Red,     bg=Color3.fromRGB(35,18,18)},
        RACING   = {txt="AutoRace: RACING",   col=Theme.Green,   bg=Color3.fromRGB(18,35,24)},
    }
    local s = map[AR_STATE] or map.IDLE
    arMain.Text = s.txt
    arMain.TextColor3 = s.col
    arSub.TextColor3 = s.col
    arRow.BackgroundColor3 = s.bg
    arDot.BackgroundColor3 = s.col
    arStroke.Color = s.col
end

arRow.MouseButton1Click:Connect(function()
    Config.AutoRace = not Config.AutoRace
    
    if Config.AutoRace then
        if Config.SpeedFarm then 
            Config.SpeedFarm = false 
            farmRoad.Parent = nil
        end
        local uuidF, stateV = FindPlayerRaceFolder()
        if uuidF then
            local sv = stateV and stateV.Value or ""
            if sv == "Racing" then
                AR_STATE="RACING"
                UpdateARVisual()
                if not raceThread then 
                    raceThread = task.spawn(DoRaceLoop, uuidF) 
                end
            else
                AR_STATE="STARTING"
                UpdateARVisual()
                SetStatus("Race in countdown, standing by 🚦", 255, 152, 0)
            end
            return
        end
        AR_STATE="QUEUING"
        UpdateARVisual()
        SetStatus("Teleporting to queue...", 255, 152, 0)
        local ch = player.Character
        if ch and ch:FindFirstChild("Humanoid") then
            local seat = ch.Humanoid.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                local car  = seat.Parent
                local root = car.PrimaryPart or seat
                if root then
                    car:PivotTo(CFrame.new(QUEUE_POS))
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    else
        Config.AutoRace = false
        AR_STATE="IDLE"
        if raceThread then 
            task.cancel(raceThread)
            raceThread=nil 
        end
        RestoreCollisions()
        raceOwnsStatus = false
        UpdateARVisual()
        SetStatus("AutoRace OFF")
    end
end)

-- ── FARM TAB ──────────────────────────────────────────────────
Section(TabFarm, "  SPEED FARMING")
FluentToggle(TabFarm, "🏎️ Auto Speed Farm", "Teleports car to an infinite sky runway to farm money", function(v)
    Config.SpeedFarm = v
    if v then
        Config.AutoRace = false
        AR_STATE = "IDLE"
        UpdateARVisual()
        farmRoad.Parent = Workspace
        if currentCar then
            currentCar:PivotTo(CFrame.new(FARM_POS))
            local root = currentCar.PrimaryPart or currentSeat
            if root then 
                root.AssemblyLinearVelocity = Vector3.zero 
            end
        end
    else
        farmRoad.Parent = nil
        if currentCar then
            currentCar:PivotTo(CFrame.new(QUEUE_POS))
            local root = currentCar.PrimaryPart or currentSeat
            if root then 
                root.AssemblyLinearVelocity = Vector3.zero 
            end
        end
    end
    return v
end)

-- ── V39 FIX: Added Farm Cruising Speed Slider ──
Section(TabFarm, "  FARM SETTINGS")
FluentSlider(TabFarm, "Farm Cruising Speed", 50, 400, Config.FarmSpeed, 250, 
    function() return Config.FarmSpeed end, 
    function(v) Config.FarmSpeed = math.clamp(v, 50, 400) end)

Section(TabFarm, "  OVERNIGHT TOOLS")
FluentToggle(TabFarm, "💤 Anti-AFK (No Kick)", "Intercepts Roblox idle kicks for overnight farming", function(v) 
    Config.AntiAFK = v
    return v 
end)

-- ── CAR TAB ───────────────────────────────────────────────────
Section(TabCar, "  UTILITY")
AddButton(TabCar, "🔄 Instant Auto-Flip", function() 
    FlipCar() 
end)

FluentToggle(TabCar, "👻 Ghost Mode", "Drive through traffic and objects (No Collisions)", function(v)
    Config.GhostMode = v
    if not v then 
        RestoreCollisions() 
    end
    return v
end)

Section(TabCar, "  ENGINE MODS")
FluentToggle(TabCar, "⚡ Speed Hack", "Overrides car's normal engine max speed", function(v) 
    Config.SpeedHack = v
    return v 
end)

FluentToggle(TabCar, "🔥 Infinite Nitro", "Keeps CurrentBoost at MaxBoost infinitely", function(v) 
    Config.InfNitro = v
    return v 
end)

FluentToggle(TabCar, "🧲 Aero Grip (Downforce)", "Injects downward force to pin the car to the road", function(v) 
    Config.TireGrip = v
    ManagePhysicsMods(currentCar)
    return v 
end)

Section(TabCar, "  HACK TUNING")
FluentStepper(TabCar, "Top Speed Override", "%d st/s",
    function() return Config.MaxSpeed end,
    function() Config.MaxSpeed=math.max(50,Config.MaxSpeed-50) end,
    function() Config.MaxSpeed=Config.MaxSpeed+50 end)
    
FluentStepper(TabCar, "Boost Power", "%.1f",
    function() return Config.Acceleration end,
    function() Config.Acceleration=math.max(0.5,Config.Acceleration-0.5) end,
    function() Config.Acceleration=Config.Acceleration+0.5 end)

-- ── MOTORCYCLE SECTION ───────────────────────────────────────
Section(TabCar, "  MOTORCYCLE")

FluentToggle(TabCar, "🏍️ Moto Speed Boost",
    "Horizontal boost (XZ-only) — works on bikes & cars, no flip",
    function(v)
        Config.MotoSpeedHack = v
        return v
    end)

FluentToggle(TabCar, "🛡️ No Crash Death",
    "Health stays full — no death or ragdoll on collision",
    function(v)
        Config.NoCrashDeath = v
        if v and player.Character then
            local h = player.Character:FindFirstChild("Humanoid")
            if h then
                pcall(function() h.BreakJointsOnDeath = false end)
            end
        end
        return v
    end)

FluentStepper(TabCar, "Moto Top Speed", "%d st/s",
    function() return Config.MotoMaxSpeed end,
    function() Config.MotoMaxSpeed = math.max(50, Config.MotoMaxSpeed - 50) end,
    function() Config.MotoMaxSpeed = Config.MotoMaxSpeed + 50 end)

FluentStepper(TabCar, "Moto Boost Power", "%.1f",
    function() return Config.MotoAccel end,
    function() Config.MotoAccel = math.max(0.5, Config.MotoAccel - 0.5) end,
    function() Config.MotoAccel = Config.MotoAccel + 0.5 end)

-- ── WORLD TAB (RESTORED) ──────────────────────────────────────
Section(TabWorld, "  TRAFFIC")
FluentToggle(TabWorld, "🚫 Kill Traffic", "Remove NPC vehicles from world", function() 
    return ToggleTraffic() 
end)

Section(TabWorld, "  VISUALS")
FluentToggle(TabWorld, "☀️ Full Bright", "Force maximum ambient lighting", function() 
    return ToggleFullBright() 
end)

Section(TabWorld, "  PERFORMANCE")
FluentToggle(TabWorld, "🖥️ FPS Boost", "Disable shadows & particles", function() 
    return ToggleFPSBoost() 
end)

-- ── MISC TAB ──────────────────────────────────────────────────
Section(TabMisc, "  INFO")
local function InfoRow(parent, text)
    local r = Instance.new("Frame",parent)
    r.Size  = UDim2.new(0.98,0,0,30)
    r.BackgroundColor3 = Color3.fromRGB(20,20,24)
    r.BorderSizePixel  = 0
    
    local rCorner = Instance.new("UICorner",r)
    rCorner.CornerRadius = UDim.new(0,6)
    
    local l = Instance.new("TextLabel",r)
    l.Size  = UDim2.new(1,-10,1,0)
    l.Position = UDim2.new(0,10,0,0)
    l.BackgroundTransparency=1
    l.Text  = text
    l.TextColor3 = Theme.SubText
    l.Font  = Enum.Font.Gotham
    l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
end

InfoRow(TabMisc, "🏁  Midnight Chasers AutoRace  V39")
InfoRow(TabMisc, "🔧  Ultimate Complete Edition")
InfoRow(TabMisc, "💡  Fluent UI  ·  josepedov")
InfoRow(TabMisc, "📋  Changelog: Restored World mods & added Farm Speed.")

-- Init default tab
if AllTabs[1] and AllTabBtns[1] then
    AllTabs[1].Frame.Visible = true
    AllTabBtns[1].Btn.BackgroundTransparency = 0.82
    AllTabBtns[1].Btn.TextColor3 = Theme.Text
    AllTabBtns[1].Ind.Visible = true
end

SetProg(95, "Finalising System Hooks...", 5)
task.wait(0.3)

-- ═══════════════════════════════════════════════════════════════
--  HEARTBEAT — state machine + SpeedHack + Farm Loop
-- ═══════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()

    if Config.FullBright then
        Lighting.Ambient = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.ClockTime = 12
    end

    local ch = player.Character
    if not ch or not ch:FindFirstChild("Humanoid") then return end
    local humanoid = ch.Humanoid

    -- ── NO CRASH DEATH — runs every frame regardless of vehicle ──
    -- Keeps health at max and disables joint-breaking so the
    -- character cannot die or ragdoll from collision physics.
    if Config.NoCrashDeath then
        if humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
        pcall(function() humanoid.BreakJointsOnDeath = false end)
    end

    currentSeat = humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then
        currentCar = nil
        return
    end
    currentCar = currentSeat.Parent

    -- Detect motorcycle by model name (see MOTO_KEYS list above)
    local isMoto = IsMoto(currentCar)

    local wantsMods = Config.TireGrip
    if wantsMods ~= lastModsState then
        ManagePhysicsMods(currentCar)
        lastModsState = wantsMods
    end

    local gasVal, brakeVal, gearVal = (currentSeat.ThrottleFloat or 0), 0, 1
    local iface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if iface and iface:FindFirstChild("Values") then
        local v = iface.Values
        if v:FindFirstChild("Throttle") then gasVal   = v.Throttle.Value end
        if v:FindFirstChild("Brake")    then brakeVal = v.Brake.Value    end
        if v:FindFirstChild("Gear")     then gearVal  = v.Gear.Value     end
    end
    
    local isRev = (gearVal==-1) or (brakeVal>0.1) or (gasVal<-0.1)
    local root = currentCar.PrimaryPart or currentSeat

    -- ── INFINITE NITRO ──────────────────────────────
    if Config.InfNitro then
        local valObj = nil
        if iface then 
            valObj = iface:FindFirstChild("Values") 
        end
        if not valObj then 
            valObj = currentCar:FindFirstChild("Values", true) 
        end
        if valObj then
            local maxB = valObj:GetAttribute("MaxBoost")
            if maxB and maxB > 0 then
                valObj:SetAttribute("CurrentBoost", maxB)
            end
        end
    end

    -- ── GHOST MODE ──────────────────────────────────────────────
    if Config.GhostMode then
        for _, p in ipairs(currentCar:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and not string.find(p.Name:lower(), "wheel") then
                p.CanCollide = false
            end
        end
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then 
                p.CanCollide = false 
            end
        end
    end

    -- ── AUTO SPEED FARM ─────────────────────────────────────────
    if Config.SpeedFarm then
        if root and root:IsA("BasePart") then
            -- Keep the runway centered exactly underneath the car
            farmRoad.CFrame = CFrame.new(root.Position.X, 9995, root.Position.Z)
            
            -- Lock orientation to prevent flipping on the flat road
            root.AssemblyAngularVelocity = Vector3.zero
            
            -- Force car perfectly straight forward at FARM speed
            root.AssemblyLinearVelocity = root.CFrame.LookVector * Config.FarmSpeed
            SetStatus("🚜 Auto-Farm Active — Speeding on Sky Road", 0, 255, 100)
        end
        return -- Skip normal AutoRace processing while farming
    end

    -- ── AutoRace state machine ──────────────────────────────────
    if Config.AutoRace then
        if AR_STATE == "QUEUING" then
            local uuidF, stateV = FindPlayerRaceFolder()
            if uuidF then
                local sv = stateV and stateV.Value or ""
                if sv == "Racing" then
                    AR_STATE="RACING"
                    UpdateARVisual()
                    if not raceThread then 
                        raceThread = task.spawn(DoRaceLoop, uuidF) 
                    end
                else
                    AR_STATE="STARTING"
                    UpdateARVisual()
                end
            end
        elseif AR_STATE == "STARTING" then
            local uuidF, stateV = FindPlayerRaceFolder()
            if uuidF then
                local sv = stateV and stateV.Value or ""
                if sv == "Racing" then
                    AR_STATE="RACING"
                    UpdateARVisual()
                    if not raceThread then 
                        raceThread = task.spawn(DoRaceLoop, uuidF) 
                    end
                end
            else
                AR_STATE="QUEUING"
                UpdateARVisual()
            end
        elseif AR_STATE == "RACING" then
            if AR_STATE ~= "RACING" then 
                UpdateARVisual() 
            end
        end
        return
    end

    if AR_STATE ~= "IDLE" then
        AR_STATE="IDLE"
        UpdateARVisual()
        if raceThread then 
            task.cancel(raceThread)
            raceThread=nil 
        end
        if not Config.GhostMode then 
            RestoreCollisions() 
        end
        raceOwnsStatus = false
        SetStatus("AutoRace OFF")
    end

    -- ── SPEED HACK OVERRIDE ─────────────────────────────────────
    if Config.SpeedHack then
        if root and root:IsA("BasePart") then
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = {ch, currentCar}
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local grounded = Workspace:Raycast(root.Position, Vector3.new(0,-5,0), rp)
            
            if gasVal > Config.Deadzone and not isRev then
                if grounded then
                    if root.AssemblyLinearVelocity.Magnitude < Config.MaxSpeed then
                        root.AssemblyLinearVelocity += root.CFrame.LookVector * Config.Acceleration
                        SetStatus("SpeedHack: BOOSTING", 0, 215, 80)
                    else
                        SetStatus("SpeedHack: MAX SPEED", 255, 200, 0)
                    end
                else
                    SetStatus("SpeedHack: AIRBORNE", 200, 80, 80)
                end
            else
                SetStatus(isRev and "Reversing..." or "Status: Idle")
            end
        end
    elseif Config.MotoSpeedHack then
        -- Status is set inside the moto block below; skip generic idle
    else
        SetStatus("Status: Idle")
    end

    -- ── MOTO SPEED HACK ─────────────────────────────────────────
    -- Separate from the car SpeedHack. Boosts along the XZ plane
    -- only — never along the full 3D LookVector which on a leaning
    -- bike points partly downward and would flip the motorcycle.
    if Config.MotoSpeedHack then
        if root and root:IsA("BasePart") then
            -- Project look direction onto XZ (horizontal) plane
            local lv   = root.CFrame.LookVector
            local flat = Vector3.new(lv.X, 0, lv.Z)
            if flat.Magnitude > 0.01 then flat = flat.Unit end

            if gasVal > Config.Deadzone and not isRev then
                local spd = root.AssemblyLinearVelocity.Magnitude
                if spd < Config.MotoMaxSpeed then
                    root.AssemblyLinearVelocity =
                        root.AssemblyLinearVelocity + flat * Config.MotoAccel
                    SetStatus(string.format(
                        "🏍️ Moto Boost: %.0f / %d st/s", spd, Config.MotoMaxSpeed),
                        0, 215, 80)
                else
                    SetStatus(string.format(
                        "🏍️ Moto Boost: MAX  %.0f st/s", spd),
                        255, 200, 0)
                end
            else
                SetStatus(isRev and "🏍️ Reversing..." or "🏍️ Moto Boost: Idle")
            end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────
--  DISMISS LOADING SCREEN
-- ─────────────────────────────────────────────────────────────
SetProg(100, "Ready!")
task.wait(0.5)

if loadAnimConn then
    loadAnimConn:Disconnect()
end

-- Cancel any in-flight camera CFrame tween (SetProg fires one that may
-- still be running). Snap it to current position so it stops immediately.
pcall(function()
    TweenService:Create(cam, TweenInfo.new(0), {CFrame = cam.CFrame}):Play()
end)
task.wait()  -- one frame for the snap to settle

-- Always restore to Custom (follow-player) regardless of prevCamType.
-- On mobile prevCamType is often already Scriptable (custom game camera),
-- restoring it would leave the camera frozen after the loading screen.
cam.CameraType = Enum.CameraType.Custom
cam.CameraSubject = nil  -- let the engine re-attach to the humanoid
task.wait()  -- one frame for the engine to reattach

TweenService:Create(bg, TweenInfo.new(0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {BackgroundTransparency=1}):Play()

for _,d in ipairs(loadGui:GetDescendants()) do
    if d:IsA("TextLabel") then 
        pcall(function() 
            TweenService:Create(d, TweenInfo.new(0.4), {TextTransparency=1}):Play() 
        end) 
    end
    if d:IsA("Frame") then 
        pcall(function() 
            TweenService:Create(d, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play() 
        end) 
    end
end

task.wait(0.6)

if loadGui then 
    loadGui:Destroy() 
end

print("\n═════════════════════════════════════════════════")
print("[J42] Midnight Chasers — V42 Moto+Stream Edition Ready")
print("[J42] Developed by josepedov")
print("[J42] Active Hooks: AutoRace, AutoFarm, MotoBoost, NoCrashDeath, Anti-AFK, Preloader+Streaming")
print("═════════════════════════════════════════════════\n")

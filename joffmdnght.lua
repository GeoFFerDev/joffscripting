-- [[ JOSEPEDOV V14: MIDNIGHT CHASERS - FINAL AUTORACE ]] --
--
-- AutoRace flow (Highway Race / Race1 - City Highway Race):
--
--  [OFF]     → car moves normally, all features work independently
--
--  [QUEUING] → car is TP'd once into Race1 QueueRegion.
--               Car is left alone so the player can drive into the zone.
--               Script polls for our UUID folder (server creates it when we join).
--
--  [STARTING]→ Server countdown is running. Server will TP car to starting grid.
--               We do NOTHING here - zero interference with the server's teleport.
--               Script watches State value for it to flip to "Racing".
--
--  [RACING]  → Race is live. A coroutine takes over:
--               1. Find next checkpoint Part (lowest numeric name in Checkpoints IntValue)
--               2. TP car to that Part's position (with CanCollide=false so we phase in)
--               3. Park the car still for 0.6 s so the server's zone system registers us
--               4. Wait for that specific Part to disappear (server confirmed it)
--               5. Repeat until no Parts remain → race done, return to QUEUING
--
--  State is read from:
--    Workspace.Races.Race1.Races.<UUID>.State  (StringValue, set by server)
--

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local player           = Players.LocalPlayer

-- ── Anti-overlap ───────────────────────────────────────────────────────────
local guiTarget = (gethui and gethui()) or CoreGui
if guiTarget:FindFirstChild("J14_Midnight") then
    guiTarget.J14_Midnight:Destroy()
end

-- ── Config ─────────────────────────────────────────────────────────────────
local Config = {
    SpeedHack      = false,
    AutoRace       = false,
    InfNitro       = false,
    TrafficBlocked = false,
    FPS_Boosted    = false,
    FullBright     = false,
    Acceleration   = 3.0,
    MaxSpeed       = 400,
    Deadzone       = 0.1,
}

-- ── Saved lighting state ───────────────────────────────────────────────────
local OriginalTech    = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoor = Lighting.OutdoorAmbient
local OriginalClock   = Lighting.ClockTime

-- ── Per-frame car handles ──────────────────────────────────────────────────
local currentSeat = nil
local currentCar  = nil

-- ── AutoRace state ─────────────────────────────────────────────────────────
-- "IDLE" | "QUEUING" | "STARTING" | "RACING"
local AR_STATE      = "IDLE"
local raceCoroutine = nil   -- the coroutine driving checkpoints during RACING

-- Race1 QueueRegion centre (from XML), with Y lifted slightly above road
local QUEUE_POS = Vector3.new(3260.5, 2, 1015.7)

-- ── Utilities ──────────────────────────────────────────────────────────────

local function DisableCarCollisions(car)
    if not car then return end
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

local function RestoreCarCollisions(car)
    if not car then return end
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.CanCollide = true
        end
    end
end

local function TeleportCarTo(car, pos, keepOrientation)
    if not car then return end
    local root = car.PrimaryPart or currentSeat
    if not root then return end
    local cf = keepOrientation
        and CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
        or  CFrame.new(pos + Vector3.new(0, 3, 0))
    car:PivotTo(cf)
    root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

-- Returns UUID folder + State StringValue if player is in any active race lobby
local function FindPlayerRaceFolder()
    local racesWS = Workspace:FindFirstChild("Races")
    if not racesWS then return nil, nil end
    for _, raceN in ipairs(racesWS:GetChildren()) do
        local racesContainer = raceN:FindFirstChild("Races")
        if racesContainer then
            for _, uuidFolder in ipairs(racesContainer:GetChildren()) do
                local racers = uuidFolder:FindFirstChild("Racers")
                if racers and racers:FindFirstChild(player.Name) then
                    local stateVal = uuidFolder:FindFirstChild("State")
                    return uuidFolder, stateVal
                end
            end
        end
    end
    return nil, nil
end

-- Returns the next checkpoint Part (lowest numeric name) from the Checkpoints IntValue
local function FindNextCheckpoint(raceFolder)
    local cpIntVal = raceFolder:FindFirstChild("Checkpoints")
    if not cpIntVal then return nil, nil end
    local best, bestIdx = nil, math.huge
    for _, child in ipairs(cpIntVal:GetChildren()) do
        if child:IsA("BasePart") then
            local idx = tonumber(child.Name)
            if idx and idx < bestIdx then
                best, bestIdx = child, idx
            end
        end
    end
    return best, bestIdx
end

-- ── Status label (set later after UI creation) ────────────────────────────
local SetStatus  -- forward declaration; assigned after UI block

-- ── Race coroutine (runs during RACING phase only) ─────────────────────────
-- Drives the car through every checkpoint in order. Exits when:
--   • no more checkpoint Parts remain (finished), or
--   • AR_STATE is no longer "RACING"
local function StartRaceCoroutine(raceFolder)
    raceCoroutine = task.spawn(function()
        SetStatus("RACING: starting CP loop...", Color3.fromRGB(0, 255, 120))

        while AR_STATE == "RACING" do
            local cpPart, cpIdx = FindNextCheckpoint(raceFolder)

            -- If no checkpoint Parts left, race is done
            if not cpPart then
                SetStatus("RACING: all checkpoints cleared!", Color3.fromRGB(0, 255, 0))
                task.wait(2)
                break
            end

            -- Safety: still have a car?
            if not currentCar then task.wait(0.1); continue end

            -- ① Teleport car to the checkpoint position
            DisableCarCollisions(currentCar)
            TeleportCarTo(currentCar, cpPart.Position)

            SetStatus(string.format("→ CP #%d (TP'd, holding...)", cpIdx), Color3.fromRGB(0, 200, 255))

            -- ② Park car still for 0.6 s so the server's zone/touch system fires
            local holdUntil = tick() + 0.6
            while tick() < holdUntil and AR_STATE == "RACING" do
                if currentCar then
                    local root = currentCar.PrimaryPart or currentSeat
                    if root then
                        root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
                        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                end
                task.wait()
            end

            if AR_STATE ~= "RACING" then break end

            -- ③ Wait for the server to remove this specific Part
            --    (means it registered our checkpoint touch)
            --    Cap wait at 3 s in case something goes wrong
            local confirmed = false
            local timeout   = tick() + 3

            -- Watch for ChildRemoved on the Checkpoints IntValue
            local cpParent = cpPart.Parent
            if cpParent then
                local conn
                conn = cpParent.ChildRemoved:Connect(function(removed)
                    if removed == cpPart then
                        confirmed = true
                        conn:Disconnect()
                    end
                end)
                while not confirmed and tick() < timeout and AR_STATE == "RACING" do
                    task.wait()
                end
                pcall(function() conn:Disconnect() end)
            end

            if not confirmed then
                -- Timeout — nudge forward and try again
                SetStatus(string.format("CP #%d: timeout, retrying...", cpIdx), Color3.fromRGB(255, 200, 0))
                task.wait(0.2)
            else
                SetStatus(string.format("CP #%d confirmed ✓", cpIdx), Color3.fromRGB(0, 255, 100))
                task.wait(0.05)  -- tiny pause before next CP
            end
        end

        -- Clean up after racing ends
        if currentCar then RestoreCarCollisions(currentCar) end
        AR_STATE = "QUEUING"
        SetStatus("Race done. Re-queuing...", Color3.fromRGB(150, 150, 150))
    end)
end

-- ── Feature helpers ────────────────────────────────────────────────────────

local function ToggleTraffic()
    Config.TrafficBlocked = not Config.TrafficBlocked
    local event = ReplicatedStorage:FindFirstChild("CreateNPCVehicle")
    if Config.TrafficBlocked then
        if event then
            for _, c in pairs(getconnections(event.OnClientEvent)) do c:Disable() end
        end
        for _, name in ipairs({"NPCVehicles", "Traffic", "Vehicles"}) do
            local f = Workspace:FindFirstChild(name)
            if f then f:ClearAllChildren() end
        end
    else
        if event then
            for _, c in pairs(getconnections(event.OnClientEvent)) do c:Enable() end
        end
    end
    return Config.TrafficBlocked
end

local function ToggleFPSBoost()
    Config.FPS_Boosted = not Config.FPS_Boosted
    pcall(function()
        if Config.FPS_Boosted then
            Lighting.GlobalShadows = false
            if sethiddenproperty then sethiddenproperty(Lighting, "Technology", Enum.Technology.Voxel) end
            for _, v in ipairs(workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("BasePart") then v.CastShadow = false
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
                end)
            end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then sethiddenproperty(Lighting, "Technology", OriginalTech) end
            for _, v in ipairs(workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("BasePart") then v.CastShadow = true
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = true end
                end)
            end
        end
    end)
    return Config.FPS_Boosted
end

local function ToggleFullBright()
    Config.FullBright = not Config.FullBright
    if not Config.FullBright then
        Lighting.Ambient        = OriginalAmbient
        Lighting.OutdoorAmbient = OriginalOutdoor
        Lighting.ClockTime      = OriginalClock
    end
    return Config.FullBright
end

-- ── Drag ───────────────────────────────────────────────────────────────────
local function MakeDraggable(gui)
    local dragging, dragInput, dragStart, startPos
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local d = input.Position - dragStart
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ── UI ─────────────────────────────────────────────────────────────────────
local ScreenGui   = Instance.new("ScreenGui")
ScreenGui.Name    = "J14_Midnight"
ScreenGui.Parent  = guiTarget

-- Mini icon
local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0,50,0,50); IconFrame.Position = UDim2.new(0.9,-60,0.4,0)
IconFrame.BackgroundTransparency = 1; IconFrame.Visible = false; IconFrame.Active = true
IconFrame.Parent = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size = UDim2.new(1,0,1,0); IconButton.BackgroundColor3 = Color3.fromRGB(0,150,255)
IconButton.Text = "J14"; IconButton.TextColor3 = Color3.fromRGB(0,0,0)
IconButton.Font = Enum.Font.GothamBlack; IconButton.TextSize = 16; IconButton.Parent = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(0,25)
MakeDraggable(IconFrame)

-- Main panel
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0,240,0,390); MainFrame.Position = UDim2.new(0.1,0,0.15,0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15,15,20); MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0,150,255); MainFrame.Active = true
MainFrame.Parent = ScreenGui
MakeDraggable(MainFrame)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1,0,0,30); TitleBar.BackgroundColor3 = Color3.fromRGB(10,10,15)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.75,0,1,0); Title.Position = UDim2.new(0.04,0,0,0)
Title.BackgroundTransparency = 1; Title.Text = "J14: MIDNIGHT CHASERS"
Title.TextColor3 = Color3.fromRGB(0,150,255); Title.Font = Enum.Font.GothamBlack
Title.TextSize = 13; Title.TextXAlignment = Enum.TextXAlignment.Left; Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0,30,0,30); MinBtn.Position = UDim2.new(1,-30,0,0)
MinBtn.BackgroundColor3 = Color3.fromRGB(50,50,60); MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255,255,255); MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20; MinBtn.Parent = TitleBar
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible=false; IconFrame.Visible=true end)
IconButton.MouseButton1Click:Connect(function() MainFrame.Visible=true; IconFrame.Visible=false end)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1,0,1,-30); Content.Position = UDim2.new(0,0,0,30)
Content.BackgroundTransparency = 1; Content.ScrollBarThickness = 6
Content.ScrollBarImageColor3 = Color3.fromRGB(0,150,255)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y; Content.CanvasSize = UDim2.new(0,0,0,0)
Content.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0,8); ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder; ListLayout.Parent = Content

local UIPad = Instance.new("UIPadding")
UIPad.PaddingTop = UDim.new(0,10); UIPad.PaddingBottom = UDim.new(0,10); UIPad.Parent = Content

local function MakeButton(label, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9,0,0,35); b.BackgroundColor3 = Color3.fromRGB(40,40,45)
    b.Text = label..": OFF"; b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold; b.TextSize = 13; b.LayoutOrder = order; b.Parent = Content
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(function()
        local s = callback()
        b.Text = label..": "..(s and "ON" or "OFF")
        b.BackgroundColor3 = s and Color3.fromRGB(0,150,255) or Color3.fromRGB(40,40,45)
    end)
    return b
end

-- AutoRace button
local arBtn = Instance.new("TextButton")
arBtn.Size = UDim2.new(0.9,0,0,40); arBtn.BackgroundColor3 = Color3.fromRGB(40,40,45)
arBtn.Text = "🏁 AutoRace (Highway): OFF"; arBtn.TextColor3 = Color3.fromRGB(255,255,255)
arBtn.Font = Enum.Font.GothamBold; arBtn.TextSize = 12; arBtn.LayoutOrder = 1; arBtn.Parent = Content
Instance.new("UICorner",arBtn).CornerRadius = UDim.new(0,6)

local function UpdateARBtn()
    local states = {
        IDLE     = {"🏁 AutoRace (Highway): OFF",  Color3.fromRGB(40,40,45)},
        QUEUING  = {"🏁 AutoRace: QUEUING ⏳",      Color3.fromRGB(255,160,0)},
        STARTING = {"🏁 AutoRace: STARTING 🚦",     Color3.fromRGB(255,100,0)},
        RACING   = {"🏁 AutoRace: RACING 🔥",       Color3.fromRGB(0,180,60)},
    }
    local s = states[AR_STATE] or states.IDLE
    arBtn.Text = s[1]; arBtn.BackgroundColor3 = s[2]
end

arBtn.MouseButton1Click:Connect(function()
    Config.AutoRace = not Config.AutoRace
    if Config.AutoRace then
        AR_STATE = "QUEUING"
        -- One-time TP to queue area so player doesn't have to drive there
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            local seat = char.Humanoid.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                TeleportCarTo(seat.Parent, QUEUE_POS)
            end
        end
        SetStatus("Queued for Highway Race. Drive into the start gate if needed.", Color3.fromRGB(255,180,0))
    else
        -- Cancel race if in progress
        Config.AutoRace = false
        AR_STATE = "IDLE"
        if raceCoroutine then task.cancel(raceCoroutine); raceCoroutine = nil end
        if currentCar then RestoreCarCollisions(currentCar) end
        SetStatus("AutoRace disabled.", Color3.fromRGB(150,150,150))
    end
    UpdateARBtn()
end)

MakeButton("⚡ SpeedHack",    2, function() Config.SpeedHack  = not Config.SpeedHack;  return Config.SpeedHack  end)
MakeButton("🔥 Inf Nitro",    3, function() Config.InfNitro   = not Config.InfNitro;   return Config.InfNitro   end)
MakeButton("🚫 Kill Traffic", 4, function() return ToggleTraffic()    end)
MakeButton("☀️ Full Bright",  5, function() return ToggleFullBright() end)
MakeButton("🖥️ FPS Boost",    6, function() return ToggleFPSBoost()   end)

-- Tuning frame
local TuneFrame = Instance.new("Frame")
TuneFrame.Size = UDim2.new(0.9,0,0,110); TuneFrame.BackgroundColor3 = Color3.fromRGB(25,25,30)
TuneFrame.LayoutOrder = 7; TuneFrame.Parent = Content
Instance.new("UICorner",TuneFrame).CornerRadius = UDim.new(0,6)

local function MakeTuneRow(lText, yL, yB, getV, decV, incV, fmt)
    local lbl = Instance.new("TextLabel")
    lbl.Text = string.format(fmt, getV()); lbl.Size = UDim2.new(1,0,0,20)
    lbl.Position = UDim2.new(0,0,yL,0); lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(200,200,200); lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12; lbl.Parent = TuneFrame
    local function mkB(t, x)
        local b = Instance.new("TextButton"); b.Text = t
        b.Size = UDim2.new(0.3,0,0,25); b.Position = UDim2.new(x,0,yB,0)
        b.BackgroundColor3 = Color3.fromRGB(50,50,50); b.TextColor3 = Color3.fromRGB(255,255,255)
        b.Parent = TuneFrame; Instance.new("UICorner",b); return b
    end
    mkB("<",0.1).MouseButton1Click:Connect(function() decV(); lbl.Text=string.format(fmt,getV()) end)
    mkB(">",0.6).MouseButton1Click:Connect(function() incV(); lbl.Text=string.format(fmt,getV()) end)
end

MakeTuneRow("Speed",0.05,0.25,
    function() return Config.MaxSpeed end,
    function() Config.MaxSpeed=math.max(50,Config.MaxSpeed-50) end,
    function() Config.MaxSpeed=Config.MaxSpeed+50 end,
    "Speed: %d studs/s")
MakeTuneRow("Accel",0.55,0.75,
    function() return Config.Acceleration end,
    function() Config.Acceleration=math.max(0.5,Config.Acceleration-0.5) end,
    function() Config.Acceleration=Config.Acceleration+0.5 end,
    "Accel: %.1f")

-- Status label
local DebugLabel = Instance.new("TextLabel")
DebugLabel.Text = "Status: IDLE"; DebugLabel.Size = UDim2.new(0.9,0,0,40)
DebugLabel.LayoutOrder = 8; DebugLabel.BackgroundTransparency = 1
DebugLabel.TextColor3 = Color3.fromRGB(150,150,150); DebugLabel.Font = Enum.Font.Code
DebugLabel.TextSize = 11; DebugLabel.TextWrapped = true; DebugLabel.Parent = Content

-- Now assign the forward-declared SetStatus
SetStatus = function(text, color)
    DebugLabel.Text      = text
    DebugLabel.TextColor3 = color or Color3.fromRGB(150,150,150)
end

-- ── Master Heartbeat ────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function()

    -- Full Bright override
    if Config.FullBright then
        Lighting.Ambient        = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.ClockTime      = 12
    end

    -- Need character seated in a car
    local char = player.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    currentSeat = char.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then
        currentCar = nil; return
    end
    currentCar = currentSeat.Parent

    -- A-Chassis values
    local gasVal = currentSeat.ThrottleFloat or currentSeat.Throttle or 0
    local brakeVal, gearVal = 0, 1
    local iface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if iface and iface:FindFirstChild("Values") then
        local v = iface.Values
        if v:FindFirstChild("Throttle") then gasVal   = v.Throttle.Value end
        if v:FindFirstChild("Brake")    then brakeVal = v.Brake.Value    end
        if v:FindFirstChild("Gear")     then gearVal  = v.Gear.Value     end
    end

    -- Inf Nitro
    if Config.InfNitro then
        for _, obj in ipairs(currentCar:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                local n = obj.Name:lower()
                if n:match("nitro") or n:match("boost") or n:match("n2o") then obj.Value = 9999 end
            end
        end
        if iface and iface:FindFirstChild("Values") then
            for _, obj in ipairs(iface.Values:GetChildren()) do
                local n = obj.Name:lower()
                if n:match("nitro") or n:match("boost") then obj.Value = 9999 end
            end
        end
    end

    -- ═══════════════════════════════════════════════════
    -- AUTO RACE STATE MACHINE (Heartbeat portion)
    -- The coroutine handles RACING; Heartbeat handles
    -- the earlier states and coroutine launch.
    -- ═══════════════════════════════════════════════════
    if Config.AutoRace then

        if AR_STATE == "QUEUING" then
            -- Look for our UUID folder
            local uuidFolder, stateVal = FindPlayerRaceFolder()
            if uuidFolder then
                local stateStr = stateVal and stateVal.Value or ""
                if stateStr == "Racing" then
                    -- Server already racing (shouldn't normally happen mid-enable,
                    -- but handle it gracefully)
                    AR_STATE = "RACING"
                    UpdateARBtn()
                    if not raceCoroutine then StartRaceCoroutine(uuidFolder) end
                else
                    -- Found folder but race is in countdown ("Starting" or similar)
                    AR_STATE = "STARTING"
                    UpdateARBtn()
                    SetStatus("Countdown in progress — hands off! 🚦", Color3.fromRGB(255,120,0))
                end
            else
                -- Still waiting for server to put us in a race
                local pulse = math.floor(tick()*1.5)%2==0
                SetStatus(pulse and "⏳ Waiting for race slot..."
                               or  "Drive into the start gate if needed",
                          Color3.fromRGB(255,180,0))
            end

        elseif AR_STATE == "STARTING" then
            -- Completely hands-off during server countdown + grid TP
            -- Poll the State value; once it flips to "Racing", start the coroutine
            local uuidFolder, stateVal = FindPlayerRaceFolder()
            if uuidFolder then
                local stateStr = stateVal and stateVal.Value or ""
                if stateStr == "Racing" then
                    AR_STATE = "RACING"
                    UpdateARBtn()
                    SetStatus("🟢 RACE STARTED!", Color3.fromRGB(0,255,100))
                    if not raceCoroutine then StartRaceCoroutine(uuidFolder) end
                else
                    -- Still in countdown; do nothing
                end
            else
                -- Fell out of race (cancelled?)
                AR_STATE = "QUEUING"
                UpdateARBtn()
            end

        elseif AR_STATE == "RACING" then
            -- The coroutine is doing all the work.
            -- Heartbeat just needs to keep collisions off and update button.
            if currentCar then DisableCarCollisions(currentCar) end
            -- (coroutine sets AR_STATE back to QUEUING when done)

        end

        return  -- skip SpeedHack while AutoRace is active
    end

    -- ═══════════════════════════════════════════════════
    -- NORMAL MODE (AutoRace OFF)
    -- ═══════════════════════════════════════════════════
    if AR_STATE ~= "IDLE" then
        AR_STATE = "IDLE"
        UpdateARBtn()
        if raceCoroutine then task.cancel(raceCoroutine); raceCoroutine = nil end
        if currentCar then RestoreCarCollisions(currentCar) end
    end

    -- SpeedHack
    local isReversing = (gearVal == -1) or (brakeVal > 0.1) or (gasVal < -0.1)
    if Config.SpeedHack then
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {char, currentCar}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local grounded = Workspace:Raycast(currentSeat.Position, Vector3.new(0,-5,0), rp)

        if gasVal > Config.Deadzone and not isReversing then
            if grounded then
                local spd = currentSeat.AssemblyLinearVelocity.Magnitude
                if spd < Config.MaxSpeed then
                    currentSeat.AssemblyLinearVelocity =
                        currentSeat.AssemblyLinearVelocity
                        + currentSeat.CFrame.LookVector * Config.Acceleration
                    SetStatus("SpeedHack: BOOSTING", Color3.fromRGB(0,255,80))
                else
                    SetStatus("SpeedHack: MAX SPEED", Color3.fromRGB(255,255,0))
                end
            else
                SetStatus("SpeedHack: AIRBORNE", Color3.fromRGB(255,100,100))
            end
        else
            SetStatus(isReversing and "SpeedHack: REVERSING" or "Status: IDLE")
        end
    else
        SetStatus("Status: IDLE")
    end
end)

print("[J14] Midnight Chasers loaded. AutoRace target: City Highway Race (Race1)")
print("[J14] State flow: QUEUING → STARTING (hands-off) → RACING (coroutine TPs)")

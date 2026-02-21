-- [[ JOSEPEDOV V13: MIDNIGHT CHASERS - HIGHWAY RACE EDITION ]] --
-- AutoRace flow:
--   1. Toggle ON  → instantly teleports car into Race1 QueueRegion (City Highway Race)
--   2. QUEUING    → waits for server to start the race (polls for UUID folder)
--   3. RACING     → instant-TPs through each checkpoint gate in order
--   4. Done       → re-enables collisions, waits quietly
-- The car is NEVER frozen while waiting - only controlled when actively racing.

local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local TweenService     = game:GetService("TweenService")
local player           = Players.LocalPlayer

-- === ANTI-OVERLAP ===
local guiTarget = (gethui and gethui()) or CoreGui
if guiTarget:FindFirstChild("J13_Midnight") then
    guiTarget.J13_Midnight:Destroy()
end

-- ============================================================
-- CONFIG
-- ============================================================
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

-- ============================================================
-- STATE
-- ============================================================
local currentSeat  = nil
local currentCar   = nil
local OriginalTech    = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoor = Lighting.OutdoorAmbient
local OriginalClock   = Lighting.ClockTime

-- AutoRace state machine
local AR_STATE = "IDLE"  -- "IDLE" | "QUEUING" | "RACING"
local lastCpIdx  = nil   -- last checkpoint index we teleported to (debounce)
local cpCooldown = 0     -- tick() timestamp: don't re-TP same CP too fast

-- Race1 QueueRegion world position (extracted from place XML)
-- City Highway Race - you drive into this box to join the queue
local QUEUE_POS = Vector3.new(3260.5, 0, 1015.7)  -- Y adjusted: slightly above road

-- ============================================================
-- HELPERS
-- ============================================================

-- Returns the car's primary assembly part (prefer PrimaryPart, fall back to seat)
local function GetCarRoot(car)
    if not car then return nil end
    return car.PrimaryPart or currentSeat
end

-- Restore collisions on the car
local function RestoreCarCollisions(car)
    if not car then return end
    for _, part in ipairs(car:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end

-- Disable collisions (so we can phase through walls)
local function DisableCarCollisions(car)
    if not car then return end
    for _, part in ipairs(car:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

-- Teleport entire car model to a world position, keeping orientation
local function TeleportCarTo(car, pos)
    local root = GetCarRoot(car)
    if not root then return end
    -- Offset so we TP to the checkpoint centre + small Y so we don't fall through floor
    local cf = CFrame.new(pos + Vector3.new(0, 3, 0))
    car:PivotTo(cf)
    -- Kill momentum so the car doesn't drift through the trigger zone
    root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end

-- Scan ALL race lobbies for a UUID folder that contains this player's name in Racers
local function FindPlayerRaceFolder()
    local racesFolder = Workspace:FindFirstChild("Races")
    if not racesFolder then return nil end
    for _, raceN in ipairs(racesFolder:GetChildren()) do
        local racesContainer = raceN:FindFirstChild("Races")
        if racesContainer then
            for _, uuidFolder in ipairs(racesContainer:GetChildren()) do
                local racers = uuidFolder:FindFirstChild("Racers")
                if racers and racers:FindFirstChild(player.Name) then
                    return uuidFolder, raceN.Name
                end
            end
        end
    end
    return nil
end

-- From a race UUID folder, find the next checkpoint Part (lowest numeric name)
local function FindNextCheckpoint(raceFolder)
    local cpValue = raceFolder:FindFirstChild("Checkpoints")
    if not cpValue then return nil, nil end
    local nextPart = nil
    local minIdx   = math.huge
    for _, child in ipairs(cpValue:GetChildren()) do
        if child:IsA("BasePart") then
            local idx = tonumber(child.Name)
            if idx and idx < minIdx then
                minIdx   = idx
                nextPart = child
            end
        end
    end
    return nextPart, minIdx
end

-- ============================================================
-- FEATURE HELPERS (unchanged logic)
-- ============================================================

local function ToggleTraffic()
    Config.TrafficBlocked = not Config.TrafficBlocked
    local event = ReplicatedStorage:FindFirstChild("CreateNPCVehicle")
    if Config.TrafficBlocked then
        if event then
            for _, c in pairs(getconnections(event.OnClientEvent)) do c:Disable() end
        end
        for _, name in ipairs({"NPCVehicles", "Traffic", "Vehicles"}) do
            local folder = Workspace:FindFirstChild(name)
            if folder then folder:ClearAllChildren() end
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
            if sethiddenproperty then
                sethiddenproperty(Lighting, "Technology", Enum.Technology.Voxel)
            end
            for _, v in ipairs(workspace:GetDescendants()) do
                pcall(function()
                    if v:IsA("BasePart") then v.CastShadow = false
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
                end)
            end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then
                sethiddenproperty(Lighting, "Technology", OriginalTech)
            end
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

-- ============================================================
-- DRAG
-- ============================================================
local function MakeDraggable(gui)
    local dragging, dragInput, dragStart, startPos
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            gui.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ============================================================
-- UI
-- ============================================================
local ScreenGui  = Instance.new("ScreenGui")
ScreenGui.Name   = "J13_Midnight"
ScreenGui.Parent = guiTarget

-- Minimise icon
local IconFrame = Instance.new("Frame")
IconFrame.Size                   = UDim2.new(0, 50, 0, 50)
IconFrame.Position               = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible                = false
IconFrame.Active                 = true
IconFrame.Parent                 = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size             = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
IconButton.Text             = "J13"
IconButton.TextColor3       = Color3.fromRGB(0, 0, 0)
IconButton.Font             = Enum.Font.GothamBlack
IconButton.TextSize         = 16
IconButton.Parent           = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(0, 25)
MakeDraggable(IconFrame)

-- Main panel
local MainFrame = Instance.new("Frame")
MainFrame.Size             = UDim2.new(0, 240, 0, 380)
MainFrame.Position         = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel  = 2
MainFrame.BorderColor3     = Color3.fromRGB(0, 150, 255)
MainFrame.Active           = true
MainFrame.Parent           = ScreenGui
MakeDraggable(MainFrame)

local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
TitleBar.Parent           = MainFrame

local Title = Instance.new("TextLabel")
Title.Size              = UDim2.new(0.75, 0, 1, 0)
Title.Position          = UDim2.new(0.04, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text              = "J13: MIDNIGHT CHASERS"
Title.TextColor3        = Color3.fromRGB(0, 150, 255)
Title.Font              = Enum.Font.GothamBlack
Title.TextSize          = 13
Title.TextXAlignment    = Enum.TextXAlignment.Left
Title.Parent            = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 30, 0, 30)
MinBtn.Position         = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
MinBtn.Text             = "-"
MinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.TextSize         = 20
MinBtn.Parent           = TitleBar

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false; IconFrame.Visible = true
end)
IconButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true; IconFrame.Visible = false
end)

local Content = Instance.new("ScrollingFrame")
Content.Size                   = UDim2.new(1, 0, 1, -30)
Content.Position               = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness     = 6
Content.ScrollBarImageColor3   = Color3.fromRGB(0, 150, 255)
Content.AutomaticCanvasSize    = Enum.AutomaticSize.Y
Content.CanvasSize             = UDim2.new(0, 0, 0, 0)
Content.Parent                 = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding             = UDim.new(0, 8)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ListLayout.SortOrder           = Enum.SortOrder.LayoutOrder
ListLayout.Parent              = Content

local UIPad = Instance.new("UIPadding")
UIPad.PaddingTop    = UDim.new(0, 10)
UIPad.PaddingBottom = UDim.new(0, 10)
UIPad.Parent        = Content

-- Button factory
local function MakeButton(label, order, callback)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.9, 0, 0, 35)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    b.Text             = label .. ": OFF"
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.GothamBold
    b.TextSize         = 13
    b.LayoutOrder      = order
    b.Parent           = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        local s = callback()
        b.Text             = label .. ": " .. (s and "ON" or "OFF")
        b.BackgroundColor3 = s and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
    end)
    return b
end

-- AutoRace button gets special treatment (state-aware)
local arButton = Instance.new("TextButton")
arButton.Size             = UDim2.new(0.9, 0, 0, 35)
arButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
arButton.Text             = "🏁 AutoRace (Highway): OFF"
arButton.TextColor3       = Color3.fromRGB(255, 255, 255)
arButton.Font             = Enum.Font.GothamBold
arButton.TextSize         = 12
arButton.LayoutOrder      = 1
arButton.Parent           = Content
Instance.new("UICorner", arButton).CornerRadius = UDim.new(0, 6)

arButton.MouseButton1Click:Connect(function()
    Config.AutoRace = not Config.AutoRace

    if Config.AutoRace then
        -- ── ENABLE: immediately TP car to QueueRegion ──
        AR_STATE    = "QUEUING"
        lastCpIdx   = nil
        cpCooldown  = 0

        -- Make sure we have a car before trying to teleport
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            local seat = char.Humanoid.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                local car = seat.Parent
                DisableCarCollisions(car)
                TeleportCarTo(car, QUEUE_POS)
            end
        end

        arButton.Text             = "🏁 AutoRace (Highway): QUEUING"
        arButton.BackgroundColor3 = Color3.fromRGB(255, 160, 0)
    else
        -- ── DISABLE: clean up ──
        AR_STATE = "IDLE"
        if currentCar then RestoreCarCollisions(currentCar) end
        arButton.Text             = "🏁 AutoRace (Highway): OFF"
        arButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    end
end)

MakeButton("⚡ SpeedHack",   2, function() Config.SpeedHack  = not Config.SpeedHack;  return Config.SpeedHack  end)
MakeButton("🔥 Inf Nitro",   3, function() Config.InfNitro   = not Config.InfNitro;   return Config.InfNitro   end)
MakeButton("🚫 Kill Traffic",4, function() return ToggleTraffic()    end)
MakeButton("☀️ Full Bright", 5, function() return ToggleFullBright() end)
MakeButton("🖥️ FPS Boost",   6, function() return ToggleFPSBoost()   end)

-- Tuning frame
local TuneFrame = Instance.new("Frame")
TuneFrame.Size             = UDim2.new(0.9, 0, 0, 110)
TuneFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TuneFrame.LayoutOrder      = 7
TuneFrame.Parent           = Content
Instance.new("UICorner", TuneFrame).CornerRadius = UDim.new(0, 6)

local function MakeTuneRow(labelText, yLabel, yBtns, getVal, dec, inc, fmt)
    local lbl = Instance.new("TextLabel")
    lbl.Text               = string.format(fmt, getVal())
    lbl.Size               = UDim2.new(1, 0, 0, 20)
    lbl.Position           = UDim2.new(0, 0, yLabel, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3         = Color3.fromRGB(200, 200, 200)
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 12
    lbl.Parent             = TuneFrame

    local function makeBtn(text, x)
        local b = Instance.new("TextButton")
        b.Text             = text
        b.Size             = UDim2.new(0.3, 0, 0, 25)
        b.Position         = UDim2.new(x, 0, yBtns, 0)
        b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        b.TextColor3       = Color3.fromRGB(255, 255, 255)
        b.Parent           = TuneFrame
        Instance.new("UICorner", b)
        return b
    end
    local bMin = makeBtn("<", 0.1)
    local bMax = makeBtn(">", 0.6)
    bMin.MouseButton1Click:Connect(function() dec(); lbl.Text = string.format(fmt, getVal()) end)
    bMax.MouseButton1Click:Connect(function() inc(); lbl.Text = string.format(fmt, getVal()) end)
end

MakeTuneRow("Speed", 0.05, 0.25,
    function() return Config.MaxSpeed end,
    function() Config.MaxSpeed = math.max(50, Config.MaxSpeed - 50) end,
    function() Config.MaxSpeed = Config.MaxSpeed + 50 end,
    "Speed: %d studs/s"
)
MakeTuneRow("Accel", 0.55, 0.75,
    function() return Config.Acceleration end,
    function() Config.Acceleration = math.max(0.5, Config.Acceleration - 0.5) end,
    function() Config.Acceleration = Config.Acceleration + 0.5 end,
    "Accel: %.1f"
)

-- Status / debug label
local DebugLabel = Instance.new("TextLabel")
DebugLabel.Text              = "Status: IDLE"
DebugLabel.Size              = UDim2.new(0.9, 0, 0, 36)
DebugLabel.LayoutOrder       = 8
DebugLabel.BackgroundTransparency = 1
DebugLabel.TextColor3        = Color3.fromRGB(150, 150, 150)
DebugLabel.Font              = Enum.Font.Code
DebugLabel.TextSize          = 11
DebugLabel.TextWrapped       = true
DebugLabel.Parent            = Content

local function SetStatus(text, color)
    DebugLabel.Text      = text
    DebugLabel.TextColor3 = color or Color3.fromRGB(150, 150, 150)
end

-- ============================================================
-- MASTER HEARTBEAT LOOP
-- ============================================================
RunService.Heartbeat:Connect(function()

    -- Full Bright enforcement
    if Config.FullBright then
        Lighting.Ambient        = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.ClockTime      = 12
    end

    -- Require character + seated in car
    local char = player.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    currentSeat = char.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then
        currentCar = nil
        return
    end
    currentCar = currentSeat.Parent

    -- Read A-Chassis values
    local gasVal   = currentSeat.ThrottleFloat or currentSeat.Throttle or 0
    local brakeVal = 0
    local gearVal  = 1
    local interface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if interface and interface:FindFirstChild("Values") then
        local vals = interface.Values
        if vals:FindFirstChild("Throttle") then gasVal   = vals.Throttle.Value end
        if vals:FindFirstChild("Brake")    then brakeVal = vals.Brake.Value    end
        if vals:FindFirstChild("Gear")     then gearVal  = vals.Gear.Value     end
    end

    -- ── Inf Nitro ─────────────────────────────────────────
    if Config.InfNitro then
        for _, obj in ipairs(currentCar:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                local n = obj.Name:lower()
                if n:match("nitro") or n:match("boost") or n:match("n2o") then
                    obj.Value = 9999
                end
            end
        end
        if interface and interface:FindFirstChild("Values") then
            for _, obj in ipairs(interface.Values:GetChildren()) do
                local n = obj.Name:lower()
                if n:match("nitro") or n:match("boost") then obj.Value = 9999 end
            end
        end
    end

    -- ═══════════════════════════════════════════════════════
    -- AUTO RACE STATE MACHINE
    -- ═══════════════════════════════════════════════════════
    if Config.AutoRace then

        if AR_STATE == "QUEUING" then
            -- ── Waiting for race to start ──────────────────
            -- Do NOT touch velocity here - car drives normally while queued
            local raceFolder = FindPlayerRaceFolder()
            if raceFolder then
                AR_STATE  = "RACING"
                lastCpIdx = nil
                DisableCarCollisions(currentCar)
                arButton.Text             = "🏁 AutoRace (Highway): RACING"
                arButton.BackgroundColor3 = Color3.fromRGB(0, 200, 80)
                SetStatus("Race started! Finding checkpoints...", Color3.fromRGB(0, 255, 100))
            else
                -- Still queuing - pulse status
                local pulse = math.floor(tick() * 2) % 2 == 0
                SetStatus(
                    pulse and "⏳ Queuing... waiting for race to start"
                          or  "🏁 Drive into the start gate if not queued",
                    Color3.fromRGB(255, 180, 0)
                )
            end

        elseif AR_STATE == "RACING" then
            -- ── Actively racing through checkpoints ────────
            local raceFolder, raceName = FindPlayerRaceFolder()

            if not raceFolder then
                -- Race ended or player was removed
                AR_STATE = "QUEUING"
                RestoreCarCollisions(currentCar)
                arButton.Text             = "🏁 AutoRace (Highway): QUEUING"
                arButton.BackgroundColor3 = Color3.fromRGB(255, 160, 0)
                SetStatus("Race ended. Re-queueing...", Color3.fromRGB(255, 100, 100))
                return
            end

            local nextCP, cpIdx = FindNextCheckpoint(raceFolder)

            if nextCP then
                -- Only TP if this is a NEW checkpoint (debounce 0.3s per CP)
                local now = tick()
                if cpIdx ~= lastCpIdx and now > cpCooldown then
                    lastCpIdx  = cpIdx
                    cpCooldown = now + 0.3

                    -- Instant teleport car to the checkpoint gate position
                    TeleportCarTo(currentCar, nextCP.Position)
                end

                local dist = (nextCP.Position - currentSeat.Position).Magnitude
                SetStatus(
                    string.format("🏁 Racing: CP #%d | %.0f studs", cpIdx, dist),
                    Color3.fromRGB(0, 210, 255)
                )
            else
                -- No checkpoint Parts visible yet — race might be
                -- counting down or we just cleared the last one.
                -- DO NOT freeze the car. Just wait.
                SetStatus("⏳ Waiting for next checkpoint...", Color3.fromRGB(255, 220, 0))
            end
        end

        -- When AutoRace is active, skip SpeedHack below
        return
    end

    -- ═══════════════════════════════════════════════════════
    -- NORMAL MODE (AutoRace OFF)
    -- ═══════════════════════════════════════════════════════

    -- Restore collisions if we just turned AutoRace off
    if AR_STATE ~= "IDLE" then
        AR_STATE = "IDLE"
        RestoreCarCollisions(currentCar)
    end

    -- ── Grounded SpeedHack ─────────────────────────────────
    local isReversing = (gearVal == -1) or (brakeVal > 0.1) or (gasVal < -0.1)
    if Config.SpeedHack then
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {char, currentCar}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local isGrounded = Workspace:Raycast(currentSeat.Position, Vector3.new(0, -5, 0), rayParams)

        if gasVal > Config.Deadzone and not isReversing then
            if isGrounded then
                local spd = currentSeat.AssemblyLinearVelocity.Magnitude
                if spd < Config.MaxSpeed then
                    currentSeat.AssemblyLinearVelocity =
                        currentSeat.AssemblyLinearVelocity
                        + currentSeat.CFrame.LookVector * Config.Acceleration
                    SetStatus("SpeedHack: BOOSTING", Color3.fromRGB(0, 255, 80))
                else
                    SetStatus("SpeedHack: MAX SPEED", Color3.fromRGB(255, 255, 0))
                end
            else
                SetStatus("SpeedHack: AIRBORNE", Color3.fromRGB(255, 100, 100))
            end
        else
            SetStatus(isReversing and "SpeedHack: REVERSING" or "Status: IDLE")
        end
    else
        SetStatus("Status: IDLE")
    end
end)

print("[J13] Midnight Chasers loaded. AutoRace → Highway Race (Race1: City Highway Race)")

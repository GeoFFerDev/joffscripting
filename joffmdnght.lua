-- [[ JOSEPEDOV V12: MIDNIGHT CHASERS EDITION ]] --
-- Fixes: AutoRace now correctly reads Workspace.Races structure.
--        Checkpoint parts are invisible (Trans=1) numbered gates;
--        script finds the player's active race UUID folder and
--        targets the lowest-indexed Part inside the Checkpoints IntValue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- === ANTI-OVERLAP ===
local guiTarget = (gethui and gethui()) or CoreGui
if guiTarget:FindFirstChild("J12_Midnight") then
    guiTarget.J12_Midnight:Destroy()
end

-- === CONFIGURATION ===
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

-- === STATE ===
local currentSeat = nil
local currentCar  = nil
local OriginalTech    = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoor = Lighting.OutdoorAmbient
local OriginalClock   = Lighting.ClockTime

-- ============================================================
-- HELPER: find the player's active race UUID folder
-- Structure: Workspace.Races.<RaceN>.Races.<UUID>
--   UUID folder has a Racers subfolder containing an ObjectValue
--   named after the local player.
-- ============================================================
local function FindPlayerRaceFolder()
    local racesFolder = Workspace:FindFirstChild("Races")
    if not racesFolder then return nil end
    for _, raceN in ipairs(racesFolder:GetChildren()) do
        local racesContainer = raceN:FindFirstChild("Races")
        if racesContainer then
            for _, uuidFolder in ipairs(racesContainer:GetChildren()) do
                local racers = uuidFolder:FindFirstChild("Racers")
                if racers and racers:FindFirstChild(player.Name) then
                    return uuidFolder
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- HELPER: from a race UUID folder, get the next checkpoint Part
-- The Checkpoints IntValue has Part children named by index (e.g. "27","28","29").
-- The server adds/removes these as the player progresses.
-- We target the one with the LOWEST numeric name = immediate next gate.
-- ============================================================
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
-- FEATURE TOGGLES (unchanged)
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

local function ProcessObjectForFPS(v, state)
    pcall(function()
        if v:IsA("BasePart") then
            v.CastShadow = not state
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Enabled = not state
        end
    end)
end

local function ToggleFPSBoost()
    Config.FPS_Boosted = not Config.FPS_Boosted
    pcall(function()
        if Config.FPS_Boosted then
            Lighting.GlobalShadows = false
            if sethiddenproperty then
                sethiddenproperty(Lighting, "Technology", Enum.Technology.Voxel)
            end
            for _, v in ipairs(workspace:GetDescendants()) do ProcessObjectForFPS(v, true) end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then
                sethiddenproperty(Lighting, "Technology", OriginalTech)
            end
            for _, v in ipairs(workspace:GetDescendants()) do ProcessObjectForFPS(v, false) end
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
    local function update(input)
        local delta = input.Position - dragStart
        gui.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
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
        if input == dragInput and dragging then update(input) end
    end)
end

-- ============================================================
-- UI
-- ============================================================
local ScreenGui   = Instance.new("ScreenGui")
ScreenGui.Name    = "J12_Midnight"
ScreenGui.Parent  = guiTarget

-- Minimise icon
local IconFrame = Instance.new("Frame")
IconFrame.Size                = UDim2.new(0, 50, 0, 50)
IconFrame.Position            = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible             = false
IconFrame.Active              = true
IconFrame.Parent              = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size             = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
IconButton.Text             = "J12"
IconButton.TextColor3       = Color3.fromRGB(0, 0, 0)
IconButton.Font             = Enum.Font.GothamBlack
IconButton.TextSize         = 18
IconButton.Parent           = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(0, 25)
MakeDraggable(IconFrame)

-- Main panel
local MainFrame = Instance.new("Frame")
MainFrame.Size             = UDim2.new(0, 240, 0, 370)
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
Title.Size              = UDim2.new(0.7, 0, 1, 0)
Title.Position          = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text              = "J12: MIDNIGHT CHASERS"
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
    MainFrame.Visible = false
    IconFrame.Visible = true
end)
IconButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    IconFrame.Visible = false
end)

local Content = Instance.new("ScrollingFrame")
Content.Size                  = UDim2.new(1, 0, 1, -30)
Content.Position              = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness    = 6
Content.ScrollBarImageColor3  = Color3.fromRGB(0, 150, 255)
Content.AutomaticCanvasSize   = Enum.AutomaticSize.Y
Content.CanvasSize            = UDim2.new(0, 0, 0, 0)
Content.Parent                = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding              = UDim.new(0, 8)
ListLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
ListLayout.SortOrder            = Enum.SortOrder.LayoutOrder
ListLayout.Parent               = Content

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingTop    = UDim.new(0, 10)
UIPadding.PaddingBottom = UDim.new(0, 10)
UIPadding.Parent        = Content

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
        b.BackgroundColor3 = s
            and Color3.fromRGB(0, 150, 255)
            or  Color3.fromRGB(40, 40, 45)
    end)
end

MakeButton("🏁 AutoRace",          1, function() Config.AutoRace   = not Config.AutoRace;   return Config.AutoRace   end)
MakeButton("⚡ Grounded SpeedHack",2, function() Config.SpeedHack  = not Config.SpeedHack;  return Config.SpeedHack  end)
MakeButton("🔥 Inf Nitro",         3, function() Config.InfNitro   = not Config.InfNitro;   return Config.InfNitro   end)
MakeButton("🚫 Kill Traffic",      4, function() return ToggleTraffic()  end)
MakeButton("☀️ Full Bright",       5, function() return ToggleFullBright() end)
MakeButton("🖥️ FPS Boost",         6, function() return ToggleFPSBoost()  end)

-- Tuning sliders
local TuneFrame = Instance.new("Frame")
TuneFrame.Size             = UDim2.new(0.9, 0, 0, 110)
TuneFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TuneFrame.LayoutOrder      = 7
TuneFrame.Parent           = Content
Instance.new("UICorner", TuneFrame).CornerRadius = UDim.new(0, 6)

-- Speed
local SpdLabel = Instance.new("TextLabel")
SpdLabel.Text               = "Fly/Top Speed: " .. Config.MaxSpeed
SpdLabel.Size               = UDim2.new(1, 0, 0, 20)
SpdLabel.Position           = UDim2.new(0, 0, 0.05, 0)
SpdLabel.BackgroundTransparency = 1
SpdLabel.TextColor3         = Color3.fromRGB(200, 200, 200)
SpdLabel.Font               = Enum.Font.GothamBold
SpdLabel.TextSize           = 12
SpdLabel.Parent             = TuneFrame

local function makeTuneBtn(text, x, y, parent)
    local b = Instance.new("TextButton")
    b.Text             = text
    b.Size             = UDim2.new(0.3, 0, 0, 25)
    b.Position         = UDim2.new(x, 0, y, 0)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Parent           = parent
    Instance.new("UICorner", b)
    return b
end

local SpdMin = makeTuneBtn("<", 0.1, 0.25, TuneFrame)
local SpdMax = makeTuneBtn(">", 0.6, 0.25, TuneFrame)
SpdMin.MouseButton1Click:Connect(function()
    Config.MaxSpeed = math.max(50, Config.MaxSpeed - 50)
    SpdLabel.Text = "Fly/Top Speed: " .. Config.MaxSpeed
end)
SpdMax.MouseButton1Click:Connect(function()
    Config.MaxSpeed = Config.MaxSpeed + 50
    SpdLabel.Text = "Fly/Top Speed: " .. Config.MaxSpeed
end)

-- Acceleration
local AccLabel = Instance.new("TextLabel")
AccLabel.Text               = "Accel: " .. Config.Acceleration
AccLabel.Size               = UDim2.new(1, 0, 0, 20)
AccLabel.Position           = UDim2.new(0, 0, 0.55, 0)
AccLabel.BackgroundTransparency = 1
AccLabel.TextColor3         = Color3.fromRGB(200, 200, 200)
AccLabel.Font               = Enum.Font.GothamBold
AccLabel.TextSize           = 12
AccLabel.Parent             = TuneFrame

local AccMin = makeTuneBtn("<", 0.1, 0.75, TuneFrame)
local AccMax = makeTuneBtn(">", 0.6, 0.75, TuneFrame)
AccMin.MouseButton1Click:Connect(function()
    Config.Acceleration = math.max(0.5, Config.Acceleration - 0.5)
    AccLabel.Text = "Accel: " .. Config.Acceleration
end)
AccMax.MouseButton1Click:Connect(function()
    Config.Acceleration = Config.Acceleration + 0.5
    AccLabel.Text = "Accel: " .. Config.Acceleration
end)

-- Status label
local DebugLabel = Instance.new("TextLabel")
DebugLabel.Text              = "Status: IDLE"
DebugLabel.Size              = UDim2.new(0.9, 0, 0, 30)
DebugLabel.LayoutOrder       = 8
DebugLabel.BackgroundTransparency = 1
DebugLabel.TextColor3        = Color3.fromRGB(150, 150, 150)
DebugLabel.Font              = Enum.Font.Code
DebugLabel.TextSize          = 11
DebugLabel.TextWrapped       = true
DebugLabel.Parent            = Content

-- ============================================================
-- MASTER LOOP
-- ============================================================
RunService.Heartbeat:Connect(function()

    -- Enforce FullBright every frame so game lighting can't override it
    if Config.FullBright then
        Lighting.Ambient        = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.ClockTime      = 12
    end

    -- Bail if character / humanoid not ready
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end
    currentSeat = player.Character.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then
        currentCar = nil
        return
    end
    currentCar = currentSeat.Parent

    -- Read A-Chassis values if present
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

    -- ── Inf Nitro ──────────────────────────────────────────
    if Config.InfNitro and currentCar then
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

    -- ── AutoRace ───────────────────────────────────────────
    if Config.AutoRace then
        -- 1. Locate the UUID folder for this player's current race
        local raceFolder = FindPlayerRaceFolder()

        if not raceFolder then
            DebugLabel.Text      = "AutoRace: Join a race first!"
            DebugLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end

        -- 2. Find the next checkpoint gate (lowest-indexed Part in Checkpoints IntValue)
        local nextCP, cpIdx = FindNextCheckpoint(raceFolder)

        if nextCP and currentCar then
            -- Disable car collisions so we fly through anything
            for _, part in ipairs(currentCar:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end

            local targetPos  = nextCP.Position
            local currentPos = currentSeat.Position
            local dist       = (targetPos - currentPos).Magnitude
            local direction  = (targetPos - currentPos).Unit

            -- Snap car orientation toward checkpoint, then apply velocity
            currentCar:PivotTo(CFrame.lookAt(currentPos, targetPos))
            currentSeat.AssemblyLinearVelocity  = direction * Config.MaxSpeed
            currentSeat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

            DebugLabel.Text = string.format("→ CP #%d  |  %.0f studs", cpIdx, dist)
            DebugLabel.TextColor3 = Color3.fromRGB(0, 200, 255)

        else
            -- No Part children yet — race may be loading or just finished
            if currentCar then
                currentSeat.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
                currentSeat.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            DebugLabel.Text       = "AutoRace: Waiting for checkpoint..."
            DebugLabel.TextColor3 = Color3.fromRGB(255, 220, 0)
        end

    else
        -- Restore collisions when AutoRace is off
        if currentCar then
            for _, part in ipairs(currentCar:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end

        -- ── Grounded SpeedHack ─────────────────────────────
        local isReversing = (gearVal == -1) or (brakeVal > 0.1) or (gasVal < -0.1)
        if Config.SpeedHack then
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {player.Character, currentCar}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local isGrounded = Workspace:Raycast(currentSeat.Position, Vector3.new(0, -5, 0), rayParams)

            if gasVal > Config.Deadzone and not isReversing then
                if isGrounded then
                    local spd = currentSeat.AssemblyLinearVelocity.Magnitude
                    if spd < Config.MaxSpeed then
                        currentSeat.AssemblyLinearVelocity =
                            currentSeat.AssemblyLinearVelocity
                            + currentSeat.CFrame.LookVector * Config.Acceleration
                        DebugLabel.Text       = "SpeedHack: BOOSTING"
                        DebugLabel.TextColor3 = Color3.fromRGB(0, 255, 80)
                    else
                        DebugLabel.Text       = "SpeedHack: MAX SPEED"
                        DebugLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                    end
                else
                    DebugLabel.Text       = "SpeedHack: AIRBORNE"
                    DebugLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
            else
                DebugLabel.Text       = isReversing and "SpeedHack: REVERSING" or "Status: IDLE"
                DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
        else
            DebugLabel.Text       = "Status: IDLE"
            DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end
end)

print("[J12] Midnight Chasers script loaded. AutoRace target: Workspace.Races.<N>.Races.<UUID>.Checkpoints")

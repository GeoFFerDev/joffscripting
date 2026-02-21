-- [[ JOSEPEDOV V9.1: MAGNET EDITION (FIXED) ]] --
-- Features: Checkpoint Magnet (AutoRace), Infinite Nitro, Grounded Speedhack
-- Fixes: Cleaned up UI Overlap, Fixed Syntax Errors, Optimized Memory Leak.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- === ANTI-OVERLAP (Cleans up old stuck UIs) ===
local guiTarget = (gethui and gethui()) or CoreGui
if guiTarget:FindFirstChild("J9_Midnight") then
    guiTarget.J9_Midnight:Destroy()
end

-- === CONFIGURATION ===
local Config = {
    SpeedHack = false,
    AutoRace = false,
    InfNitro = false,
    TrafficBlocked = false,
    FPS_Boosted = false,
    Acceleration = 3.0,  
    MaxSpeed = 400,      
    Deadzone = 0.1
}

-- === STATE ===
local currentSeat = nil
local OriginalTech = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalClock = Lighting.ClockTime

-- === 1. FEATURE TOGGLES ===
local function ToggleTraffic()
    Config.TrafficBlocked = not Config.TrafficBlocked
    local event = ReplicatedStorage:FindFirstChild("CreateNPCVehicle")
    if Config.TrafficBlocked then
        if event then for _, c in pairs(getconnections(event.OnClientEvent)) do c:Disable() end end
        for _, name in ipairs({"NPCVehicles", "Traffic", "Vehicles"}) do
            local folder = Workspace:FindFirstChild(name)
            if folder then folder:ClearAllChildren() end
        end
    else
        if event then for _, c in pairs(getconnections(event.OnClientEvent)) do c:Enable() end end
    end
    return Config.TrafficBlocked
end

local function ProcessObjectForFPS(v, state)
    pcall(function()
        if v:IsA("BasePart") then v.CastShadow = not state 
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = not state end
    end)
end

local function ToggleFPSBoost()
    Config.FPS_Boosted = not Config.FPS_Boosted
    pcall(function()
        if Config.FPS_Boosted then
            Lighting.GlobalShadows = false
            if sethiddenproperty then sethiddenproperty(Lighting, "Technology", Enum.Technology.Voxel) end
            for _, v in ipairs(workspace:GetDescendants()) do ProcessObjectForFPS(v, true) end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then sethiddenproperty(Lighting, "Technology", OriginalTech) end
            for _, v in ipairs(workspace:GetDescendants()) do ProcessObjectForFPS(v, false) end
        end
    end)
    return Config.FPS_Boosted
end

-- === DRAG FUNCTION ===
local function MakeDraggable(gui)
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = gui.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then update(input) end end)
end

-- === UI CREATION ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "J9_Midnight"
ScreenGui.Parent = guiTarget

local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0, 50, 0, 50)
IconFrame.Position = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible = false 
IconFrame.Active = true
IconFrame.Parent = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
IconButton.Text = "J9"
IconButton.TextColor3 = Color3.fromRGB(0, 0, 0)
IconButton.Font = Enum.Font.GothamBlack
IconButton.TextSize = 18
IconButton.Parent = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(0, 25)
MakeDraggable(IconFrame)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 400) 
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 150)
MainFrame.Active = true
MainFrame.Parent = ScreenGui
MakeDraggable(MainFrame)

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "J9: MAGNET EDITION"
Title.TextColor3 = Color3.fromRGB(0, 255, 150)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20
MinBtn.Parent = TitleBar

MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; IconFrame.Visible = true end)
IconButton.MouseButton1Click:Connect(function() MainFrame.Visible = true; IconFrame.Visible = false end)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -30)
Content.Position = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

-- Toggles
local function MakeButton(label, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 30)
    b.Position = UDim2.new(0.05, 0, 0, 10 + (order * 35))
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    b.Text = label .. ": OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        local s = callback()
        b.Text = label .. ": " .. (s and "ON" or "OFF")
        b.BackgroundColor3 = s and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(40, 40, 45)
    end)
end

MakeButton("🧲 Checkpoint Magnet", 0, function() Config.AutoRace = not Config.AutoRace; return Config.AutoRace; end)
MakeButton("⚡ Accurate Speed Hack", 1, function() Config.SpeedHack = not Config.SpeedHack; return Config.SpeedHack; end)
MakeButton("🔥 Infinite Nitro", 2, function() Config.InfNitro = not Config.InfNitro; return Config.InfNitro; end)
MakeButton("🚫 Kill Traffic", 3, function() return ToggleTraffic(); end)
MakeButton("🖥️ XML FPS Boost", 4, function() return ToggleFPSBoost(); end)

-- Tuning Adjusters (Speed/Accel)
local TuneFrame = Instance.new("Frame")
TuneFrame.Size = UDim2.new(0.9, 0, 0, 100)
TuneFrame.Position = UDim2.new(0.05, 0, 0, 190)
TuneFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
TuneFrame.Parent = Content
Instance.new("UICorner", TuneFrame).CornerRadius = UDim.new(0, 6)

-- Speed
local SpdLabel = Instance.new("TextLabel")
SpdLabel.Text = "Top Speed: " .. Config.MaxSpeed
SpdLabel.Size = UDim2.new(1, 0, 0, 20)
SpdLabel.Position = UDim2.new(0, 0, 0.05, 0)
SpdLabel.BackgroundTransparency = 1
SpdLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SpdLabel.Font = Enum.Font.GothamBold
SpdLabel.TextSize = 12
SpdLabel.Parent = TuneFrame

local SpdMin = Instance.new("TextButton"); SpdMin.Text = "<"; SpdMin.Size = UDim2.new(0.3, 0, 0, 25); SpdMin.Position = UDim2.new(0.1, 0, 0.25, 0); SpdMin.BackgroundColor3 = Color3.fromRGB(50,50,50); SpdMin.TextColor3 = Color3.fromRGB(255,255,255); SpdMin.Parent = TuneFrame
local SpdMax = Instance.new("TextButton"); SpdMax.Text = ">"; SpdMax.Size = UDim2.new(0.3, 0, 0, 25); SpdMax.Position = UDim2.new(0.6, 0, 0.25, 0); SpdMax.BackgroundColor3 = Color3.fromRGB(50,50,50); SpdMax.TextColor3 = Color3.fromRGB(255,255,255); SpdMax.Parent = TuneFrame
Instance.new("UICorner", SpdMin); Instance.new("UICorner", SpdMax)

SpdMin.MouseButton1Click:Connect(function() Config.MaxSpeed = math.max(100, Config.MaxSpeed - 50); SpdLabel.Text = "Top Speed: " .. Config.MaxSpeed end)
SpdMax.MouseButton1Click:Connect(function() Config.MaxSpeed = Config.MaxSpeed + 50; SpdLabel.Text = "Top Speed: " .. Config.MaxSpeed end)

-- Acceleration
local AccLabel = Instance.new("TextLabel")
AccLabel.Text = "Accel (Grip): " .. Config.Acceleration
AccLabel.Size = UDim2.new(1, 0, 0, 20)
AccLabel.Position = UDim2.new(0, 0, 0.55, 0)
AccLabel.BackgroundTransparency = 1
AccLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
AccLabel.Font = Enum.Font.GothamBold
AccLabel.TextSize = 12
AccLabel.Parent = TuneFrame

local AccMin = Instance.new("TextButton"); AccMin.Text = "<"; AccMin.Size = UDim2.new(0.3, 0, 0, 25); AccMin.Position = UDim2.new(0.1, 0, 0.75, 0); AccMin.BackgroundColor3 = Color3.fromRGB(50,50,50); AccMin.TextColor3 = Color3.fromRGB(255,255,255); AccMin.Parent = TuneFrame
local AccMax = Instance.new("TextButton"); AccMax.Text = ">"; AccMax.Size = UDim2.new(0.3, 0, 0, 25); AccMax.Position = UDim2.new(0.6, 0, 0.75, 0); AccMax.BackgroundColor3 = Color3.fromRGB(50,50,50); AccMax.TextColor3 = Color3.fromRGB(255,255,255); AccMax.Parent = TuneFrame
Instance.new("UICorner", AccMin); Instance.new("UICorner", AccMax)

AccMin.MouseButton1Click:Connect(function() Config.Acceleration = math.max(0.5, Config.Acceleration - 0.5); AccLabel.Text = "Accel (Grip): " .. Config.Acceleration end)
AccMax.MouseButton1Click:Connect(function() Config.Acceleration = Config.Acceleration + 0.5; AccLabel.Text = "Accel (Grip): " .. Config.Acceleration end)

-- Status
local DebugLabel = Instance.new("TextLabel")
DebugLabel.Text = "Status: IDLE"
DebugLabel.Size = UDim2.new(1, 0, 0, 20)
DebugLabel.Position = UDim2.new(0, 0, 0, 305)
DebugLabel.BackgroundTransparency = 1
DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
DebugLabel.Font = Enum.Font.Code
DebugLabel.TextSize = 12
DebugLabel.Parent = Content

-- === 2. TRUE PHYSICS & MAGNET LOOP ===
RunService.Heartbeat:Connect(function()
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end
    currentSeat = player.Character.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then return end
    
    -- Read A-Chassis Input
    local gasVal = currentSeat.ThrottleFloat or currentSeat.Throttle or 0
    local brakeVal = 0
    local gearVal = 1
    
    local interface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if interface and interface:FindFirstChild("Values") then
        local vals = interface.Values
        if vals:FindFirstChild("Throttle") then gasVal = vals.Throttle.Value end
        if vals:FindFirstChild("Brake") then brakeVal = vals.Brake.Value end
        if vals:FindFirstChild("Gear") then gearVal = vals.Gear.Value end
        
        -- INFINITE NITRO
        if Config.InfNitro then
            for _, nName in ipairs({"Nitro", "N2O", "Boost", "Nitrous"}) do
                local nVal = vals:FindFirstChild(nName)
                if nVal and (nVal:IsA("NumberValue") or nVal:IsA("IntValue")) then
                    nVal.Value = 100 
                end
            end
        end
    end

    local isReversing = (gearVal == -1) or (brakeVal > 0.1) or (gasVal < -0.1)

    -- MAGNET LOGIC (AutoRace)
    if Config.AutoRace then
        gasVal = 1 
        
        -- Optimized Checkpoint Scanner
        local activeCP = nil
        local minDist = math.huge
        local currentPos = currentSeat.Position
        
        -- Find the dedicated folder first to prevent scanning the whole map
        local cpFolder = Workspace:FindFirstChild("Checkpoints") or Workspace:FindFirstChild("RaceNodes") or Workspace:FindFirstChild("Race")
        local objectsToScan = cpFolder and cpFolder:GetChildren() or Workspace:GetChildren()

        for _, obj in ipairs(objectsToScan) do
            if obj:IsA("BasePart") then
                local n = string.lower(obj.Name)
                if string.match(n, "check") or string.match(n, "node") or string.match(n, "hitbox") then
                    local dist = (obj.Position - currentPos).Magnitude
                    if dist < minDist and dist > 15 then
                        minDist = dist
                        activeCP = obj
                    end
                end
            end
        end

        -- Steer towards Checkpoint
        if activeCP then
            local turnForce = currentSeat:FindFirstChild("J9_MagnetTurn")
            if not turnForce then
                turnForce = Instance.new("BodyAngularVelocity", currentSeat)
                turnForce.Name = "J9_MagnetTurn"
                turnForce.MaxTorque = Vector3.new(0, currentSeat.AssemblyMass * 5000, 0)
            end
            
            local localPos = currentSeat.CFrame:PointToObjectSpace(activeCP.Position)
            local steerDirection = math.clamp(localPos.X / 20, -1, 1)
            turnForce.AngularVelocity = Vector3.new(0, -steerDirection * 4.0, 0) 
            
            DebugLabel.Text = "Status: MAGNET LOCKED"
            DebugLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
        else
            local turnForce = currentSeat:FindFirstChild("J9_MagnetTurn")
            if turnForce then turnForce:Destroy() end
            DebugLabel.Text = "Status: NO CHECKPOINTS FOUND"
            DebugLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        end
    else
        local turnForce = currentSeat:FindFirstChild("J9_MagnetTurn")
        if turnForce then turnForce:Destroy() end
    end

    -- SPEEDHACK LOGIC
    if Config.SpeedHack or Config.AutoRace then
        local origin = currentSeat.Position
        local direction = Vector3.new(0, -5, 0) 
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {player.Character, currentSeat.Parent}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local isGrounded = Workspace:Raycast(origin, direction, rayParams)

        if gasVal > Config.Deadzone and not isReversing then
            if isGrounded then
                local currentVelocity = currentSeat.AssemblyLinearVelocity
                local lookVector = currentSeat.CFrame.LookVector
                local currentSpeed = currentVelocity.Magnitude
                
                if currentSpeed < Config.MaxSpeed then
                    currentSeat.AssemblyLinearVelocity = currentVelocity + (lookVector * Config.Acceleration)
                    if not Config.AutoRace then
                        DebugLabel.Text = "Status: BOOSTING (Grounded)"
                        DebugLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                    end
                else
                    if not Config.AutoRace then
                        DebugLabel.Text = "Status: MAX SPEED REACHED"
                        DebugLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                    end
                end
            else
                if not Config.AutoRace then
                    DebugLabel.Text = "Status: AIRBORNE (Power Cut)"
                    DebugLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
            end
        else
            if not Config.AutoRace then
                if isReversing then
                    DebugLabel.Text = "Status: REVERSING"
                else
                    DebugLabel.Text = "Status: IDLE"
                end
                DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
        end
    elseif not Config.AutoRace then
        DebugLabel.Text = "Status: SCRIPT OFF"
        DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)
print("JOSEPEDOV V9.1 Loaded Successfully!")

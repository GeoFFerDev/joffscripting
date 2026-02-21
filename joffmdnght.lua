-- [[ JOSEPEDOV V6.3: ULTIMATE HIGHWAY EDITION ]] --
-- Features: Checkpoint Nav, Traffic Killer, Full Bright, Speedhack Fix, FPS Boost
-- Fixes: Car no longer auto-accelerates. Restored Kill Traffic button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- === CONFIGURATION ===
local Config = {
    SpeedHack = false,
    AutoRace = false,
    TrafficBlocked = false,
    FPS_Boosted = false,
    FullBright = false,
    PowerMultiplier = 3,
    TurnStrength = 3.0, 
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
        -- Disable incoming traffic
        if event then
            for _, c in pairs(getconnections(event.OnClientEvent)) do c:Disable() end
        end
        -- Destroy existing traffic
        local trafficFolders = {"NPCVehicles", "Traffic", "Vehicles"}
        for _, name in ipairs(trafficFolders) do
            local folder = Workspace:FindFirstChild(name)
            if folder then folder:ClearAllChildren() end
        end
    else
        -- Allow traffic
        if event then
            for _, c in pairs(getconnections(event.OnClientEvent)) do c:Enable() end
        end
    end
    return Config.TrafficBlocked
end

local function ToggleFullBright()
    Config.FullBright = not Config.FullBright
    if Config.FullBright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.ClockTime = 12
    else
        Lighting.Ambient = OriginalAmbient
        Lighting.OutdoorAmbient = OriginalAmbient
        Lighting.ClockTime = OriginalClock
    end
    return Config.FullBright
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
ScreenGui.Name = "J63_Midnight"
ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

-- THE ICON (Minimized State)
local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0, 50, 0, 50)
IconFrame.Position = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible = false 
IconFrame.Active = true
IconFrame.Parent = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
IconButton.Text = "J63"
IconButton.TextColor3 = Color3.fromRGB(0, 0, 0)
IconButton.Font = Enum.Font.GothamBlack
IconButton.TextSize = 18
IconButton.Parent = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(0, 25)
MakeDraggable(IconFrame)

-- MAIN PANEL
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 310) -- Taller to fit the 5 buttons
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 255)
MainFrame.Active = true
MainFrame.Parent = ScreenGui
MakeDraggable(MainFrame)

-- TITLE BAR
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "MIDNIGHT CHASERS"
Title.TextColor3 = Color3.fromRGB(0, 255, 255)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- MINIMIZE BUTTON
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20
MinBtn.Parent = TitleBar

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    IconFrame.Visible = true
end)

IconButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    IconFrame.Visible = false
end)

-- CONTENT FRAME (Buttons)
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -30)
Content.Position = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function MakeButton(label, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 35)
    b.Position = UDim2.new(0.05, 0, 0, 10 + (order * 40))
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
        b.BackgroundColor3 = s and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(40, 40, 45)
    end)
end

MakeButton("⚡ Speed Hack", 0, function() Config.SpeedHack = not Config.SpeedHack return Config.SpeedHack end)
MakeButton("🏎️ Seq. AutoRace", 1, function() Config.AutoRace = not Config.AutoRace return Config.AutoRace end)
MakeButton("🚫 Kill Traffic", 2, function() return ToggleTraffic() end)
MakeButton("☀️ Full Bright", 3, function() return ToggleFullBright() end)
MakeButton("🖥️ XML FPS Boost", 4, function() return ToggleFPSBoost() end)

-- Status Text
local DebugLabel = Instance.new("TextLabel")
DebugLabel.Text = "Status: IDLE"
DebugLabel.Size = UDim2.new(1, 0, 0, 20)
DebugLabel.Position = UDim2.new(0, 0, 0, 215)
DebugLabel.BackgroundTransparency = 1
DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
DebugLabel.Font = Enum.Font.Code
DebugLabel.TextSize = 12
DebugLabel.Parent = Content

-- === 3. PHYSICS & NAVIGATION LOOP ===
RunService.Heartbeat:Connect(function()
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end
    currentSeat = player.Character.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then return end
    
    -- READ A-CHASSIS INTERFACE (Fixes Auto-Acceleration Bug)
    local gasVal = currentSeat.ThrottleFloat or currentSeat.Throttle or 0
    local brakeVal = 0
    local gearVal = 1
    local steerVal = currentSeat.SteerFloat or currentSeat.Steer or 0
    
    local interface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if interface and interface:FindFirstChild("Values") then
        local vals = interface.Values
        if vals:FindFirstChild("Throttle") then gasVal = vals.Throttle.Value end
        if vals:FindFirstChild("Brake") then brakeVal = vals.Brake.Value end
        if vals:FindFirstChild("Gear") then gearVal = vals.Gear.Value end
        if vals:FindFirstChild("SteerT") then steerVal = vals.SteerT.Value end
    end

    local isReversing = (gearVal == -1) or (brakeVal > 0.1) or (gasVal < -0.1)

    local thrust = currentSeat:FindFirstChild("J63_Thrust")
    local turn = currentSeat:FindFirstChild("J63_Turn")
    
    if Config.AutoRace or Config.SpeedHack then
        if not thrust then
            local att = Instance.new("Attachment", currentSeat)
            att.Name = "J63_Att"
            thrust = Instance.new("VectorForce", currentSeat)
            thrust.Name = "J63_Thrust"
            thrust.Attachment0 = att
            thrust.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
            
            turn = Instance.new("BodyAngularVelocity", currentSeat)
            turn.Name = "J63_Turn"
            turn.MaxTorque = Vector3.new(0, currentSeat.AssemblyMass * 5000, 0)
        end

        -- NAVIGATION LOGIC
        local targetSteer = steerVal
        if Config.AutoRace then
            gasVal = 1 -- Force Gas ONLY for AutoRace
            local checkpoints = Workspace:FindFirstChild("Checkpoints") or Workspace:FindFirstChild("RaceNodes")
            local nextCP = nil
            local minDist = math.huge
            
            if checkpoints then
                for _, cp in ipairs(checkpoints:GetChildren()) do
                    if cp:IsA("BasePart") then
                        local d = (cp.Position - currentSeat.Position).Magnitude
                        if d < minDist and d > 20 then
                            minDist = d
                            nextCP = cp
                        end
                    end
                end
            end
            
            if nextCP then
                local localPos = currentSeat.CFrame:PointToObjectSpace(nextCP.Position)
                targetSteer = math.clamp(localPos.X / 20, -1, 1)
                DebugLabel.Text = "Status: AUTO-NAVIGATING"
            else
                DebugLabel.Text = "Status: NO CHECKPOINTS FOUND"
            end
        else
            DebugLabel.Text = "Status: SPEEDHACK READY"
        end

        -- APPLY FORCES (Strict Checks for Acceleration)
        if gasVal > Config.Deadzone and not isReversing then
            local force = currentSeat.AssemblyMass * Config.PowerMultiplier * 50
            thrust.Force = Vector3.new(0, 0, -force)
            turn.AngularVelocity = Vector3.new(0, -targetSteer * Config.TurnStrength, 0)
            if not Config.AutoRace then DebugLabel.Text = "Status: BOOSTING" end
        else
            -- IDLE OR REVERSING -> KILLS FORCES INSTANTLY
            thrust.Force = Vector3.new(0,0,0)
            turn.AngularVelocity = Vector3.new(0,0,0)
            if isReversing then 
                DebugLabel.Text = "Status: REVERSING" 
            elseif not Config.AutoRace then 
                DebugLabel.Text = "Status: IDLE" 
            end
        end
    elseif thrust then
        -- CLEANUP WHEN OFF
        thrust:Destroy()
        if turn then turn:Destroy() end
        local att = currentSeat:FindFirstChild("J63_Att")
        if att then att:Destroy() end
        DebugLabel.Text = "Status: SCRIPT OFF"
    end
end)

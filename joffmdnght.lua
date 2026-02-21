-- [[ JOSEPEDOV V6.1: SEQUENTIAL AUTORACE ]] --
-- Features: Checkpoint Navigation, Full Bright, Adaptive Speed, XML FPS Boost
-- Optimized for Delta | Revised for high-accuracy checkpoint tracking.

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
    FPS_Boosted = false,
    FullBright = false,
    PowerMultiplier = 3,
    TurnStrength = 3.0, -- Increased for tighter checkpoint turns
    Deadzone = 0.1
}

-- === STATE ===
local currentSeat = nil
local currentCar = nil
local OriginalTech = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalClock = Lighting.ClockTime
local FPSConnection = nil

-- === 1. FULL BRIGHT TOGGLE ===
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

-- === 2. FPS BOOSTER (XML Optimized) ===
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

-- === UI CREATION (Condensed for V6.1) ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "J61_Midnight"
ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 300)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 255)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local function MakeButton(label, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 35)
    b.Position = UDim2.new(0.05, 0, 0, 40 + (order * 40))
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    b.Text = label .. ": OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = MainFrame
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(function()
        local s = callback()
        b.Text = label .. ": " .. (s and "ON" or "OFF")
        b.BackgroundColor3 = s and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(40, 40, 45)
    end)
end

MakeButton("⚡ Speed Hack", 0, function() Config.SpeedHack = not Config.SpeedHack return Config.SpeedHack end)
MakeButton("🏎️ Sequential AutoRace", 1, function() Config.AutoRace = not Config.AutoRace return Config.AutoRace end)
MakeButton("☀️ Full Bright", 2, function() return ToggleFullBright() end)
MakeButton("🖥️ XML FPS Boost", 3, function() return ToggleFPSBoost() end)

-- === 3. PHYSICS & NAVIGATION LOOP ===
RunService.Heartbeat:Connect(function()
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end
    currentSeat = player.Character.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then return end
    
    local throttle = 0
    local steer = 0
    
    -- READ A-CHASSIS INTERFACE
    local interface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if interface and interface:FindFirstChild("Values") then
        throttle = interface.Values.Throttle.Value
        steer = interface.Values.SteerT.Value
    end

    local thrust = currentSeat:FindFirstChild("J61_Thrust")
    local turn = currentSeat:FindFirstChild("J61_Turn")
    
    if Config.AutoRace or Config.SpeedHack then
        if not thrust then
            local att = Instance.new("Attachment", currentSeat)
            thrust = Instance.new("VectorForce", currentSeat)
            thrust.Name = "J61_Thrust"
            thrust.Attachment0 = att
            thrust.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
            
            turn = Instance.new("BodyAngularVelocity", currentSeat)
            turn.Name = "J61_Turn"
            turn.MaxTorque = Vector3.new(0, currentSeat.AssemblyMass * 5000, 0)
        end

        -- NAVIGATION LOGIC (Find Nearest/Next Checkpoint)
        local targetSteer = steer
        if Config.AutoRace then
            throttle = 1 -- Max gas for AutoRace
            local checkpoints = Workspace:FindFirstChild("Checkpoints") or Workspace:FindFirstChild("RaceNodes")
            local nextCP = nil
            local minDist = math.huge
            
            if checkpoints then
                for _, cp in ipairs(checkpoints:GetChildren()) do
                    local d = (cp.Position - currentSeat.Position).Magnitude
                    if d < minDist and d > 20 then -- Don't target current one
                        minDist = d
                        nextCP = cp
                    end
                end
            end
            
            if nextCP then
                local localPos = currentSeat.CFrame:PointToObjectSpace(nextCP.Position)
                targetSteer = math.clamp(localPos.X / 20, -1, 1) -- Steering Bias toward Checkpoint
            end
        end

        -- APPLY FORCES
        if throttle > Config.Deadzone then
            local force = currentSeat.AssemblyMass * Config.PowerMultiplier * 50
            thrust.Force = Vector3.new(0, 0, -force)
            turn.AngularVelocity = Vector3.new(0, -targetSteer * Config.TurnStrength, 0)
        else
            thrust.Force = Vector3.new(0,0,0)
            turn.AngularVelocity = Vector3.new(0,0,0)
        end
    elseif thrust then
        thrust:Destroy()
        if turn then turn:Destroy() end
    end
end)

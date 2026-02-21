-- [[ JOSEPEDOV V7: PURE RACING EDITION ]] --
-- Features: A-Chassis Velocity Scaling, Ground Detection, FPS Boost, Traffic Kill
-- Fixes: Removed floaty VectorForce. Car now grips the road and handles accurately.

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
    TrafficBlocked = false,
    FPS_Boosted = false,
    FullBright = false,
    Acceleration = 3.0,  -- How fast it reaches top speed
    MaxSpeed = 400,      -- Top speed in studs per second (approx 280 MPH)
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
ScreenGui.Name = "J7_Midnight"
ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0, 50, 0, 50)
IconFrame.Position = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible = false 
IconFrame.Active = true
IconFrame.Parent = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
IconButton.Text = "J7"
IconButton.TextColor3 = Color3.fromRGB(0, 0, 0)
IconButton.Font = Enum.Font.GothamBlack
IconButton.TextSize = 18
IconButton.Parent = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(0, 25)
MakeDraggable(IconFrame)

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 260)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(255, 100, 0)
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
Title.Text = "J7: PURE RACING"
Title.TextColor3 = Color3.fromRGB(255, 100, 0)
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
        b.BackgroundColor3 = s and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(40, 40, 45)
    end)
end

MakeButton("⚡ Accurate Speed Hack", 0, function() Config.SpeedHack = not Config.SpeedHack return Config.SpeedHack end)
MakeButton("🚫 Kill Traffic", 1, function() return ToggleTraffic() end)
MakeButton("☀️ Full Bright", 2, function() return ToggleFullBright() end)
MakeButton("🖥️ XML FPS Boost", 3, function() return ToggleFPSBoost() end)

local DebugLabel = Instance.new("TextLabel")
DebugLabel.Text = "Status: IDLE"
DebugLabel.Size = UDim2.new(1, 0, 0, 20)
DebugLabel.Position = UDim2.new(0, 0, 0, 180)
DebugLabel.BackgroundTransparency = 1
DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
DebugLabel.Font = Enum.Font.Code
DebugLabel.TextSize = 12
DebugLabel.Parent = Content

-- === 2. TRUE PHYSICS SPEEDHACK ===
RunService.Heartbeat:Connect(function(deltaTime)
    if not player.Character or not player.Character:FindFirstChild("Humanoid") then return end
    currentSeat = player.Character.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then return end
    
    -- Read A-Chassis
    local gasVal = currentSeat.ThrottleFloat or currentSeat.Throttle or 0
    local brakeVal = 0
    local gearVal = 1
    
    local interface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if interface and interface:FindFirstChild("Values") then
        local vals = interface.Values
        if vals:FindFirstChild("Throttle") then gasVal = vals.Throttle.Value end
        if vals:FindFirstChild("Brake") then brakeVal = vals.Brake.Value end
        if vals:FindFirstChild("Gear") then gearVal = vals.Gear.Value end
    end

    local isReversing = (gearVal == -1) or (brakeVal > 0.1) or (gasVal < -0.1)

    if Config.SpeedHack then
        -- GROUND CHECK: Only apply speed if tires are touching the road
        local origin = currentSeat.Position
        local direction = Vector3.new(0, -5, 0) -- Cast 5 studs straight down
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {player.Character, currentSeat.Parent}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local isGrounded = Workspace:Raycast(origin, direction, rayParams)

        if gasVal > Config.Deadzone and not isReversing then
            if isGrounded then
                -- Accurate Velocity Scaling
                local currentVelocity = currentSeat.AssemblyLinearVelocity
                local lookVector = currentSeat.CFrame.LookVector
                local currentSpeed = currentVelocity.Magnitude
                
                -- Only boost if under Max Speed
                if currentSpeed < Config.MaxSpeed then
                    -- Smoothly add speed in the direction the car is pointing
                    currentSeat.AssemblyLinearVelocity = currentVelocity + (lookVector * Config.Acceleration)
                    DebugLabel.Text = "Status: BOOSTING (Grounded)"
                    DebugLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                else
                    DebugLabel.Text = "Status: MAX SPEED REACHED"
                    DebugLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                end
            else
                DebugLabel.Text = "Status: AIRBORNE (Power Cut)"
                DebugLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        else
            if isReversing then
                DebugLabel.Text = "Status: REVERSING"
            else
                DebugLabel.Text = "Status: IDLE"
            end
            DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    else
        DebugLabel.Text = "Status: SCRIPT OFF"
        DebugLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

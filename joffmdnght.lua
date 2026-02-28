--[[
  JOSEPEDOV V24c — MIDNIGHT CHASERS
  Highway AutoRace exploit | Fluent UI | 3D Homing Engine

  ══════════════════════════════════════════════════════════════
  V24c FIX — 3D HOMING & DOWNHILL DIVING
  ══════════════════════════════════════════════════════════════
  - Removed independent 2D XZ steering. The car now uses a true 3D 
    homing vector to the gate target.
  - If a gate is downhill, the car will actively dive at full speed 
    towards it, perfectly tracking elevation drops without overshooting.
  - Terrain raycasts now act as a "Repulsion Cushion" rather than a 
    strict altitude lock. The car is free to dive aggressively unless 
    it is within 6 studs of crashing into the terrain.
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

-- Anti-overlap: destroy any previous instance
if guiTarget:FindFirstChild("MC_V22") then guiTarget.MC_V22:Destroy() end

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
subLbl.Text   = "JOSEPEDOV V24c  ·  3D HOMING EDITION"
subLbl.TextColor3 = Color3.fromRGB(60,130,100)
subLbl.Font   = Enum.Font.GothamBold
subLbl.TextSize = 14

-- Route strip
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

-- Speed lines
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

-- Camera flythrough
local cam = Workspace.CurrentCamera
local prevCamType = cam.CameraType
cam.CameraType = Enum.CameraType.Scriptable
local CAM_ROUTE = {
    {CFrame.lookAt(Vector3.new(3180,75,1100),  Vector3.new(2900,0,700))},
    {CFrame.lookAt(Vector3.new(2900,40,600),   Vector3.new(2513,0,411))},
    {CFrame.lookAt(Vector3.new(2650,55,480),   Vector3.new(2981,0,537))},
    {CFrame.lookAt(Vector3.new(3050,45,450),   Vector3.new(3485,0,622))},
    {CFrame.lookAt(Vector3.new(3380,60,750),   Vector3.new(3485,0,622))},
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
        if d.dot then TweenService:Create(d.dot,TweenInfo.new(0.25),{BackgroundColor3=col}):Play() end
        if d.lbl then d.lbl.TextColor3 = tc end
        if d.line then TweenService:Create(d.line,TweenInfo.new(0.25),{BackgroundColor3=col}):Play() end
    end
end

-- ─────────────────────────────────────────────────────────────
--  CONFIG & STATE
-- ─────────────────────────────────────────────────────────────
SetProg(5, "Reading config...", 1)
task.wait(0.3)

local Config = {
    SpeedHack      = false,
    AutoRace       = false,
    InfNitro       = false,
    TrafficBlocked = false,
    FPS_Boosted    = false,
    FullBright     = false,
    Acceleration   = 3.0,
    MaxSpeed       = 320,
    AutoRaceSpeed  = 350,
    Deadzone       = 0.1,
}
local AR_SPEED_CAP = 600

local OriginalTech    = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoor = Lighting.OutdoorAmbient
local OriginalClock   = Lighting.ClockTime

SetProg(20, "Scanning highway route...", 2)
task.wait(0.4)

local currentSeat    = nil
local currentCar     = nil
local disabledCar    = nil
local AR_STATE       = "IDLE"
local raceThread     = nil
local raceOwnsStatus = false

local QUEUE_POS = Vector3.new(3260.5, 12, 1015.7)

-- ─────────────────────────────────────────────────────────────
--  COLLISION HELPERS
-- ─────────────────────────────────────────────────────────────
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
            if p:IsA("BasePart") then p.CanCollide = false end
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
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
    disabledCar = nil
end

SetProg(40, "Mapping checkpoint gates...", 3)
task.wait(0.4)

-- ─────────────────────────────────────────────────────────────
--  RACE HELPERS
-- ─────────────────────────────────────────────────────────────
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
    for _,child in ipairs(cpVal:GetChildren()) do
        if child:IsA("BasePart") then
            local idx = tonumber(child.Name)
            if idx and idx < bestIdx
               and idx ~= skipIdx
               and not (clearedSet and clearedSet[idx]) then
                best, bestIdx = child, idx
            end
        end
    end
    return best, bestIdx
end

SetProg(60, "Calibrating 3D homing engine...", 4)
task.wait(0.4)

-- ─────────────────────────────────────────────────────────────
--  STATUS
-- ─────────────────────────────────────────────────────────────
local _statusLbl = nil
local function SetStatus(text, r, g, b)
    if _statusLbl then
        _statusLbl.Text = "  " .. text
        _statusLbl.TextColor3 = (r and Color3.fromRGB(r,g,b)) or Color3.fromRGB(150,150,150)
    end
end

-- ─────────────────────────────────────────────────────────────
--  3D HOMING ENGINE (V24c)
-- ─────────────────────────────────────────────────────────────
local ROAD_HOVER  = 4     
local GATE_INSIDE = 0.30  
local PUNCH_DIST  = 16    

local function DoRaceLoop(uuidFolder)
    raceOwnsStatus = true
    DisableCollisions(currentCar)

    local clearedSet = {}
    local skipIdx    = nil

    local rcParams = RaycastParams.new()
    rcParams.FilterType = Enum.RaycastFilterType.Exclude

    while Config.AutoRace and AR_STATE == "RACING" do

        local gatePart, cpIdx
        local waitForCP = tick() + 15
        repeat
            gatePart, cpIdx = FindNextCP(uuidFolder, clearedSet, skipIdx)
            if not gatePart then task.wait(0.1) end
        until gatePart or tick() > waitForCP
              or not Config.AutoRace or AR_STATE ~= "RACING"

        if not gatePart then
            SetStatus("🏁 Race complete! Returning to queue...", 0, 220, 130)
            task.wait(2)
            RestoreCollisions()
            raceOwnsStatus = false
            local ch2 = player.Character
            if ch2 and ch2:FindFirstChild("Humanoid") then
                local seat2 = ch2.Humanoid.SeatPart
                if seat2 and seat2:IsA("VehicleSeat") then
                    local car2  = seat2.Parent
                    local root2 = car2.PrimaryPart or seat2
                    if root2 then
                        task.wait(0.1)
                        car2:PivotTo(CFrame.new(QUEUE_POS))
                        root2.AssemblyLinearVelocity  = Vector3.zero
                        root2.AssemblyAngularVelocity = Vector3.zero
                        SetStatus("⏎ Back at queue — drive in to race again!", 0, 190, 255)
                    end
                end
            end
            break
        end

        skipIdx = nil

        local cpCleared = false
        local cpConn    = nil
        local cpParent  = gatePart.Parent
        if cpParent then
            cpConn = cpParent.ChildRemoved:Connect(function(removed)
                if removed == gatePart then cpCleared = true end
            end)
        end

        local gateTargetY = gatePart.Position.Y + gatePart.Size.Y * GATE_INSIDE
        local gateXZ = Vector3.new(gatePart.Position.X, 0, gatePart.Position.Z)
        local targetPos = Vector3.new(gateXZ.X, gateTargetY, gateXZ.Z)

        local flyLimit  = tick() + 30
        local arSpeed   = math.clamp(Config.AutoRaceSpeed, 50, AR_SPEED_CAP)
        local clearDist = math.max(28, arSpeed * 0.07)

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
            local distXZ= (gateXZ - myXZ).Magnitude

            -- ── SMOOTH PASS-THROUGH ────────────────────────────────────
            if distXZ <= PUNCH_DIST then
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

            -- ── 3D HOMING VECTOR ───────────────────────────────────────
            -- Calculates a true 3D straight line directly to the gate.
            local dir3D = (targetPos - myPos).Unit
            local desiredVelX = dir3D.X * arSpeed
            local desiredVelY = dir3D.Y * arSpeed
            local desiredVelZ = dir3D.Z * arSpeed

            -- ── TERRAIN REPULSION CUSHIONS ─────────────────────────────
            local roadY = nil
            local dirXZ = (gateXZ - myXZ).Unit
            
            -- Floor directly below
            local floorRay = Workspace:Raycast(myPos + Vector3.new(0, 50, 0), Vector3.new(0, -250, 0), rcParams)
            if floorRay then roadY = floorRay.Position.Y end
            
            -- Floor ahead to anticipate hills
            local aheadPos = myPos + (dirXZ * 60)
            local aheadRay = Workspace:Raycast(aheadPos + Vector3.new(0, 50, 0), Vector3.new(0, -250, 0), rcParams)
            if aheadRay then
                if roadY then
                    roadY = math.max(roadY, aheadRay.Position.Y)
                else
                    roadY = aheadRay.Position.Y
                end
            end

            -- Apply Magnetic Floor Cushion
            if roadY then
                local safeFloor = roadY + ROAD_HOVER
                local cushionY = safeFloor + 6
                
                -- If we dip too close to the floor, push the vertical velocity upward.
                if myPos.Y < cushionY then
                    local pushUp = (cushionY - myPos.Y) * 15
                    desiredVelY = math.max(desiredVelY, pushUp)
                end
                
                -- Absolute bottom out prevention
                if myPos.Y < safeFloor then
                    desiredVelY = math.max(desiredVelY, (safeFloor - myPos.Y) * 30)
                end
            end

            -- Apply Magnetic Ceiling Cushion (Bridges/Tunnels)
            local ceilHit = Workspace:Raycast(myPos, Vector3.new(0, 30, 0), rcParams)
            if ceilHit then
                local safeCeil = ceilHit.Position.Y - 5
                local cushionY = safeCeil - 5
                
                if myPos.Y > cushionY then
                    local pushDown = (myPos.Y - cushionY) * 15
                    desiredVelY = math.min(desiredVelY, -pushDown)
                end
            end

            -- Execute the movement
            root.AssemblyLinearVelocity = Vector3.new(desiredVelX, desiredVelY, desiredVelZ)
            root.AssemblyAngularVelocity = Vector3.zero

            SetStatus(string.format("→ CP #%d  %.0f studs  Y%.1f▶%.1f",
                cpIdx, distXZ, myPos.Y, gateTargetY), 0, 190, 255)
            task.wait()
        end

        -- ⑤ Cleanup
        if cpConn then pcall(function() cpConn:Disconnect() end) end
        if not Config.AutoRace or AR_STATE ~= "RACING" then break end

        if cpCleared then
            clearedSet[cpIdx] = true
            SetStatus(string.format("✓ CP #%d cleared  Y=%.1f", cpIdx, gateTargetY), 0, 230, 100)
            task.wait(0.2)
        else
            SetStatus(string.format("CP #%d timed out — skipping", cpIdx), 255, 150, 0)
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
--  FEATURE HELPERS
-- ─────────────────────────────────────────────────────────────
local function ToggleTraffic()
    Config.TrafficBlocked = not Config.TrafficBlocked
    local ev = ReplicatedStorage:FindFirstChild("CreateNPCVehicle")
    if Config.TrafficBlocked then
        if ev then for _,c in pairs(getconnections(ev.OnClientEvent)) do c:Disable() end end
        for _,n in ipairs({"NPCVehicles","Traffic","Vehicles"}) do
            local f=Workspace:FindFirstChild(n);
            if f then f:ClearAllChildren() end
        end
    else
        if ev then for _,c in pairs(getconnections(ev.OnClientEvent)) do c:Enable() end end
    end
    return Config.TrafficBlocked
end

local function ToggleFPSBoost()
    Config.FPS_Boosted = not Config.FPS_Boosted
    pcall(function()
        if Config.FPS_Boosted then
            Lighting.GlobalShadows = false
            if sethiddenproperty then
                sethiddenproperty(Lighting,"Technology",Enum.Technology.Voxel)
            end
            for _,v in ipairs(workspace:GetDescendants()) do pcall(function()
                if v:IsA("BasePart") then v.CastShadow=false
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false end
            end) end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then
                sethiddenproperty(Lighting,"Technology",OriginalTech)
            end
            for _,v in ipairs(workspace:GetDescendants()) do pcall(function()
                if v:IsA("BasePart") then v.CastShadow=true
                elseif v:IsA("Trail") or v:IsA("ParticleEmitter") then v.Enabled=true end
            end) end
        end
    end)
    return Config.FPS_Boosted
end

local function ToggleFullBright()
    Config.FullBright = not Config.FullBright
    if not Config.FullBright then
        Lighting.Ambient=OriginalAmbient
        Lighting.OutdoorAmbient=OriginalOutdoor
        Lighting.ClockTime=OriginalClock
    end
    return Config.FullBright
end

SetProg(80, "Building interface...", 4)
task.wait(0.3)

-- ═══════════════════════════════════════════════════════════════
--  FLUENT UI  (based on Fluent Local UI Framework template)
-- ═══════════════════════════════════════════════════════════════

-- Theme (Fluent Green accent matching the game's green neon aesthetic)
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

-- ── Toggle icon (minimised state) ──
local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size   = UDim2.new(0,45,0,45)
ToggleIcon.Position = UDim2.new(0.5,-22,0.05,0)
ToggleIcon.BackgroundColor3 = Theme.Background
ToggleIcon.BackgroundTransparency = 0.1
ToggleIcon.Text   = "🏁"
ToggleIcon.TextSize = 22
ToggleIcon.Visible = false
Instance.new("UICorner",ToggleIcon).CornerRadius = UDim.new(1,0)
local IconStroke = Instance.new("UIStroke",ToggleIcon)
IconStroke.Color = Theme.Accent
IconStroke.Thickness = 2

-- ── Main window ──
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size   = UDim2.new(0,420,0,280)
MainFrame.Position = UDim2.new(0.5,-210,0.5,-140)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BackgroundTransparency = 0.08
MainFrame.Active = true
Instance.new("UICorner",MainFrame).CornerRadius = UDim.new(0,10)
local MainStroke = Instance.new("UIStroke",MainFrame)
MainStroke.Color = Theme.Stroke
MainStroke.Transparency = 0.4

-- ── Top bar ──
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1,0,0,32)
TopBar.BackgroundTransparency = 1

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size   = UDim2.new(0.6,0,1,0)
TitleLbl.Position = UDim2.new(0,14,0,0)
TitleLbl.Text   = "🏁  MIDNIGHT CHASERS  V24c"
TitleLbl.Font   = Enum.Font.GothamBold
TitleLbl.TextColor3 = Theme.Accent
TitleLbl.TextSize = 12
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.BackgroundTransparency = 1

-- Separator line under top bar
local Sep = Instance.new("Frame",MainFrame)
Sep.Size = UDim2.new(1,-20,0,1)
Sep.Position = UDim2.new(0,10,0,32)
Sep.BackgroundColor3 = Theme.Stroke
Sep.BorderSizePixel = 0

-- Window controls
local function AddCtrl(text, pos, color, cb)
    local b = Instance.new("TextButton", TopBar)
    b.Size   = UDim2.new(0,28,0,22)
    b.Position = pos
    b.BackgroundTransparency = 1
    b.Text   = text
    b.TextColor3 = color
    b.Font   = Enum.Font.GothamBold
    b.TextSize = 12
    b.MouseButton1Click:Connect(cb)
    return b
end
AddCtrl("✕", UDim2.new(1,-32,0.5,-11), Color3.fromRGB(255,80,80),
    function() ScreenGui:Destroy() end)
AddCtrl("—", UDim2.new(1,-62,0.5,-11), Theme.SubText, function()
    MainFrame.Visible = false
    ToggleIcon.Visible = true
end)
ToggleIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    ToggleIcon.Visible = false
end)

-- ── Native drag ──
local function EnableDrag(obj, handle)
    local drag, ipt, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; start=i.Position; startPos=obj.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then drag=false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement
                  or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position - start
            obj.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset+d.X,
                startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end
EnableDrag(MainFrame, TopBar)
EnableDrag(ToggleIcon, ToggleIcon)

-- ── Sidebar ──
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size   = UDim2.new(0,108,1,-33)
Sidebar.Position = UDim2.new(0,0,0,33)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.4
Sidebar.BorderSizePixel = 0
Instance.new("UICorner",Sidebar).CornerRadius = UDim.new(0,10)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0,5)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding",Sidebar).PaddingTop = UDim.new(0,10)

-- ── Content area ──
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size   = UDim2.new(1,-118,1,-38)
ContentArea.Position = UDim2.new(0,113,0,38)
ContentArea.BackgroundTransparency = 1

-- ── Tab system ──
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
    Instance.new("UIPadding",tf).PaddingTop = UDim.new(0,6)

    local tb = Instance.new("TextButton", Sidebar)
    tb.Size   = UDim2.new(0.92,0,0,30)
    tb.BackgroundColor3 = Theme.Accent
    tb.BackgroundTransparency = 1
    tb.Text   = "  "..icon.." "..name
    tb.TextColor3 = Theme.SubText
    tb.Font   = Enum.Font.GothamMedium
    tb.TextSize = 12
    tb.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner",tb).CornerRadius = UDim.new(0,6)

    local ind = Instance.new("Frame", tb)
    ind.Size  = UDim2.new(0,3,0.6,0)
    ind.Position = UDim2.new(0,2,0.2,0)
    ind.BackgroundColor3 = Theme.Accent
    ind.Visible = false
    Instance.new("UICorner",ind).CornerRadius = UDim.new(1,0)

    tb.MouseButton1Click:Connect(function()
        for _,t in pairs(AllTabs) do t.Frame.Visible = false end
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

    table.insert(AllTabs,    {Frame = tf})
    table.insert(AllTabBtns, {Btn = tb, Ind = ind})
    return tf
end

-- ── UI Components ──────────────────────────────────────────────

-- Section label
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

-- Toggle row (Fluent pill style)
local function FluentToggle(parent, title, desc, callback)
    local state = false
    local btn = Instance.new("TextButton", parent)
    btn.Size   = UDim2.new(0.98,0,0,48)
    btn.BackgroundColor3 = Theme.Button
    btn.Text   = ""
    btn.AutoButtonColor = false
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke",btn).Color = Theme.Stroke

    local tx = Instance.new("TextLabel",btn)
    tx.Size   = UDim2.new(0.72,0,0.5,0)
    tx.Position = UDim2.new(0,10,0,5)
    tx.Text   = title
    tx.Font   = Enum.Font.GothamMedium
    tx.TextColor3 = Theme.Text
    tx.TextSize = 12
    tx.TextXAlignment = Enum.TextXAlignment.Left
    tx.BackgroundTransparency = 1

    local sub = Instance.new("TextLabel",btn)
    sub.Size  = UDim2.new(0.72,0,0.5,0)
    sub.Position = UDim2.new(0,10,0.5,0)
    sub.Text  = desc
    sub.Font  = Enum.Font.Gotham
    sub.TextColor3 = Theme.SubText
    sub.TextSize = 10
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.BackgroundTransparency = 1

    local pill = Instance.new("Frame",btn)
    pill.Size   = UDim2.new(0,42,0,22)
    pill.Position = UDim2.new(1,-52,0.5,-11)
    pill.BackgroundColor3 = Theme.Button
    Instance.new("UICorner",pill).CornerRadius = UDim.new(1,0)
    local ps = Instance.new("UIStroke",pill)
    ps.Color = Theme.Stroke; ps.Thickness = 1

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

-- Drag slider (full-width track, snap to 10)
local function FluentSlider(parent, label, minV, maxV, defaultV, sweetspot, getV, setV)
    local row = Instance.new("Frame", parent)
    row.Size  = UDim2.new(0.98,0,0,62)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel  = 0
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke",row).Color = Theme.Stroke

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
    Instance.new("UICorner",track).CornerRadius = UDim.new(0,3)

    local fill = Instance.new("Frame",track)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0,0,1,0)
    Instance.new("UICorner",fill).CornerRadius = UDim.new(0,3)

    local knob = Instance.new("Frame",track)
    knob.Size = UDim2.new(0,14,0,14)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    Instance.new("UICorner",knob).CornerRadius = UDim.new(0,7)

    -- Sweet-spot tick
    if sweetspot then
        local sp = (sweetspot-minV)/(maxV-minV)
        local stk = Instance.new("Frame",track)
        stk.Size  = UDim2.new(0,2,1,6)
        stk.Position = UDim2.new(sp,-1,0,-3)
        stk.BackgroundColor3 = Theme.Orange
        stk.BorderSizePixel = 0
    end

    local minTxt = Instance.new("TextLabel",row)
    minTxt.Size = UDim2.new(0,30,0,10); minTxt.Position=UDim2.new(0,10,0,48)
    minTxt.BackgroundTransparency=1; minTxt.Text=tostring(minV)
    minTxt.TextColor3=Theme.SubText; minTxt.Font=Enum.Font.Code; minTxt.TextSize=8
    minTxt.TextXAlignment = Enum.TextXAlignment.Left

    local maxTxt = Instance.new("TextLabel",row)
    maxTxt.Size = UDim2.new(0,40,0,10); maxTxt.Position=UDim2.new(1,-50,0,48)
    maxTxt.BackgroundTransparency=1; maxTxt.Text=tostring(maxV).." MAX"
    maxTxt.TextColor3=Theme.Red; maxTxt.Font=Enum.Font.Code; maxTxt.TextSize=8
    maxTxt.TextXAlignment = Enum.TextXAlignment.Right

    local function updateFromPct(pct)
        pct = math.clamp(pct,0,1)
        local raw = minV + pct*(maxV-minV)
        local val = math.clamp(math.round(raw/10)*10, minV, maxV)
        setV(val)
        local rp  = (val-minV)/(maxV-minV)
        fill.Size = UDim2.new(rp,0,1,0)
        knob.Position = UDim2.new(rp,-7,0.5,-7)
        local col
        if val >= maxV then
            col=Theme.Red
        elseif sweetspot and val > sweetspot then
            col=Theme.Orange
        else
            col=Theme.Accent
        end
        valLbl.Text = val.." st/s"
        valLbl.TextColor3 = col
        fill.BackgroundColor3 = col
        knob.BackgroundColor3 = val>=maxV and Theme.Red or Color3.new(1,1,1)
    end
    updateFromPct((defaultV-minV)/(maxV-minV))

    local dragging = false
    local function applyInput(inp)
        local ax = track.AbsolutePosition.X
        local aw = track.AbsoluteSize.X
        updateFromPct((inp.Position.X-ax)/aw)
    end
    knob.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true
        end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; applyInput(i)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement
                      or i.UserInputType==Enum.UserInputType.Touch) then
            applyInput(i)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
end

-- Simple +/- stepper (for tuning values)
local function FluentStepper(parent, label, fmt, getV, decV, incV)
    local row = Instance.new("Frame",parent)
    row.Size  = UDim2.new(0.98,0,0,38)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel  = 0
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke",row).Color = Theme.Stroke

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
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
        return b
    end
    mkB("<",-62).MouseButton1Click:Connect(function()
        decV(); lbl2.Text=string.format(fmt,getV())
    end)
    mkB(">", -30).MouseButton1Click:Connect(function()
        incV(); lbl2.Text=string.format(fmt,getV())
    end)
end

-- ── TABS ──────────────────────────────────────────────────────
local TabRace  = CreateTab("Race",  "🏁")
local TabCar   = CreateTab("Car",   "🚗")
local TabWorld = CreateTab("World", "🌍")
local TabMisc  = CreateTab("Misc",  "⚙️")

-- ── RACE TAB ──────────────────────────────────────────────────
Section(TabRace, "  AUTO RACE")

-- AutoRace hero row (big clickable row with status dot)
local arRow = Instance.new("TextButton", TabRace)
arRow.Size  = UDim2.new(0.98,0,0,52)
arRow.BackgroundColor3 = Theme.Button
arRow.Text  = ""
arRow.AutoButtonColor = false
Instance.new("UICorner",arRow).CornerRadius = UDim.new(0,8)
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
arSub.Text   = "City Highway Race  ·  3D Homing V24c"
arSub.TextColor3 = Theme.SubText
arSub.Font   = Enum.Font.Gotham
arSub.TextSize = 10
arSub.TextXAlignment = Enum.TextXAlignment.Left

local arDot = Instance.new("Frame",arRow)
arDot.Size  = UDim2.new(0,10,0,10)
arDot.Position = UDim2.new(1,-18,0.5,-5)
arDot.BackgroundColor3 = Theme.SubText
Instance.new("UICorner",arDot).CornerRadius = UDim.new(0,5)

-- Status label (below hero row)
local statRow = Instance.new("Frame", TabRace)
statRow.Size  = UDim2.new(0.98,0,0,32)
statRow.BackgroundColor3 = Color3.fromRGB(20,20,24)
statRow.BorderSizePixel  = 0
Instance.new("UICorner",statRow).CornerRadius = UDim.new(0,6)
Instance.new("UIStroke",statRow).Color = Theme.Stroke

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
_statusLbl = statLbl   -- wire SetStatus here

Section(TabRace, "  FLIGHT SPEED")
FluentSlider(TabRace, "AutoRace Speed", 50, AR_SPEED_CAP, Config.AutoRaceSpeed, 500,
    function() return Config.AutoRaceSpeed end,
    function(v) Config.AutoRaceSpeed = math.clamp(v, 50, AR_SPEED_CAP) end)

-- AutoRace visual state updater
local function UpdateARVisual()
    local map = {
        IDLE     = {txt="AutoRace: OFF",      col=Theme.SubText, bg=Theme.Button},
        QUEUING  = {txt="AutoRace: QUEUING",  col=Theme.Orange,  bg=Color3.fromRGB(35,28,15)},
        STARTING = {txt="AutoRace: STANDBY",  col=Theme.Red,     bg=Color3.fromRGB(35,18,18)},
        RACING   = {txt="AutoRace: RACING",   col=Theme.Green,   bg=Color3.fromRGB(18,35,24)},
    }
    local s = map[AR_STATE] or map.IDLE
    arMain.Text        = s.txt
    arMain.TextColor3  = s.col
    arSub.TextColor3   = s.col
    arRow.BackgroundColor3 = s.bg
    arDot.BackgroundColor3 = s.col
    arStroke.Color     = s.col
end

arRow.MouseButton1Click:Connect(function()
    Config.AutoRace = not Config.AutoRace

    if Config.AutoRace then
        local uuidF, stateV = FindPlayerRaceFolder()
        if uuidF then
            local sv = stateV and stateV.Value or ""
            if sv == "Racing" then
                AR_STATE="RACING"; UpdateARVisual()
                SetStatus("Already racing — joining loop!", 0, 200, 80)
                if not raceThread then
                    raceThread = task.spawn(DoRaceLoop, uuidF)
                end
            else
                AR_STATE="STARTING"; UpdateARVisual()
                SetStatus("Race in countdown, standing by 🚦", 255, 152, 0)
            end
            return
        end
        AR_STATE="QUEUING"; UpdateARVisual()
        SetStatus("Teleporting to queue...", 255, 152, 0)
        local ch = player.Character
        if ch and ch:FindFirstChild("Humanoid") then
            local seat = ch.Humanoid.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                local car  = seat.Parent
                local root = car.PrimaryPart or seat
                if root then
                    car:PivotTo(CFrame.new(QUEUE_POS))
                    root.AssemblyLinearVelocity  = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
        SetStatus("Queued — drive into start gate", 255, 152, 0)
    else
        Config.AutoRace = false; AR_STATE="IDLE"
        if raceThread then task.cancel(raceThread); raceThread=nil end
        RestoreCollisions()
        raceOwnsStatus = false
        UpdateARVisual()
        SetStatus("AutoRace OFF")
    end
end)

-- ── CAR TAB ───────────────────────────────────────────────────
Section(TabCar, "  DRIVING")
FluentToggle(TabCar, "⚡ Speed Hack", "Override car top speed",
    function(v) Config.SpeedHack=v; return v end)

Section(TabCar, "  NITRO")
FluentToggle(TabCar, "🔥 Infinite Nitro", "Keeps CurrentBoost at MaxBoost",
    function(v) Config.InfNitro=v; return v end)

Section(TabCar, "  TUNING")
FluentStepper(TabCar, "Top Speed (SpeedHack)", "%d st/s",
    function() return Config.MaxSpeed end,
    function() Config.MaxSpeed=math.max(50,Config.MaxSpeed-50) end,
    function() Config.MaxSpeed=Config.MaxSpeed+50 end)
FluentStepper(TabCar, "Acceleration", "%.1f",
    function() return Config.Acceleration end,
    function() Config.Acceleration=math.max(0.5,Config.Acceleration-0.5) end,
    function() Config.Acceleration=Config.Acceleration+0.5 end)

-- ── WORLD TAB ─────────────────────────────────────────────────
Section(TabWorld, "  TRAFFIC")
FluentToggle(TabWorld, "🚫 Kill Traffic", "Remove NPC vehicles from world",
    function() return ToggleTraffic() end)

Section(TabWorld, "  VISUALS")
FluentToggle(TabWorld, "☀️ Full Bright", "Force maximum ambient lighting",
    function() return ToggleFullBright() end)

Section(TabWorld, "  PERFORMANCE")
FluentToggle(TabWorld, "🖥️ FPS Boost", "Disable shadows & particles",
    function() return ToggleFPSBoost() end)

-- ── MISC TAB ──────────────────────────────────────────────────
Section(TabMisc, "  INFO")
local function InfoRow(parent, text)
    local r = Instance.new("Frame",parent)
    r.Size  = UDim2.new(0.98,0,0,30)
    r.BackgroundColor3 = Color3.fromRGB(20,20,24)
    r.BorderSizePixel  = 0
    Instance.new("UICorner",r).CornerRadius = UDim.new(0,6)
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
InfoRow(TabMisc, "🏁  Midnight Chasers AutoRace  V24c")
InfoRow(TabMisc, "🔧  True 3D Homing Flight Engine")
InfoRow(TabMisc, "🎚️  Magnetic repulsion cushion against hills/dives")
InfoRow(TabMisc, "💡  Fluent UI  ·  josepedov")
InfoRow(TabMisc, "📋  Changelog: Fixed downhill overshooting issue.")

-- Open Race tab by default
do
    for _,t in pairs(AllTabs)    do t.Frame.Visible = false end
    for _,b in pairs(AllTabBtns) do
        b.Btn.BackgroundTransparency = 1
        b.Btn.TextColor3 = Theme.SubText
        b.Ind.Visible = false
    end
    AllTabs[1].Frame.Visible                 = true
    AllTabBtns[1].Btn.BackgroundTransparency = 0.82
    AllTabBtns[1].Btn.TextColor3             = Theme.Text
    AllTabBtns[1].Ind.Visible                = true
end

SetProg(95, "Finalising...", 5)
task.wait(0.3)

-- ═══════════════════════════════════════════════════════════════
--  HEARTBEAT — state machine + SpeedHack + InfNitro
-- ═══════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()

    -- Full Bright enforcement
    if Config.FullBright then
        Lighting.Ambient        = Color3.new(1,1,1)
        Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.ClockTime      = 12
    end

    -- Update car handles
    local ch = player.Character
    if not ch or not ch:FindFirstChild("Humanoid") then return end
    currentSeat = ch.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then
        currentCar = nil; return
    end
    currentCar = currentSeat.Parent

    -- A-Chassis values
    local gasVal, brakeVal, gearVal = (currentSeat.ThrottleFloat or 0), 0, 1
    local iface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if iface and iface:FindFirstChild("Values") then
        local v = iface.Values
        if v:FindFirstChild("Throttle") then gasVal   = v.Throttle.Value end
        if v:FindFirstChild("Brake")    then brakeVal = v.Brake.Value    end
        if v:FindFirstChild("Gear")     then gearVal  = v.Gear.Value     end
    end

    -- Infinite Nitro
    if Config.InfNitro then
        local valObj = nil
        if iface then valObj = iface:FindFirstChild("Values") end
        if not valObj then valObj = currentCar:FindFirstChild("Values", true) end
        if valObj then
            local maxB = valObj:GetAttribute("MaxBoost")
            if maxB and maxB > 0 then
                valObj:SetAttribute("CurrentBoost", maxB)
            end
        end
    end

    -- ── AutoRace state machine ──────────────────────────────────
    if Config.AutoRace then

        if AR_STATE == "QUEUING" then
            local uuidF, stateV = FindPlayerRaceFolder()
            if uuidF then
                local sv = stateV and stateV.Value or ""
                if sv == "Racing" then
                    AR_STATE="RACING"; UpdateARVisual()
                    if not raceOwnsStatus then
                        SetStatus("Race started! Launching loop...", 0, 210, 80)
                    end
                    if not raceThread then
                        raceThread = task.spawn(DoRaceLoop, uuidF)
                    end
                else
                    AR_STATE="STARTING"; UpdateARVisual()
                    if not raceOwnsStatus then
                        SetStatus("Countdown — server moving car to grid 🚦", 255, 152, 0)
                    end
                end
            else
                if not raceOwnsStatus then
                    local t = math.floor(tick()*1.2)%2
                    SetStatus(t==0 and "⏳ Waiting for race start..." or
                        "⏳ Drive into the start gate", 255, 152, 0)
                end
            end

        elseif AR_STATE == "STARTING" then
            local uuidF, stateV = FindPlayerRaceFolder()
            if uuidF then
                local sv = stateV and stateV.Value or ""
                if sv == "Racing" then
                    AR_STATE="RACING"; UpdateARVisual()
                    if not raceOwnsStatus then
                        SetStatus("Race started! Launching loop...", 0, 210, 80)
                    end
                    if not raceThread then
                        raceThread = task.spawn(DoRaceLoop, uuidF)
                    end
                end
            else
                AR_STATE="QUEUING"; UpdateARVisual()
            end

        elseif AR_STATE == "RACING" then
            -- Coroutine owns the car. Heartbeat does nothing.
            if AR_STATE ~= "RACING" then UpdateARVisual() end
        end

        return
    end

    -- ── Normal mode (AutoRace OFF) ──────────────────────────────
    if AR_STATE ~= "IDLE" then
        AR_STATE="IDLE"; UpdateARVisual()
        if raceThread then task.cancel(raceThread); raceThread=nil end
        RestoreCollisions()
        raceOwnsStatus = false
        SetStatus("AutoRace OFF")
    end

    -- SpeedHack
    local isRev = (gearVal==-1) or (brakeVal>0.1) or (gasVal<-0.1)
    if Config.SpeedHack then
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {ch, currentCar}
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local grounded = Workspace:Raycast(currentSeat.Position,Vector3.new(0,-5,0),rp)
        if gasVal > Config.Deadzone and not isRev then
            if grounded then
                if currentSeat.AssemblyLinearVelocity.Magnitude < Config.MaxSpeed then
                    currentSeat.AssemblyLinearVelocity +=
                        currentSeat.CFrame.LookVector * Config.Acceleration
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
    else
        if not raceOwnsStatus then SetStatus("Status: Idle") end
    end
end)

-- ─────────────────────────────────────────────────────────────
--  DISMISS LOADING SCREEN
-- ─────────────────────────────────────────────────────────────
SetProg(100, "Ready!", 5)
task.wait(0.5)

loadAnimConn:Disconnect()
cam.CameraType = prevCamType

TweenService:Create(bg, TweenInfo.new(0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
    {BackgroundTransparency=1}):Play()
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
loadGui:Destroy()

print("[J24c] Midnight Chasers — V24c 3D Homing Engine Ready")
print("[J24c] Vehicle will now calculate true 3D vectors to dive towards low checkpoints.")

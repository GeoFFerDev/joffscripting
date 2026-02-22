-- [[ JOSEPEDOV V15: MIDNIGHT CHASERS ]] --
-- AutoRace: velocity-based flight through checkpoints (no instant TP freeze)
-- UI: tabbed, phone-friendly, compact

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local player            = Players.LocalPlayer

-- Anti-overlap
local guiTarget = (gethui and gethui()) or CoreGui
if guiTarget:FindFirstChild("J15_Midnight") then
    guiTarget.J15_Midnight:Destroy()
end

-- ═══════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════
local Config = {
    SpeedHack      = false,
    AutoRace       = false,
    InfNitro       = false,
    TrafficBlocked = false,
    FPS_Boosted    = false,
    FullBright     = false,
    Acceleration   = 3.0,
    MaxSpeed       = 300,   -- fly speed during AutoRace
    Deadzone       = 0.1,
}

local OriginalTech    = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoor = Lighting.OutdoorAmbient
local OriginalClock   = Lighting.ClockTime

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════
local currentSeat = nil
local currentCar  = nil

-- "IDLE" | "QUEUING" | "STARTING" | "RACING"
local AR_STATE       = "IDLE"
local raceThread     = nil   -- task.spawn coroutine
local flyConnection  = nil   -- RunService connection for per-frame flight

-- Race1 QueueRegion position (from XML)
local QUEUE_POS = Vector3.new(3260.5, 2, 1015.7)

-- Height above checkpoint centre to target (checkpoints are at road level / slightly below)
local CP_HEIGHT_OFFSET = 5

-- ═══════════════════════════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════════════════════════

local function GetRoot(car)
    return car and (car.PrimaryPart or currentSeat) or nil
end

local function SetCollisions(car, enabled)
    if not car then return end
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.CanCollide = enabled
        end
    end
end

local function KillMomentum(car)
    local root = GetRoot(car)
    if root then
        root.AssemblyLinearVelocity  = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
end

local function TeleportCarOnce(car, pos)
    local root = GetRoot(car)
    if not root then return end
    car:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
    KillMomentum(car)
end

-- Stop per-frame flight connection
local function StopFlight()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
end

-- Fly car toward a world position at Config.MaxSpeed studs/s per frame.
-- Returns a Promise-like: calls onArrived(part) when within arrivalDist.
-- Stops automatically when distance <= arrivalDist OR part disappears.
local function FlyToward(targetPart, arrivalDist, onArrived)
    StopFlight()
    arrivalDist = arrivalDist or 8

    flyConnection = RunService.Heartbeat:Connect(function(dt)
        if not Config.AutoRace or AR_STATE ~= "RACING" then
            StopFlight(); return
        end
        if not targetPart or not targetPart.Parent then
            -- Part was removed by server (checkpoint touched)
            StopFlight()
            onArrived(true)  -- true = server confirmed
            return
        end
        if not currentCar then StopFlight(); return end

        local root = GetRoot(currentCar)
        if not root then StopFlight(); return end

        -- Aim at checkpoint centre + height offset so car doesn't sink into ground
        local targetPos = targetPart.Position + Vector3.new(0, CP_HEIGHT_OFFSET, 0)
        local myPos     = root.Position
        local dist      = (targetPos - myPos).Magnitude

        if dist <= arrivalDist then
            -- We are inside the checkpoint zone — let the server register it
            -- Keep flying through for up to 1 more second, then check
            StopFlight()
            onArrived(false)  -- false = proximity-based, wait for server
            return
        end

        -- Apply velocity toward target
        local dir = (targetPos - myPos).Unit
        -- Orient car toward target
        currentCar:PivotTo(CFrame.lookAt(myPos, targetPos))
        root.AssemblyLinearVelocity  = dir * Config.MaxSpeed
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
end

-- Find player's UUID race folder across all Race lobbies
local function FindPlayerRaceFolder()
    local racesWS = Workspace:FindFirstChild("Races")
    if not racesWS then return nil, nil end
    for _, raceN in ipairs(racesWS:GetChildren()) do
        local container = raceN:FindFirstChild("Races")
        if container then
            for _, uuidFolder in ipairs(container:GetChildren()) do
                local racers = uuidFolder:FindFirstChild("Racers")
                if racers and racers:FindFirstChild(player.Name) then
                    return uuidFolder, uuidFolder:FindFirstChild("State")
                end
            end
        end
    end
    return nil, nil
end

-- Get next checkpoint Part (lowest numeric name in Checkpoints IntValue)
local function FindNextCP(raceFolder)
    local cpVal = raceFolder:FindFirstChild("Checkpoints")
    if not cpVal then return nil, nil end
    local best, bestIdx = nil, math.huge
    for _, child in ipairs(cpVal:GetChildren()) do
        if child:IsA("BasePart") then
            local idx = tonumber(child.Name)
            if idx and idx < bestIdx then best, bestIdx = child, idx end
        end
    end
    return best, bestIdx
end

-- ═══════════════════════════════════════════════════════════════
-- STATUS LABEL (forward-declared, assigned after UI)
-- ═══════════════════════════════════════════════════════════════
local SetStatus  -- function(text, color?)

-- ═══════════════════════════════════════════════════════════════
-- RACE COROUTINE
-- Handles the RACING phase. Called once when State flips to "Racing".
-- Loops: find CP → fly to it → wait for server removal → repeat.
-- ═══════════════════════════════════════════════════════════════
local function DoRacingLoop(uuidFolder)
    raceThread = task.spawn(function()
        while Config.AutoRace and AR_STATE == "RACING" do

            if not currentCar then task.wait(0.1); continue end
            SetCollisions(currentCar, false)

            local cpPart, cpIdx = FindNextCP(uuidFolder)
            if not cpPart then
                SetStatus("✓ All checkpoints cleared!", Color3.fromRGB(0, 255, 120))
                task.wait(3)
                StopFlight()
                break
            end

            SetStatus(string.format("→ CP #%d  (flying...)", cpIdx), Color3.fromRGB(0, 200, 255))

            -- Fly toward checkpoint. We use a signal pattern:
            -- serverConfirmed = true  → part vanished while flying (best case)
            -- serverConfirmed = false → we arrived close but part still exists; wait more
            local arrived       = false
            local serverConfirmed = false

            FlyToward(cpPart, 10, function(byServer)
                arrived         = true
                serverConfirmed = byServer
            end)

            -- Wait until arrived signal fires
            local waitStart = tick()
            while not arrived and tick() - waitStart < 30 do
                task.wait()
            end
            StopFlight()

            if serverConfirmed then
                -- Server already removed the part; move on immediately
                SetStatus(string.format("CP #%d ✓ (server confirmed)", cpIdx), Color3.fromRGB(0,255,80))
                task.wait(0.1)
            else
                -- We arrived close, but server hasn't removed part yet.
                -- Keep driving through it and wait up to 3 s for ChildRemoved.
                SetStatus(string.format("CP #%d ⏳ (waiting server...)", cpIdx), Color3.fromRGB(255,200,0))

                local removed   = false
                local removeConn
                if cpPart.Parent then
                    removeConn = cpPart.Parent.ChildRemoved:Connect(function(child)
                        if child == cpPart then
                            removed = true
                            if removeConn then removeConn:Disconnect() end
                        end
                    end)
                end

                -- Keep nudging through the zone during the wait
                local nudgeStart = tick()
                while not removed and tick() - nudgeStart < 3 do
                    if currentCar and cpPart.Parent then
                        local root = GetRoot(currentCar)
                        if root then
                            local dir = (cpPart.Position - root.Position).Unit
                            root.AssemblyLinearVelocity  = dir * 80
                            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end
                    end
                    task.wait(0.05)
                end

                if removeConn then pcall(function() removeConn:Disconnect() end) end

                if removed then
                    SetStatus(string.format("CP #%d ✓", cpIdx), Color3.fromRGB(0,255,80))
                else
                    -- Timeout — CP might not have fired. Move on anyway.
                    SetStatus(string.format("CP #%d timeout, continuing...", cpIdx), Color3.fromRGB(255,100,0))
                end
                task.wait(0.1)
            end
        end

        -- Race ended / AutoRace turned off
        StopFlight()
        if currentCar then SetCollisions(currentCar, true) end

        if Config.AutoRace then
            -- Race finished naturally; go back to queuing
            AR_STATE = "QUEUING"
        end
        raceThread = nil
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- FEATURE HELPERS
-- ═══════════════════════════════════════════════════════════════
local function ToggleTraffic()
    Config.TrafficBlocked = not Config.TrafficBlocked
    local ev = ReplicatedStorage:FindFirstChild("CreateNPCVehicle")
    if Config.TrafficBlocked then
        if ev then for _, c in pairs(getconnections(ev.OnClientEvent)) do c:Disable() end end
        for _, n in ipairs({"NPCVehicles","Traffic","Vehicles"}) do
            local f = Workspace:FindFirstChild(n); if f then f:ClearAllChildren() end
        end
    else
        if ev then for _, c in pairs(getconnections(ev.OnClientEvent)) do c:Enable() end end
    end
    return Config.TrafficBlocked
end

local function ToggleFPSBoost()
    Config.FPS_Boosted = not Config.FPS_Boosted
    pcall(function()
        if Config.FPS_Boosted then
            Lighting.GlobalShadows = false
            if sethiddenproperty then sethiddenproperty(Lighting,"Technology",Enum.Technology.Voxel) end
            for _, v in ipairs(workspace:GetDescendants()) do pcall(function()
                if v:IsA("BasePart") then v.CastShadow = false
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false end
            end) end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then sethiddenproperty(Lighting,"Technology",OriginalTech) end
            for _, v in ipairs(workspace:GetDescendants()) do pcall(function()
                if v:IsA("BasePart") then v.CastShadow = true
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = true end
            end) end
        end
    end)
    return Config.FPS_Boosted
end

local function ToggleFullBright()
    Config.FullBright = not Config.FullBright
    if not Config.FullBright then
        Lighting.Ambient=OriginalAmbient; Lighting.OutdoorAmbient=OriginalOutdoor; Lighting.ClockTime=OriginalClock
    end
    return Config.FullBright
end

-- ═══════════════════════════════════════════════════════════════
-- DRAG
-- ═══════════════════════════════════════════════════════════════
local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=frame.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    frame.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then dragInput=i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i==dragInput and dragging then
            local d=i.Position-dragStart
            frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- UI — TABBED, PHONE-FRIENDLY
-- ═══════════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "J15_Midnight"; ScreenGui.Parent = guiTarget

-- ── Colour palette ──────────────────────────────────────────
local C = {
    BG      = Color3.fromRGB(14,14,18),
    Panel   = Color3.fromRGB(22,22,30),
    Row     = Color3.fromRGB(34,34,44),
    Accent  = Color3.fromRGB(0,150,255),
    AccentD = Color3.fromRGB(0,100,190),
    Green   = Color3.fromRGB(0,200,80),
    Orange  = Color3.fromRGB(255,155,0),
    Red     = Color3.fromRGB(220,60,60),
    Text    = Color3.fromRGB(230,230,230),
    SubText = Color3.fromRGB(140,140,160),
}

-- ── Mini icon (shown when collapsed) ────────────────────────
local IconFrame = Instance.new("Frame")
IconFrame.Size=UDim2.new(0,44,0,44); IconFrame.Position=UDim2.new(1,-54,0.5,-22)
IconFrame.BackgroundTransparency=1; IconFrame.Visible=false; IconFrame.Active=true
IconFrame.Parent=ScreenGui

local IconBtn = Instance.new("TextButton")
IconBtn.Size=UDim2.new(1,0,1,0); IconBtn.BackgroundColor3=C.Accent
IconBtn.Text="J"; IconBtn.TextColor3=Color3.fromRGB(255,255,255)
IconBtn.Font=Enum.Font.GothamBlack; IconBtn.TextSize=20; IconBtn.Parent=IconFrame
Instance.new("UICorner",IconBtn).CornerRadius=UDim.new(0,22)
MakeDraggable(IconFrame)

-- ── Main window ──────────────────────────────────────────────
local WIN_W, WIN_H = 230, 370

local Main = Instance.new("Frame")
Main.Size=UDim2.new(0,WIN_W,0,WIN_H); Main.Position=UDim2.new(0,12,0.08,0)
Main.BackgroundColor3=C.BG; Main.BorderSizePixel=0; Main.Active=true
Main.Parent=ScreenGui
Instance.new("UICorner",Main).CornerRadius=UDim.new(0,10)
local MainStroke = Instance.new("UIStroke",Main)
MainStroke.Color=C.Accent; MainStroke.Thickness=1.5
MakeDraggable(Main)

-- ── Title bar ────────────────────────────────────────────────
local TBar = Instance.new("Frame")
TBar.Size=UDim2.new(1,0,0,34); TBar.BackgroundColor3=C.Panel; TBar.Parent=Main
Instance.new("UICorner",TBar).CornerRadius=UDim.new(0,10)
-- Cover bottom corners
local TBarFix = Instance.new("Frame",TBar)
TBarFix.Size=UDim2.new(1,0,0.5,0); TBarFix.Position=UDim2.new(0,0,0.5,0)
TBarFix.BackgroundColor3=C.Panel; TBarFix.BorderSizePixel=0

local TTitle = Instance.new("TextLabel",TBar)
TTitle.Size=UDim2.new(0,140,1,0); TTitle.Position=UDim2.new(0,10,0,0)
TTitle.BackgroundTransparency=1; TTitle.Text="J15 MIDNIGHT CHASERS"
TTitle.TextColor3=C.Accent; TTitle.Font=Enum.Font.GothamBlack
TTitle.TextSize=11; TTitle.TextXAlignment=Enum.TextXAlignment.Left

local ColBtn = Instance.new("TextButton",TBar)
ColBtn.Size=UDim2.new(0,28,0,28); ColBtn.Position=UDim2.new(1,-32,0,3)
ColBtn.BackgroundColor3=C.Row; ColBtn.Text="−"
ColBtn.TextColor3=C.Text; ColBtn.Font=Enum.Font.GothamBold; ColBtn.TextSize=18
Instance.new("UICorner",ColBtn).CornerRadius=UDim.new(0,6)

ColBtn.MouseButton1Click:Connect(function() Main.Visible=false; IconFrame.Visible=true end)
IconBtn.MouseButton1Click:Connect(function() Main.Visible=true; IconFrame.Visible=false end)

-- ── Tab bar ──────────────────────────────────────────────────
local TAB_H = 30
local TabBar = Instance.new("Frame",Main)
TabBar.Size=UDim2.new(1,0,0,TAB_H); TabBar.Position=UDim2.new(0,0,0,34)
TabBar.BackgroundColor3=C.Panel; TabBar.BorderSizePixel=0

local TabLayout = Instance.new("UIListLayout",TabBar)
TabLayout.FillDirection=Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
TabLayout.SortOrder=Enum.SortOrder.LayoutOrder; TabLayout.Padding=UDim.new(0,2)
local TabPad = Instance.new("UIPadding",TabBar)
TabPad.PaddingLeft=UDim.new(0,4); TabPad.PaddingRight=UDim.new(0,4)
TabPad.PaddingTop=UDim.new(0,4); TabPad.PaddingBottom=UDim.new(0,4)

-- ── Content area ─────────────────────────────────────────────
local CONTENT_Y = 34 + TAB_H
local ContentArea = Instance.new("Frame",Main)
ContentArea.Size=UDim2.new(1,0,0,WIN_H-CONTENT_Y)
ContentArea.Position=UDim2.new(0,0,0,CONTENT_Y)
ContentArea.BackgroundTransparency=1; ContentArea.ClipsDescendants=true

-- Pages container (slides horizontally)
local Pages = {}        -- {name: ScrollingFrame}
local ActiveTab = nil
local TabBtns   = {}

local function MakePage(name)
    local sf = Instance.new("ScrollingFrame",ContentArea)
    sf.Size=UDim2.new(1,0,1,0); sf.Position=UDim2.new(0,0,0,0)
    sf.BackgroundTransparency=1; sf.ScrollBarThickness=4
    sf.ScrollBarImageColor3=C.Accent
    sf.AutomaticCanvasSize=Enum.AutomaticSize.Y; sf.CanvasSize=UDim2.new(0,0,0,0)
    sf.Visible=false
    local ll = Instance.new("UIListLayout",sf)
    ll.Padding=UDim.new(0,6); ll.HorizontalAlignment=Enum.HorizontalAlignment.Center
    ll.SortOrder=Enum.SortOrder.LayoutOrder
    local pp = Instance.new("UIPadding",sf)
    pp.PaddingTop=UDim.new(0,8); pp.PaddingBottom=UDim.new(0,8)
    Pages[name] = sf
    return sf
end

local function SwitchTab(name)
    ActiveTab = name
    for n, page in pairs(Pages) do page.Visible = (n==name) end
    for n, btn in pairs(TabBtns) do
        btn.BackgroundColor3 = (n==name) and C.Accent or C.Row
        btn.TextColor3       = (n==name) and Color3.fromRGB(255,255,255) or C.SubText
    end
end

local function MakeTab(name, label, order)
    local btn = Instance.new("TextButton",TabBar)
    btn.Size=UDim2.new(0,68,1,0); btn.BackgroundColor3=C.Row
    btn.Text=label; btn.TextColor3=C.SubText
    btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.LayoutOrder=order
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
    btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
    TabBtns[name] = btn
    MakePage(name)
end

MakeTab("race",  "🏁 Race",  1)
MakeTab("car",   "🚗 Car",   2)
MakeTab("world", "🌏 World", 3)

-- ── Widget helpers ───────────────────────────────────────────

-- Toggle row (returns button)
local function MakeToggle(page, label, order, callback)
    local row = Instance.new("Frame",Pages[page])
    row.Size=UDim2.new(0.95,0,0,38); row.BackgroundColor3=C.Row
    row.LayoutOrder=order; Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(0.65,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.Text; lbl.Font=Enum.Font.GothamBold
    lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left

    -- Pill toggle
    local pill = Instance.new("Frame",row)
    pill.Size=UDim2.new(0,46,0,24); pill.Position=UDim2.new(1,-54,0.5,-12)
    pill.BackgroundColor3=C.Row; Instance.new("UICorner",pill).CornerRadius=UDim.new(0,12)
    local PillStroke = Instance.new("UIStroke",pill)
    PillStroke.Color=C.SubText; PillStroke.Thickness=1

    local knob = Instance.new("Frame",pill)
    knob.Size=UDim2.new(0,18,0,18); knob.Position=UDim2.new(0,3,0.5,-9)
    knob.BackgroundColor3=C.SubText; Instance.new("UICorner",knob).CornerRadius=UDim.new(0,9)

    local state = false
    local function setVisual(on)
        state=on
        pill.BackgroundColor3 = on and C.Accent or C.Row
        PillStroke.Color      = on and C.Accent or C.SubText
        knob.BackgroundColor3 = on and Color3.fromRGB(255,255,255) or C.SubText
        knob.Position         = on and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
    end

    -- Click anywhere on the row
    local clickBtn = Instance.new("TextButton",row)
    clickBtn.Size=UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency=1; clickBtn.Text=""
    clickBtn.MouseButton1Click:Connect(function()
        local result = callback(not state)
        setVisual(result ~= nil and result or not state)
    end)

    return setVisual   -- caller can call this to update visual externally
end

-- Section label
local function MakeLabel(page, text, order)
    local lbl = Instance.new("TextLabel",Pages[page])
    lbl.Size=UDim2.new(0.95,0,0,18); lbl.BackgroundTransparency=1
    lbl.Text=text; lbl.TextColor3=C.SubText
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=10
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.LayoutOrder=order
    local pp=Instance.new("UIPadding",lbl); pp.PaddingLeft=UDim.new(0,4)
end

-- Slider row (< label >)
local function MakeSlider(page, labelFmt, order, getV, decV, incV)
    local row = Instance.new("Frame",Pages[page])
    row.Size=UDim2.new(0.95,0,0,36); row.BackgroundColor3=C.Row
    row.LayoutOrder=order; Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(0.6,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=string.format(labelFmt,getV())
    lbl.TextColor3=C.Text; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left

    local function mkBtn(label, x)
        local b=Instance.new("TextButton",row)
        b.Size=UDim2.new(0,26,0,26); b.Position=UDim2.new(x,0,0.5,-13)
        b.BackgroundColor3=C.Panel; b.TextColor3=C.Text
        b.Text=label; b.Font=Enum.Font.GothamBold; b.TextSize=14
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
        return b
    end
    mkBtn("<",0.62).MouseButton1Click:Connect(function() decV(); lbl.Text=string.format(labelFmt,getV()) end)
    mkBtn(">",0.80).MouseButton1Click:Connect(function() incV(); lbl.Text=string.format(labelFmt,getV()) end)
end

-- Big status block
local function MakeStatusBlock(page, order)
    local row = Instance.new("Frame",Pages[page])
    row.Size=UDim2.new(0.95,0,0,44); row.BackgroundColor3=C.Panel
    row.LayoutOrder=order; Instance.new("UICorner",row).CornerRadius=UDim.new(0,7)
    local lbl = Instance.new("TextLabel",row)
    lbl.Size=UDim2.new(1,-10,1,0); lbl.Position=UDim2.new(0,6,0,0)
    lbl.BackgroundTransparency=1; lbl.Text="Status: IDLE"
    lbl.TextColor3=C.SubText; lbl.Font=Enum.Font.Code; lbl.TextSize=11
    lbl.TextWrapped=true; lbl.TextXAlignment=Enum.TextXAlignment.Left
    return lbl
end

-- ── AutoRace button (custom, not toggle) ─────────────────────
local arRow = Instance.new("Frame",Pages["race"])
arRow.Size=UDim2.new(0.95,0,0,44); arRow.BackgroundColor3=C.Accent
arRow.LayoutOrder=1; Instance.new("UICorner",arRow).CornerRadius=UDim.new(0,8)

local arLbl = Instance.new("TextLabel",arRow)
arLbl.Size=UDim2.new(1,0,1,0); arLbl.BackgroundTransparency=1
arLbl.Text="🏁  AutoRace (Highway): OFF"; arLbl.TextColor3=Color3.fromRGB(255,255,255)
arLbl.Font=Enum.Font.GothamBlack; arLbl.TextSize=12

local arClick = Instance.new("TextButton",arRow)
arClick.Size=UDim2.new(1,0,1,0); arClick.BackgroundTransparency=1; arClick.Text=""

local statusLbl = MakeStatusBlock("race", 10)

local function UpdateARVisual()
    local map = {
        IDLE     = {"🏁  AutoRace (Highway): OFF", C.Row,    C.SubText},
        QUEUING  = {"⏳  Queuing...",              C.Orange,  Color3.fromRGB(255,255,255)},
        STARTING = {"🚦  Countdown — hands off!",  C.Red,     Color3.fromRGB(255,255,255)},
        RACING   = {"🔥  RACING",                  C.Green,   Color3.fromRGB(255,255,255)},
    }
    local s = map[AR_STATE] or map.IDLE
    arRow.BackgroundColor3 = s[2]
    arLbl.Text             = s[1]
    arLbl.TextColor3       = s[3]
end

arClick.MouseButton1Click:Connect(function()
    Config.AutoRace = not Config.AutoRace
    if Config.AutoRace then
        -- ── Detect if already in a race right now ──
        local uuidFolder, stateVal = FindPlayerRaceFolder()
        if uuidFolder then
            local sv = stateVal and stateVal.Value or ""
            if sv == "Racing" then
                AR_STATE = "RACING"
                UpdateARVisual()
                SetStatus("Already racing — joining loop!", C.Green)
                if not raceThread then DoRacingLoop(uuidFolder) end
                return
            else
                AR_STATE = "STARTING"
                UpdateARVisual()
                SetStatus("Race in countdown, standing by...", C.Orange)
                return
            end
        end
        -- Not in a race yet — TP to queue and wait
        AR_STATE = "QUEUING"
        UpdateARVisual()
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            local seat = char.Humanoid.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                TeleportCarOnce(seat.Parent, QUEUE_POS)
            end
        end
        SetStatus("Queued. Drive into start gate if needed.", C.Orange)
    else
        -- Disable
        Config.AutoRace = false
        AR_STATE = "IDLE"
        StopFlight()
        if raceThread then task.cancel(raceThread); raceThread = nil end
        if currentCar then SetCollisions(currentCar, true) end
        UpdateARVisual()
        SetStatus("AutoRace OFF.", C.SubText)
    end
end)

-- ── Fly speed slider (Race tab) ──────────────────────────────
MakeLabel("race", "FLIGHT SPEED", 5)
MakeSlider("race","Speed: %d studs/s",6,
    function() return Config.MaxSpeed end,
    function() Config.MaxSpeed=math.max(50,Config.MaxSpeed-50) end,
    function() Config.MaxSpeed=Config.MaxSpeed+50 end)

-- ── Car tab ──────────────────────────────────────────────────
MakeLabel("car","DRIVING",1)
MakeToggle("car","⚡ Speed Hack",2,function(v) Config.SpeedHack=v; return v end)
MakeLabel("car","TUNING",5)
MakeSlider("car","Top Speed: %d",6,
    function() return Config.MaxSpeed end,
    function() Config.MaxSpeed=math.max(50,Config.MaxSpeed-50) end,
    function() Config.MaxSpeed=Config.MaxSpeed+50 end)
MakeSlider("car","Acceleration: %.1f",7,
    function() return Config.Acceleration end,
    function() Config.Acceleration=math.max(0.5,Config.Acceleration-0.5) end,
    function() Config.Acceleration=Config.Acceleration+0.5 end)
MakeLabel("car","NITRO",10)
MakeToggle("car","🔥 Infinite Nitro",11,function(v) Config.InfNitro=v; return v end)

-- ── World tab ─────────────────────────────────────────────────
MakeLabel("world","TRAFFIC",1)
MakeToggle("world","🚫 Kill Traffic",2,function(v)
    ToggleTraffic(); return Config.TrafficBlocked
end)
MakeLabel("world","VISUALS",5)
MakeToggle("world","☀️ Full Bright",6,function(v)
    ToggleFullBright(); return Config.FullBright
end)
MakeLabel("world","PERFORMANCE",10)
MakeToggle("world","🖥️ FPS Boost",11,function(v)
    ToggleFPSBoost(); return Config.FPS_Boosted
end)

-- Default tab
SwitchTab("race")

-- Assign SetStatus now that statusLbl exists
SetStatus = function(text, color)
    statusLbl.Text      = text
    statusLbl.TextColor3 = color or C.SubText
end

-- ═══════════════════════════════════════════════════════════════
-- MASTER HEARTBEAT
-- ═══════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()

    -- Full Bright enforcement
    if Config.FullBright then
        Lighting.Ambient=Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        Lighting.ClockTime=12
    end

    -- Must be seated in a car
    local char = player.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    currentSeat = char.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then currentCar=nil; return end
    currentCar = currentSeat.Parent

    -- A-Chassis values
    local gasVal, brakeVal, gearVal = (currentSeat.ThrottleFloat or 0), 0, 1
    local iface = player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if iface and iface:FindFirstChild("Values") then
        local v=iface.Values
        if v:FindFirstChild("Throttle") then gasVal=v.Throttle.Value end
        if v:FindFirstChild("Brake") then brakeVal=v.Brake.Value end
        if v:FindFirstChild("Gear") then gearVal=v.Gear.Value end
    end

    -- Inf Nitro
    if Config.InfNitro then
        for _,obj in ipairs(currentCar:GetDescendants()) do
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                local n=obj.Name:lower()
                if n:match("nitro") or n:match("boost") or n:match("n2o") then obj.Value=9999 end
            end
        end
        if iface and iface:FindFirstChild("Values") then
            for _,obj in ipairs(iface.Values:GetChildren()) do
                local n=obj.Name:lower()
                if n:match("nitro") or n:match("boost") then obj.Value=9999 end
            end
        end
    end

    -- ══════════════════════════════════════════
    -- AUTORACE STATE MACHINE (Heartbeat portion)
    -- ══════════════════════════════════════════
    if Config.AutoRace then
        if AR_STATE == "QUEUING" then
            local uuidFolder, stateVal = FindPlayerRaceFolder()
            if uuidFolder then
                local sv = stateVal and stateVal.Value or ""
                if sv == "Racing" then
                    AR_STATE = "RACING"; UpdateARVisual()
                    if not raceThread then DoRacingLoop(uuidFolder) end
                else
                    AR_STATE = "STARTING"; UpdateARVisual()
                    SetStatus("Countdown — server teleporting you to grid. Hands off 🚦", C.Orange)
                end
            else
                local pulse = math.floor(tick()*1.5)%2==0
                SetStatus(pulse and "⏳ Waiting for race..." or "Drive into the start gate", C.Orange)
            end

        elseif AR_STATE == "STARTING" then
            -- Pure polling, zero car interference
            local uuidFolder, stateVal = FindPlayerRaceFolder()
            if uuidFolder then
                local sv = stateVal and stateVal.Value or ""
                if sv == "Racing" then
                    AR_STATE = "RACING"; UpdateARVisual()
                    SetStatus("🟢 Race started!", C.Green)
                    if not raceThread then DoRacingLoop(uuidFolder) end
                end
            else
                AR_STATE = "QUEUING"; UpdateARVisual()
            end

        elseif AR_STATE == "RACING" then
            -- Coroutine drives everything; Heartbeat just ensures collisions stay off
            if currentCar then SetCollisions(currentCar, false) end
            -- If coroutine ended (set AR_STATE back to QUEUING), UpdateARVisual
            if AR_STATE ~= "RACING" then UpdateARVisual() end
        end

        return
    end

    -- ══════════════════════════════════════════
    -- NORMAL MODE
    -- ══════════════════════════════════════════
    if AR_STATE ~= "IDLE" then
        AR_STATE = "IDLE"; UpdateARVisual()
        StopFlight()
        if raceThread then task.cancel(raceThread); raceThread=nil end
        if currentCar then SetCollisions(currentCar, true) end
    end

    -- SpeedHack
    local isRev = (gearVal==-1) or (brakeVal>0.1) or (gasVal<-0.1)
    if Config.SpeedHack then
        local rp=RaycastParams.new()
        rp.FilterDescendantsInstances={char,currentCar}; rp.FilterType=Enum.RaycastFilterType.Exclude
        local grounded=Workspace:Raycast(currentSeat.Position,Vector3.new(0,-5,0),rp)
        if gasVal>Config.Deadzone and not isRev then
            if grounded then
                if currentSeat.AssemblyLinearVelocity.Magnitude<Config.MaxSpeed then
                    currentSeat.AssemblyLinearVelocity+=currentSeat.CFrame.LookVector*Config.Acceleration
                    SetStatus("SpeedHack: BOOSTING",C.Green)
                else SetStatus("SpeedHack: MAX SPEED",C.Orange) end
            else SetStatus("SpeedHack: AIRBORNE",C.Red) end
        else SetStatus(isRev and "SpeedHack: REVERSING" or "Status: IDLE") end
    else
        SetStatus("Status: IDLE")
    end
end)

print("[J15] Midnight Chasers loaded — tabbed UI, flight-based AutoRace")

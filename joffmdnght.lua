--[[
  JOSEPEDOV V22 — MIDNIGHT CHASERS
  Highway AutoRace exploit | Tabbed UI | Loading screen

  NEW IN V22 (AutoRace stability — highway underground fix):
  • Floor clamp on targetY          → The ceiling guard's downward push (×3 multiplier)
                                       was sending targetY to (myPos.Y - 15) or lower
                                       when ANY bridge/overpass geometry appeared within
                                       20 studs overhead. The car was dragged underground,
                                       never reached road level, and the XZ proximity check
                                       never fired → CP was missed entirely.
                                       FIX: After ceiling guard fires, clamp targetY so it
                                       can NEVER go below (gatePart.Y + 2) regardless of
                                       what is overhead. Road level is always the floor.
  • Ceiling guard multiplier ×3→×1  → Softened from 3× to 1× so the downward nudge is
                                       proportional, not explosive.
  • CLEAR_DIST 28→40                → Wider proximity trigger (40 studs XZ) handles high-
                                       speed approaches where the car is still converging
                                       on Y when it crosses the gate plane in XZ.
  • 3D distance fallback (+12 studs)→ If the car is vertically displaced when it reaches
                                       the CP (e.g. still descending from queue height),
                                       the XZ-only check could miss it. 3D fallback fires
                                       at CLEAR_DIST+12 so even a vertically offset car
                                       gets the CP marked.
  • Ceiling clamp on targetY        → Also clamp targetY from going more than 10 studs
                                       above gate road level so the car can't shoot up into
                                       bridge decks during the approach.
  • Stable coast after CP clear     → Previously the car dead-coasted for 0.2 s with
                                       CanCollide=false and no velocity, letting gravity
                                       pull it underground before the next CP loop started.
                                       Now actively holds Y at road level + forward momentum
                                       throughout the 0.2 s coast window.

  NEW IN V21:
  • Car under highway fixed  → Removed the downward raycast (V20). Most road Parts
                               have CanCollide=false so the ray passed through them,
                               found nothing, and fell back to gatePart.Y-5 = underground.
                               Now targets gatePart.Y+3 directly (gate centres sit at road
                               level Y≈-2 to -7, so +3 = just above tarmac).
                               Added UPWARD ceiling raycast (20 studs) to detect bridge
                               undersides (deck bottoms confirmed at Y≈17-18 in XML) and
                               actively steer the car DOWN away from them.
  • Infinite Nitro fixed     → Old code searched for NumberValue/IntValue children named
                               "nitro/boost". From place XML: the game uses Attributes on
                               the A-Chassis Values object — "CurrentBoost" / "MaxBoost".
                               No child values are involved at all.
                               New code: finds Values via PlayerGui → A-Chassis Interface
                               → Values (or deep-searches car), reads MaxBoost attribute,
                               writes CurrentBoost = MaxBoost every Heartbeat frame.

  NEW IN V20:
  • Bridge/underpass stuck fix → Per-frame downward raycast replaces fixed targetY.
                                 The car now always tracks the actual surface directly
                                 below it (road, bridge deck, etc.) and hovers HOVER=2
                                 studs above it. Bridge undersides are never targeted
                                 because the raycast finds the road BELOW the bridge,
                                 not the bridge bottom above the car.
  • Character collision fix   → DisableCollisions now also sets CanCollide=false on
                                 the seated character's body parts (Torso, Arms, etc.).
                                 These are not car:GetDescendants(), so they were still
                                 physically snagging bridge geometry even when the car
                                 itself passed through. Restored on race end.
  • Tighter Y overshoot guard → P-controller gain drops from 8→5 and clamp drops from
                                 ±80→±20 when within 8 studs of ground target, so the
                                 car can't launch itself into bridge geometry on approach.

  NEW IN V19:
  • Wall/obstacle collisions   → Car no longer flies in 3D straight line toward CP.
                                 Now drives XZ-only at full AutoRaceSpeed with a gentle
                                 Y correction (±60 stud/s) to stay at road level.
                                 Walls, barriers, and buildings are on the sides of
                                 the road — a road-level horizontal approach avoids them.
  • Real drag slider (Race tab)→ "FLIGHT SPEED" replaced with a draggable track slider,
                                 range 50–600 studs/s. Color-codes the value:
                                 blue=safe · orange=fast · red=at cap.
  • Separate AutoRaceSpeed     → Config.AutoRaceSpeed (default 350) controls AR flight.
                                 Config.MaxSpeed still controls SpeedHack. Hard cap 600.
  • TP back to queue after race→ On race complete, car is teleported back to QUEUE_POS
                                 so user can re-queue instantly without driving back.

  FIXES vs V17:
  ─────────────────────────────────────────────────────────────────
  BUG: Car freezes / glitches mid-air after CP 1 (and every CP)
  ROOT CAUSE (confirmed from place XML analysis):
    • The checkpoint trigger Parts are 0.001213 studs thick (X).
    • At Config.MaxSpeed=320, the car moves ~5.3 studs per frame.
    • The car skips entirely over the 0.001-stud trigger between frames.
    • Server Touched event never fires → Part never removed → ChildRemoved
      never fires on client → cpCleared stays false forever.
    • The fly-loop keeps reversing dir each frame (car overshoots CP centre,
      dir flips, car flies back, overshoots again) → infinite oscillation
      = the "mid-air freeze glitch" the user sees.

  FIX A — Proximity-based CP clearance (primary):
    Break out of the fly-loop and mark CP as cleared when dist <= 40 studs
    (widened from 28 in v22 for better high-speed coverage).
    This fires BEFORE the close-range oscillation zone is reached.

  FIX B — clearedSet replaces single skippedIdx:
    After a CP is cleared via proximity the server Part still exists (Touched
    never fired). Old code reset skippedIdx = nil so FindNextCP returned the
    same CP index again on the very next loop iteration → car forever targets
    CP27 after "passing" it.
    New: clearedSet{} records every cleared cpIdx permanently. FindNextCP
    skips any index in clearedSet, so the car always advances forward.

  FIX C — ChildRemoved kept as secondary/backup:
    If the server IS fast and removes the Part before proximity triggers,
    ChildRemoved sets cpCleared=true early. The proximity check catches all
    other cases.

  FIX D — No velocity applied inside CLEAR_DIST zone:
    Stop setting AssemblyLinearVelocity when dist <= CLEAR_DIST.
    Existing momentum coasts the car through the gate arch.
    This eliminates the oscillation without zeroing velocity (zeroing = gravity
    drops car through road since CanCollide is off).

  RETAINED FROM V17:
    • disabledCar ref for always-correct RestoreCollisions
    • raceOwnsStatus flag (no Heartbeat/status conflicts)
    • QUEUE_POS Y=12 (corrected from XML: top surface of QueueRegion ≈ Y 11.5)
    • 15s CP-wait timeout for slow streaming connections
    • CanCollide nil-check on connection guard
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local CoreGui           = game:GetService("CoreGui")
local player            = Players.LocalPlayer

-- ── Anti-overlap ────────────────────────────────────────────
local guiTarget = (gethui and gethui()) or CoreGui
if guiTarget:FindFirstChild("J17_Midnight") then
    guiTarget.J17_Midnight:Destroy()
end

-- ════════════════════════════════════════════════════════════
--  LOADING SCREEN  (shown while the script sets itself up)
--  Camera does a 3D flythrough of the Race1 highway route.
-- ════════════════════════════════════════════════════════════

local loadGui = Instance.new("ScreenGui")
loadGui.Name = "J17_Load"; loadGui.IgnoreGuiInset = true
loadGui.ResetOnSpawn = false; loadGui.Parent = guiTarget

-- Full-screen dark background
local bg = Instance.new("Frame", loadGui)
bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.fromRGB(4,5,9)
bg.BorderSizePixel = 0

-- Subtle vignette gradient
local vig = Instance.new("UIGradient", bg)
vig.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0,0,0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6,8,14)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0)),
}
vig.Rotation = 45; vig.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0, 0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1, 0.6),
}

-- Title block
local titleLbl = Instance.new("TextLabel", bg)
titleLbl.Size = UDim2.new(1,0,0,50); titleLbl.Position = UDim2.new(0,0,0.22,0)
titleLbl.BackgroundTransparency = 1; titleLbl.Text = "MIDNIGHT CHASERS"
titleLbl.TextColor3 = Color3.fromRGB(0,160,255); titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 38

local subLbl = Instance.new("TextLabel", bg)
subLbl.Size = UDim2.new(1,0,0,24); subLbl.Position = UDim2.new(0,0,0.36,0)
subLbl.BackgroundTransparency = 1; subLbl.Text = "JOSEPEDOV V22"
subLbl.TextColor3 = Color3.fromRGB(60,100,160); subLbl.Font = Enum.Font.GothamBold
subLbl.TextSize = 16

-- Route preview strip (dot + label for each waypoint)
local routeY = 0.50
local ROUTE_LABELS = {"🚦 QUEUE", "◆ CP 27", "◆ CP 28", "◆ CP 29", "🏁 FINISH"}
local routeDots = {}
local totalDots = #ROUTE_LABELS
for i, label in ipairs(ROUTE_LABELS) do
    local xpct = (i-1)/(totalDots-1) * 0.7 + 0.15  -- 15% to 85%

    -- connector line before this dot
    if i > 1 then
        local prevX = (i-2)/(totalDots-1) * 0.7 + 0.15
        local lineW = xpct - prevX
        local lineF = Instance.new("Frame", bg)
        lineF.Size = UDim2.new(lineW,-4,0,2)
        lineF.Position = UDim2.new(prevX,6,routeY,4)
        lineF.BackgroundColor3 = Color3.fromRGB(20,30,50); lineF.BorderSizePixel=0
        routeDots[i] = routeDots[i] or {}
        routeDots[i].line = lineF
    end

    local dot = Instance.new("Frame", bg)
    dot.Size = UDim2.new(0,10,0,10); dot.Position = UDim2.new(xpct,-5,routeY,-0)
    dot.BackgroundColor3 = Color3.fromRGB(20,30,50); dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(0,5)

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(0,80,0,16); lbl.Position = UDim2.new(xpct,-40,routeY,14)
    lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=Color3.fromRGB(30,45,70); lbl.Font=Enum.Font.Code; lbl.TextSize=10

    routeDots[i] = routeDots[i] or {}
    routeDots[i].dot = dot; routeDots[i].lbl = lbl
end

-- Progress bar
local barTrack = Instance.new("Frame", bg)
barTrack.Size=UDim2.new(0.5,0,0,5); barTrack.Position=UDim2.new(0.25,0,0.68,0)
barTrack.BackgroundColor3=Color3.fromRGB(14,18,28); barTrack.BorderSizePixel=0
Instance.new("UICorner",barTrack).CornerRadius=UDim.new(0,3)

local barFill = Instance.new("Frame", barTrack)
barFill.Size=UDim2.new(0,0,1,0); barFill.BackgroundColor3=Color3.fromRGB(0,150,255)
barFill.BorderSizePixel=0; Instance.new("UICorner",barFill).CornerRadius=UDim.new(0,3)

local barTxt = Instance.new("TextLabel", bg)
barTxt.Size=UDim2.new(1,0,0,18); barTxt.Position=UDim2.new(0,0,0.72,0)
barTxt.BackgroundTransparency=1; barTxt.Text="Initialising..."
barTxt.TextColor3=Color3.fromRGB(40,65,100); barTxt.Font=Enum.Font.Code; barTxt.TextSize=12

-- Moving dot on progress bar (loader indicator)
local movDot = Instance.new("Frame", barFill)
movDot.Size=UDim2.new(0,8,0,8); movDot.Position=UDim2.new(1,-4,0.5,-4)
movDot.BackgroundColor3=Color3.fromRGB(100,200,255); movDot.BorderSizePixel=0
Instance.new("UICorner",movDot).CornerRadius=UDim.new(0,4)

-- Speed lines (horizontal streaks, simulating fast movement)
local speedLines = {}
math.randomseed(42)
for i = 1, 12 do
    local line = Instance.new("Frame", bg)
    local ypos = math.random(10, 90)/100
    local w    = math.random(60, 160)/1000
    local xpos = math.random(0, 80)/100
    line.Size=UDim2.new(w,0,0,1); line.Position=UDim2.new(xpos,0,ypos,0)
    line.BackgroundColor3=Color3.fromRGB(0,100,200); line.BorderSizePixel=0
    line.BackgroundTransparency=0.6+math.random()*0.3
    speedLines[i] = {frame=line, speed=math.random(40,120)/100, x=xpos, w=w}
end

-- Animate speed lines
local loadAnimConn = RunService.Heartbeat:Connect(function(dt)
    for _, sl in ipairs(speedLines) do
        sl.x = sl.x + sl.speed * dt * 0.15
        if sl.x > 1 then sl.x = -sl.w end
        sl.frame.Position = UDim2.new(sl.x, 0, sl.frame.Position.Y.Scale, 0)
    end
end)

-- Camera flythrough — Real 3D positions over the highway
-- Route data from XML: Queue(3260,1015) → CP27(2513,411) → CP28(2981,537) → CP29(3485,622)
-- NOTE: StreamingEnabled=true in this place (min radius 400 studs).
-- Checkpoint Parts are dynamically created by the SERVER only when a race session
-- begins — they don't exist at script load time, so this flythrough CANNOT stream
-- them. The actual streaming fix lives at the top of DoRaceLoop (see below).
-- The flythrough still correctly shows the highway route as a visual preview.
-- Camera is elevated above road (road Y ≈ 0, camera Y = 40-80)
local cam = Workspace.CurrentCamera
local prevCamType = cam.CameraType
cam.CameraType = Enum.CameraType.Scriptable

local CAM_ROUTE = {
    -- Sweeping bird's-eye over the queue zone, looking toward highway
    { CFrame.lookAt(Vector3.new(3180, 75, 1100), Vector3.new(2900, 0, 700)) },
    -- Low tracking shot along the highway toward CP27
    { CFrame.lookAt(Vector3.new(2900, 40, 600),  Vector3.new(2513, 0, 411)) },
    -- Over CP27, looking toward CP28
    { CFrame.lookAt(Vector3.new(2650, 55, 480),  Vector3.new(2981, 0, 537)) },
    -- Side angle on CP28
    { CFrame.lookAt(Vector3.new(3050, 45, 450),  Vector3.new(3485, 0, 622)) },
    -- Final sweeping look at finish area (CP29)
    { CFrame.lookAt(Vector3.new(3380, 60, 750),  Vector3.new(3485, 0, 622)) },
}
cam.CFrame = CAM_ROUTE[1][1]

-- Progress helper: updates bar, label, dots, and camera
local function SetProg(pct, msg, activeDot)
    TweenService:Create(barFill, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Size=UDim2.new(pct/100,0,1,0)}):Play()
    barTxt.Text = string.format("  %d%%  —  %s", math.floor(pct), msg)

    -- Camera tween to corresponding route waypoint
    local camIdx = math.max(1, math.min(#CAM_ROUTE, math.round(pct/100 * #CAM_ROUTE + 0.5)))
    TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {CFrame = CAM_ROUTE[camIdx][1]}):Play()

    -- Light up route dots
    for i, d in ipairs(routeDots) do
        local active = activeDot and i <= activeDot
        if d.dot then
            TweenService:Create(d.dot, TweenInfo.new(0.25),
                {BackgroundColor3 = active and Color3.fromRGB(0,150,255) or Color3.fromRGB(20,30,50)}):Play()
        end
        if d.lbl then
            d.lbl.TextColor3 = active and Color3.fromRGB(0,170,255) or Color3.fromRGB(30,45,70)
        end
        -- Light up connector line
        if d.line then
            TweenService:Create(d.line, TweenInfo.new(0.25),
                {BackgroundColor3 = active and Color3.fromRGB(0,100,200) or Color3.fromRGB(20,30,50)}):Play()
        end
    end
end

-- ════════════════════════════════════════════════════════════
--  INITIALISE EVERYTHING (while loading screen plays)
-- ════════════════════════════════════════════════════════════

SetProg(5,  "Reading config...", 1);  task.wait(0.3)

-- ── Config ──────────────────────────────────────────────────
local Config = {
    SpeedHack      = false,
    AutoRace       = false,
    InfNitro       = false,
    TrafficBlocked = false,
    FPS_Boosted    = false,
    FullBright     = false,
    Acceleration   = 3.0,
    MaxSpeed       = 320,  -- SpeedHack top speed
    AutoRaceSpeed  = 350,  -- AutoRace flight speed (separate, capped at AR_SPEED_CAP)
    Deadzone       = 0.1,
}

local AR_SPEED_CAP = 600  -- hard ceiling for AutoRace; >600 causes wall clipping

local OriginalTech    = Lighting.Technology
local OriginalAmbient = Lighting.Ambient
local OriginalOutdoor = Lighting.OutdoorAmbient
local OriginalClock   = Lighting.ClockTime

SetProg(20, "Scanning highway route...", 2); task.wait(0.4)

-- ── State ───────────────────────────────────────────────────
local currentSeat   = nil
local currentCar    = nil
local disabledCar   = nil   -- exact car whose collisions we disabled (FIX #1)

-- AR state: "IDLE" | "QUEUING" | "STARTING" | "RACING"
local AR_STATE      = "IDLE"
local raceThread    = nil
local raceOwnsStatus = false  -- when true, Heartbeat never writes status (FIX #3)

-- Race1 QueueRegion centre from XML.
-- Part centre Y=-7.515, size Y=38 → top surface ≈ Y=11.5.
-- Y=4 (old) was below road surface causing the car to clip into the gate.
local QUEUE_POS = Vector3.new(3260.5, 12, 1015.7)

-- ── Collision helpers (FIX #1) ──────────────────────────────
-- Always operate on a specific car reference, not the global currentCar.
-- This prevents mismatches when the car changes between disable/enable calls.
-- Car-side collision disable
local function DisableCollisions(car)
    if not car then return end
    disabledCar = car
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.CanCollide = false
        end
    end
    -- Also disable collisions on the seated character's body parts.
    -- DisableCollisions only touches car:GetDescendants(), so the player's
    -- Torso, Arms, Legs etc. remain CanCollide=true and can snag bridge
    -- underside geometry even when the car passes straight through it.
    local char = player.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end

local function RestoreCollisions()
    local car = disabledCar or currentCar
    if not car then return end
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.CanCollide = true
        end
    end
    -- Restore character body parts
    local char = player.Character
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
    disabledCar = nil
end

SetProg(40, "Mapping checkpoint gates...", 3); task.wait(0.4)

-- ── Race helpers ─────────────────────────────────────────────
local function FindPlayerRaceFolder()
    local racesWS = Workspace:FindFirstChild("Races")
    if not racesWS then return nil, nil end
    for _, raceN in ipairs(racesWS:GetChildren()) do
        local container = raceN:FindFirstChild("Races")
        if container then
            for _, uuidF in ipairs(container:GetChildren()) do
                local racers = uuidF:FindFirstChild("Racers")
                if racers and racers:FindFirstChild(player.Name) then
                    return uuidF, uuidF:FindFirstChild("State")
                end
            end
        end
    end
    return nil, nil
end

-- Find the next checkpoint Part (lowest numeric name child of Checkpoints IntValue).
-- clearedSet: table of cpIdx → true for CPs already passed client-side.
-- skipIdx: single extra index to skip (timed-out gate fallback).
-- WHY clearedSet: CP trigger parts are 0.001 studs thick — the car moves ~5 studs
-- per frame at race speed, so the server Touched event never fires and the Part
-- is never removed from the folder. Without a clearedSet, FindNextCP keeps
-- returning the same CP index forever after the car "passes" it.
local function FindNextCP(raceFolder, clearedSet, skipIdx)
    local cpVal = raceFolder:FindFirstChild("Checkpoints")
    if not cpVal then return nil, nil end
    local best, bestIdx = nil, math.huge
    for _, child in ipairs(cpVal:GetChildren()) do
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

SetProg(60, "Calibrating flight engine...", 4); task.wait(0.4)

-- ── Status label (wired after UI creation) ──────────────────
local _statusLbl = nil
local function SetStatus(text, r, g, b)
    if _statusLbl then
        _statusLbl.Text = text
        _statusLbl.TextColor3 = (r and Color3.fromRGB(r,g,b)) or Color3.fromRGB(110,115,140)
    end
end

-- ════════════════════════════════════════════════════════════
--  RACE LOOP COROUTINE
--  Owns the car entirely during RACING.
--  Heartbeat does ZERO car manipulation when raceOwnsStatus=true.
-- ════════════════════════════════════════════════════════════
local function DoRaceLoop(uuidFolder)
    raceOwnsStatus = true
    DisableCollisions(currentCar)

    -- clearedSet tracks CPs we've passed client-side.
    -- The server's Touched event is unreliable here because:
    --   • CP trigger Parts are only 0.001213 studs thick (from place XML)
    --   • At 320 studs/s the car moves ~5.3 studs/frame → completely skips the trigger
    --   • Server never fires Touched → never removes the Part → ChildRemoved never fires
    -- Solution: use client proximity (<= CLEAR_DIST studs from CP centre) as primary
    -- clearance, and record each cleared index in clearedSet so FindNextCP never
    -- returns the same CP twice, even though the server Part may still exist.
    local clearedSet = {}
    local skipIdx   = nil   -- fallback: skip a timed-out CP index

    -- Gate half-width from XML: Z-size of CP gate ≈ 60 studs → half ≈ 30.
    -- Use 40 studs (was 28) so high-speed approaches still trigger inside the arch.
    -- At 600 studs/s the car moves ~10 studs/frame — larger margin prevents skipping.
    local CLEAR_DIST = 40

    while Config.AutoRace and AR_STATE == "RACING" do

        -- ① Wait for the next CP Part to appear (server spawns them at race start)
        local gatePart, cpIdx
        local waitForCP = tick() + 15
        repeat
            gatePart, cpIdx = FindNextCP(uuidFolder, clearedSet, skipIdx)
            if not gatePart then task.wait(0.1) end
        until gatePart or tick() > waitForCP
              or not Config.AutoRace or AR_STATE ~= "RACING"

        if not gatePart then
            -- No more CPs in folder — race finished
            SetStatus("🏁 Race complete! Returning to queue...", 0, 255, 120)
            task.wait(2)

            -- TP car back to queue so user can re-enter the race instantly
            RestoreCollisions()  -- re-enable collisions before landing
            raceOwnsStatus = false
            local char2 = player.Character
            if char2 and char2:FindFirstChild("Humanoid") then
                local seat2 = char2.Humanoid.SeatPart
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

        skipIdx = nil  -- reset timeout-skip for this new CP

        -- ② ChildRemoved listener (secondary / backup — fires if server IS fast enough)
        local cpCleared = false
        local cpConn    = nil
        local cpParent  = gatePart.Parent
        if cpParent then
            cpConn = cpParent.ChildRemoved:Connect(function(removed)
                if removed == gatePart then cpCleared = true end
            end)
        end

        -- ③ Fly toward gate
        --    XZ: full AutoRaceSpeed toward CP gate.
        --    Y:  Target = gatePart.Y + 3  (CP gate centres sit at road level, Y≈-2 to -7,
        --        so +3 puts the car just above the tarmac — exactly where it should be).
        --
        --    WHY NOT downward raycast (v20 attempt):
        --        Most road surface Parts have CanCollide=false (cosmetic mesh). The ray
        --        passes straight through them, finds nothing, and falls back to
        --        gatePart.Y - 5 = underground. Car gets dragged below the highway.
        --
        --    Bridge/overpass guard — UPWARD raycast only:
        --        Bridge deck bottoms are at Y≈17–18 (confirmed from place XML).
        --        The car targeting Y≈0 is 17 studs below them — normally safe.
        --        But if the car is still descending from queue height (Y=12) when it
        --        crosses under a bridge, the ceiling can snag the roof.
        --        Fix: each frame, cast UP 20 studs. If a ceiling is detected within
        --        CEIL_CLEAR=10 studs, force targetY down to ceilY - CEIL_CLEAR so the
        --        car steers away from the underside rather than into it.
        local CEIL_CLEAR = 10  -- minimum clearance below any ceiling (studs)
        local flyLimit   = tick() + 30
        local arSpeed    = math.clamp(Config.AutoRaceSpeed, 50, AR_SPEED_CAP)

        local rcParams = RaycastParams.new()
        rcParams.FilterType = Enum.RaycastFilterType.Exclude

        while tick() < flyLimit do
            if not Config.AutoRace or AR_STATE ~= "RACING" then break end
            if cpCleared then break end
            if not gatePart.Parent then cpCleared = true; break end

            local car  = currentCar
            if not car then task.wait(0.05); continue end
            local root = car.PrimaryPart or currentSeat
            if not root then task.wait(0.05); continue end

            local char = player.Character
            rcParams.FilterDescendantsInstances = char and {car, char} or {car}

            local myPos  = root.Position
            local gateXZ = Vector3.new(gatePart.Position.X, 0, gatePart.Position.Z)
            local myXZ   = Vector3.new(myPos.X, 0, myPos.Z)
            local distXZ = (gateXZ - myXZ).Magnitude

            -- Primary: XZ-plane proximity (original).
            -- Fallback: full 3D distance with a generous radius — catches high-speed
            -- overshoots where the car blows past in XZ but is vertically displaced
            -- (e.g. being dragged underground, or still descending from queue height).
            local dist3D = (gatePart.Position - myPos).Magnitude
            if distXZ <= CLEAR_DIST or dist3D <= CLEAR_DIST + 12 then
                cpCleared = true
                break
            end

            -- Base target Y: road level (gate centre + 3).
            -- Gate centres sit at Y ≈ -2 to -7 → +3 = just above tarmac.
            local gateRoadY = gatePart.Position.Y + 3
            local targetY   = gateRoadY

            -- Ceiling guard: if something solid is less than CEIL_CLEAR studs above,
            -- nudge target down so the car clears the obstacle.
            -- MULTIPLIER reduced from 3 → 1 (was sending car 15+ studs underground).
            local ceilHit = Workspace:Raycast(myPos, Vector3.new(0, 20, 0), rcParams)
            if ceilHit then
                local clearance = ceilHit.Position.Y - myPos.Y
                if clearance < CEIL_CLEAR then
                    -- Gentle downward nudge — just enough to clear the ceiling
                    targetY = math.min(targetY, myPos.Y - (CEIL_CLEAR - clearance) * 1)
                end
            end

            -- ── FLOOR / CEILING CLAMP ──────────────────────────────────────────
            -- BUG FIX (v22): The ceiling guard with multiplier ×3 could push
            -- targetY to (myPos.Y - 15) or lower when bridge geometry was just
            -- overhead, dragging the car underground and past the CP without
            -- ever triggering the proximity check.
            --
            -- Floor clamp: never go below 1 stud under the gate road surface.
            --   Even if a bridge is directly overhead, the road is at gateRoadY.
            --   Targeting below that serves no purpose and sends the car underground.
            targetY = math.max(targetY, gateRoadY - 1)
            -- Ceiling clamp: never fly more than 10 studs above gate level either.
            targetY = math.min(targetY, gateRoadY + 10)

            local yErr  = targetY - myPos.Y
            local yGain = math.abs(yErr) > 8 and 8 or 5
            local yMax  = math.abs(yErr) > 8 and 80 or 20
            local velY  = math.clamp(yErr * yGain, -yMax, yMax)

            local dirXZ = (gateXZ - myXZ).Unit
            root.AssemblyLinearVelocity  = Vector3.new(dirXZ.X * arSpeed, velY, dirXZ.Z * arSpeed)
            root.AssemblyAngularVelocity = Vector3.zero

            SetStatus(string.format("→ CP #%d   %.0f studs", cpIdx, distXZ), 0, 190, 255)
            task.wait()
        end

        -- ④ Cleanup listener
        if cpConn then pcall(function() cpConn:Disconnect() end) end

        if not Config.AutoRace or AR_STATE ~= "RACING" then break end

        -- ⑤ Post-gate: record in clearedSet so this CP is never targeted again
        if cpCleared then
            clearedSet[cpIdx] = true
            SetStatus(string.format("✓ CP #%d cleared", cpIdx), 0, 230, 100)
            -- Coast: keep car moving forward at road level so gravity can't pull it
            -- underground during the gap between CP loops (CanCollide=false = no floor).
            -- Apply forward velocity + Y hold for 0.2 s instead of dead-coasting.
            local coastEnd = tick() + 0.2
            local arSpeed2 = math.clamp(Config.AutoRaceSpeed, 50, AR_SPEED_CAP)
            local root2    = (currentCar and (currentCar.PrimaryPart or currentSeat)) or nil
            local holdY    = (root2 and root2.Position.Y) or (gatePart.Position.Y + 3)
            while tick() < coastEnd do
                if not Config.AutoRace or AR_STATE ~= "RACING" then break end
                local r = currentCar and (currentCar.PrimaryPart or currentSeat)
                if r then
                    local fwd = r.CFrame.LookVector
                    -- Forward momentum + gentle Y hold so we don't sink
                    local yHoldErr = holdY - r.Position.Y
                    local yHoldVel = math.clamp(yHoldErr * 6, -15, 15)
                    r.AssemblyLinearVelocity  = Vector3.new(fwd.X*arSpeed2, yHoldVel, fwd.Z*arSpeed2)
                    r.AssemblyAngularVelocity = Vector3.zero
                end
                task.wait()
            end
        else
            -- 30s hard timeout — skip this index as a last resort
            SetStatus(string.format("CP #%d timed out — skipping", cpIdx), 255, 150, 0)
            skipIdx = cpIdx
            task.wait(0.2)
        end
    end

    -- ── Cleanup ──────────────────────────────────────────────
    RestoreCollisions()
    raceOwnsStatus = false

    if Config.AutoRace and AR_STATE == "RACING" then
        AR_STATE = "QUEUING"
    end
    raceThread = nil
end

SetProg(80, "Building interface...", 4); task.wait(0.3)

-- ════════════════════════════════════════════════════════════
--  FEATURE HELPERS
-- ════════════════════════════════════════════════════════════
local function ToggleTraffic()
    Config.TrafficBlocked = not Config.TrafficBlocked
    local ev = ReplicatedStorage:FindFirstChild("CreateNPCVehicle")
    if Config.TrafficBlocked then
        if ev then for _,c in pairs(getconnections(ev.OnClientEvent)) do c:Disable() end end
        for _,n in ipairs({"NPCVehicles","Traffic","Vehicles"}) do
            local f=Workspace:FindFirstChild(n); if f then f:ClearAllChildren() end
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
            if sethiddenproperty then sethiddenproperty(Lighting,"Technology",Enum.Technology.Voxel) end
            for _,v in ipairs(workspace:GetDescendants()) do pcall(function()
                if v:IsA("BasePart") then v.CastShadow=false
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false end
            end) end
        else
            Lighting.GlobalShadows = true
            if sethiddenproperty then sethiddenproperty(Lighting,"Technology",OriginalTech) end
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
        Lighting.Ambient=OriginalAmbient; Lighting.OutdoorAmbient=OriginalOutdoor
        Lighting.ClockTime=OriginalClock
    end
    return Config.FullBright
end

-- ════════════════════════════════════════════════════════════
--  UI — TABBED, PHONE-FRIENDLY  (220 × 360)
-- ════════════════════════════════════════════════════════════
local function Drag(frame)
    local drag, din, ds, sp
    frame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; ds=i.Position; sp=frame.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then drag=false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch then din=i end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i==din and drag then
            local d=i.Position-ds
            frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
end

local C = {
    BG     = Color3.fromRGB(11,12,18),
    Panel  = Color3.fromRGB(19,20,29),
    Row    = Color3.fromRGB(26,27,40),
    Accent = Color3.fromRGB(0,148,255),
    Green  = Color3.fromRGB(0,200,75),
    Orange = Color3.fromRGB(255,152,0),
    Red    = Color3.fromRGB(215,55,55),
    Text   = Color3.fromRGB(218,220,235),
    Dim    = Color3.fromRGB(105,110,140),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name="J17_Midnight"; ScreenGui.IgnoreGuiInset=true
ScreenGui.ResetOnSpawn=false; ScreenGui.Parent=guiTarget

-- Mini icon (shown when collapsed)
local IconF = Instance.new("Frame", ScreenGui)
IconF.Size=UDim2.new(0,38,0,38); IconF.Position=UDim2.new(1,-48,0.48,-19)
IconF.BackgroundTransparency=1; IconF.Visible=false; IconF.Active=true
local IconB = Instance.new("TextButton", IconF)
IconB.Size=UDim2.new(1,0,1,0); IconB.BackgroundColor3=C.Accent
IconB.Text="J"; IconB.TextColor3=Color3.new(1,1,1)
IconB.Font=Enum.Font.GothamBlack; IconB.TextSize=17
Instance.new("UICorner",IconB).CornerRadius=UDim.new(0,19)
Drag(IconF)

-- Main window
local Win = Instance.new("Frame", ScreenGui)
Win.Size=UDim2.new(0,220,0,360); Win.Position=UDim2.new(0,10,0.05,0)
Win.BackgroundColor3=C.BG; Win.BorderSizePixel=0; Win.Active=true
Win.ClipsDescendants=true
Instance.new("UICorner",Win).CornerRadius=UDim.new(0,10)
local WStroke=Instance.new("UIStroke",Win); WStroke.Color=C.Accent; WStroke.Thickness=1.2
Drag(Win)

-- Title bar
local TB = Instance.new("Frame", Win)
TB.Size=UDim2.new(1,0,0,30); TB.BackgroundColor3=C.Panel; TB.BorderSizePixel=0
-- Round top corners, square bottom via a cover strip
Instance.new("UICorner",TB).CornerRadius=UDim.new(0,10)
local TBFix=Instance.new("Frame",TB); TBFix.Size=UDim2.new(1,0,0.45,0)
TBFix.Position=UDim2.new(0,0,0.55,0); TBFix.BackgroundColor3=C.Panel; TBFix.BorderSizePixel=0

local TL=Instance.new("TextLabel",TB); TL.Size=UDim2.new(0.78,0,1,0)
TL.Position=UDim2.new(0,8,0,0); TL.BackgroundTransparency=1
TL.Text="J17 MIDNIGHT CHASERS"; TL.TextColor3=C.Accent
TL.Font=Enum.Font.GothamBlack; TL.TextSize=11; TL.TextXAlignment=Enum.TextXAlignment.Left

local MinB=Instance.new("TextButton",TB)
MinB.Size=UDim2.new(0,24,0,24); MinB.Position=UDim2.new(1,-28,0.5,-12)
MinB.BackgroundColor3=C.Row; MinB.Text="−"; MinB.TextColor3=C.Text
MinB.Font=Enum.Font.GothamBold; MinB.TextSize=16
Instance.new("UICorner",MinB).CornerRadius=UDim.new(0,6)
MinB.MouseButton1Click:Connect(function() Win.Visible=false; IconF.Visible=true end)
IconB.MouseButton1Click:Connect(function() Win.Visible=true; IconF.Visible=false end)

-- Tab bar
local TABH = 28
local TabBar = Instance.new("Frame", Win)
TabBar.Size=UDim2.new(1,-8,0,TABH); TabBar.Position=UDim2.new(0,4,0,32)
TabBar.BackgroundTransparency=1
local TabLL=Instance.new("UIListLayout",TabBar)
TabLL.FillDirection=Enum.FillDirection.Horizontal; TabLL.Padding=UDim.new(0,3)
TabLL.SortOrder=Enum.SortOrder.LayoutOrder

-- Content area starts below tab bar
local CONTENT_Y = 30+TABH+6
local CONTENT_H = 360-CONTENT_Y

local Pages,TabBtns,ActiveTab = {},{},nil

local function NewPage(name)
    local sf=Instance.new("ScrollingFrame",Win)
    sf.Size=UDim2.new(1,-4,0,CONTENT_H)
    sf.Position=UDim2.new(0,2,0,CONTENT_Y)
    sf.BackgroundTransparency=1; sf.ScrollBarThickness=3
    sf.ScrollBarImageColor3=C.Accent
    sf.AutomaticCanvasSize=Enum.AutomaticSize.Y
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.Visible=false
    local ll=Instance.new("UIListLayout",sf)
    ll.Padding=UDim.new(0,5)
    ll.HorizontalAlignment=Enum.HorizontalAlignment.Center
    ll.SortOrder=Enum.SortOrder.LayoutOrder
    local pp=Instance.new("UIPadding",sf)
    pp.PaddingTop=UDim.new(0,6); pp.PaddingBottom=UDim.new(0,6)
    Pages[name]=sf
end

local function SwitchTab(name)
    ActiveTab=name
    for n,p in pairs(Pages) do p.Visible=(n==name) end
    for n,b in pairs(TabBtns) do
        b.BackgroundColor3=(n==name) and C.Accent or C.Row
        b.TextColor3=(n==name) and Color3.new(1,1,1) or C.Dim
    end
end

local function NewTab(name, label, order)
    NewPage(name)
    local b=Instance.new("TextButton",TabBar)
    b.LayoutOrder=order; b.Size=UDim2.new(0,50,1,0)
    b.BackgroundColor3=C.Row; b.TextColor3=C.Dim
    b.Text=label; b.Font=Enum.Font.GothamBold; b.TextSize=9
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
    b.MouseButton1Click:Connect(function() SwitchTab(name) end)
    TabBtns[name]=b
end

NewTab("race",  "🏁Race",  1)
NewTab("car",   "🚗Car",   2)
NewTab("world", "🌏World", 3)
NewTab("misc",  "⚙Misc",  4)

-- ── Widget helpers ───────────────────────────────────────────
local function RowFrame(page, h, order)
    local f=Instance.new("Frame",Pages[page])
    f.Size=UDim2.new(0.95,0,0,h); f.BackgroundColor3=C.Row
    f.LayoutOrder=order
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,7)
    return f
end

local function SecLabel(page, text, order)
    local l=Instance.new("TextLabel",Pages[page])
    l.Size=UDim2.new(0.95,0,0,15); l.BackgroundTransparency=1
    l.Text=text; l.TextColor3=C.Dim; l.Font=Enum.Font.GothamBold; l.TextSize=9
    l.TextXAlignment=Enum.TextXAlignment.Left; l.LayoutOrder=order
    Instance.new("UIPadding",l).PaddingLeft=UDim.new(0,4)
end

-- Pill toggle
local function Toggle(page, label, order, callback)
    local r=RowFrame(page,38,order)

    local lbl=Instance.new("TextLabel",r)
    lbl.Size=UDim2.new(0.63,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=C.Text
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local pill=Instance.new("Frame",r)
    pill.Size=UDim2.new(0,42,0,22); pill.Position=UDim2.new(1,-50,0.5,-11)
    pill.BackgroundColor3=C.Row
    Instance.new("UICorner",pill).CornerRadius=UDim.new(0,11)
    local ps=Instance.new("UIStroke",pill); ps.Color=C.Dim; ps.Thickness=1

    local knob=Instance.new("Frame",pill)
    knob.Size=UDim2.new(0,16,0,16); knob.Position=UDim2.new(0,3,0.5,-8)
    knob.BackgroundColor3=C.Dim
    Instance.new("UICorner",knob).CornerRadius=UDim.new(0,8)

    local state=false
    local function setV(on)
        state=on
        pill.BackgroundColor3 = on and C.Accent or C.Row
        ps.Color = on and C.Accent or C.Dim
        knob.BackgroundColor3 = on and Color3.new(1,1,1) or C.Dim
        knob.Position = on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    end

    local cb=Instance.new("TextButton",r)
    cb.Size=UDim2.new(1,0,1,0); cb.BackgroundTransparency=1; cb.Text=""
    cb.MouseButton1Click:Connect(function()
        local res=callback(not state)
        setV(res~=nil and res or not state)
    end)
    return setV
end

-- Slider row (< > buttons) — used in Car tab
local function Slider(page, fmt, order, getV, decV, incV)
    local r=RowFrame(page,36,order)
    local lbl=Instance.new("TextLabel",r)
    lbl.Size=UDim2.new(0.58,0,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=string.format(fmt,getV())
    lbl.TextColor3=C.Text; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local function mkB(t,x)
        local b=Instance.new("TextButton",r)
        b.Size=UDim2.new(0,26,0,26); b.Position=UDim2.new(x,0,0.5,-13)
        b.BackgroundColor3=C.Panel; b.TextColor3=C.Text
        b.Text=t; b.Font=Enum.Font.GothamBold; b.TextSize=14
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
        return b
    end
    mkB("<",0.60).MouseButton1Click:Connect(function() decV(); lbl.Text=string.format(fmt,getV()) end)
    mkB(">",0.78).MouseButton1Click:Connect(function() incV(); lbl.Text=string.format(fmt,getV()) end)
end

-- Drag Slider — used in Race tab for AutoRace flight speed
-- minVal/maxVal: numeric range. getV/setV: getter and setter functions.
-- Value label colour-codes: blue=normal · orange=fast (>450) · red=at cap (600).
local function DragSlider(page, label, order, minVal, maxVal, getV, setV)
    local r = RowFrame(page, 58, order)

    -- Label (top-left)
    local nameLbl = Instance.new("TextLabel", r)
    nameLbl.Size     = UDim2.new(0.55, 0, 0, 18)
    nameLbl.Position = UDim2.new(0, 10, 0, 7)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text     = label
    nameLbl.TextColor3 = C.Text
    nameLbl.Font     = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Value readout (top-right)
    local valLbl = Instance.new("TextLabel", r)
    valLbl.Size     = UDim2.new(0.40, -10, 0, 18)
    valLbl.Position = UDim2.new(0.58, 0, 0, 7)
    valLbl.BackgroundTransparency = 1
    valLbl.Font     = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    -- Warning badge (shows "FAST" / "MAX")
    local warnLbl = Instance.new("TextLabel", r)
    warnLbl.Size     = UDim2.new(0, 34, 0, 14)
    warnLbl.Position = UDim2.new(1, -44, 0, 9)
    warnLbl.BackgroundTransparency = 1
    warnLbl.Font     = Enum.Font.GothamBold
    warnLbl.TextSize = 9
    warnLbl.TextXAlignment = Enum.TextXAlignment.Right

    -- Track background
    local track = Instance.new("Frame", r)
    track.Size             = UDim2.new(1, -20, 0, 6)
    track.Position         = UDim2.new(0, 10, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
    track.BorderSizePixel  = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

    -- Filled portion
    local fill = Instance.new("Frame", track)
    fill.BackgroundColor3 = C.Accent
    fill.BorderSizePixel  = 0
    fill.Size             = UDim2.new(0, 0, 1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    -- Draggable knob
    local knob = Instance.new("Frame", track)
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel  = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", knob).Color        = C.Dim

    -- Min / max labels below track
    local minTxt = Instance.new("TextLabel", r)
    minTxt.Size = UDim2.new(0, 30, 0, 10); minTxt.Position = UDim2.new(0, 10, 0, 45)
    minTxt.BackgroundTransparency = 1; minTxt.Text = tostring(minVal)
    minTxt.TextColor3 = C.Dim; minTxt.Font = Enum.Font.Code; minTxt.TextSize = 8
    minTxt.TextXAlignment = Enum.TextXAlignment.Left

    local maxTxt = Instance.new("TextLabel", r)
    maxTxt.Size = UDim2.new(0, 30, 0, 10); maxTxt.Position = UDim2.new(1, -40, 0, 45)
    maxTxt.BackgroundTransparency = 1; maxTxt.Text = tostring(maxVal).." MAX"
    maxTxt.TextColor3 = Color3.fromRGB(200, 55, 55); maxTxt.Font = Enum.Font.Code; maxTxt.TextSize = 8
    maxTxt.TextXAlignment = Enum.TextXAlignment.Right

    -- Sweet-spot tick mark at 500
    local sweetPct = (500 - minVal) / (maxVal - minVal)
    local tick500 = Instance.new("Frame", track)
    tick500.Size             = UDim2.new(0, 2, 1, 4)
    tick500.Position         = UDim2.new(sweetPct, -1, 0, -2)
    tick500.BackgroundColor3 = Color3.fromRGB(255, 152, 0)
    tick500.BorderSizePixel  = 0
    local sweetLbl = Instance.new("TextLabel", r)
    sweetLbl.Size = UDim2.new(0, 28, 0, 10)
    sweetLbl.Position = UDim2.new(sweetPct, -14, 0, 45)
    sweetLbl.BackgroundTransparency = 1; sweetLbl.Text = "↑500"
    sweetLbl.TextColor3 = Color3.fromRGB(255, 152, 0)
    sweetLbl.Font = Enum.Font.Code; sweetLbl.TextSize = 8

    -- Update display from a 0–1 percentage
    local function updateFromPct(pct)
        pct = math.clamp(pct, 0, 1)
        -- Snap to nearest 10
        local raw = minVal + pct * (maxVal - minVal)
        local val = math.clamp(math.round(raw / 10) * 10, minVal, maxVal)
        setV(val)
        local realPct = (val - minVal) / (maxVal - minVal)
        fill.Size     = UDim2.new(realPct, 0, 1, 0)
        knob.Position = UDim2.new(realPct, -7, 0.5, -7)

        -- Colour-code value and fill
        local col
        if val >= maxVal then
            col = Color3.fromRGB(215, 55, 55)
            warnLbl.Text = "MAX"; warnLbl.TextColor3 = col
        elseif val > 499 then
            col = Color3.fromRGB(255, 152, 0)
            warnLbl.Text = "FAST"; warnLbl.TextColor3 = col
        else
            col = C.Accent
            warnLbl.Text = ""
        end
        valLbl.Text      = val .. " st/s"
        valLbl.TextColor3 = col
        fill.BackgroundColor3 = col
        knob.BackgroundColor3 = val >= maxVal and Color3.fromRGB(215, 55, 55) or Color3.new(1,1,1)
    end

    -- Initialise display
    updateFromPct((getV() - minVal) / (maxVal - minVal))

    -- Input handling — drag or click anywhere on the track
    local dragging = false
    local function applyInput(inp)
        local absX  = track.AbsolutePosition.X
        local absW  = track.AbsoluteSize.X
        updateFromPct((inp.Position.X - absX) / absW)
    end

    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; applyInput(inp)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                      or inp.UserInputType == Enum.UserInputType.Touch) then
            applyInput(inp)
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ── Race tab content ─────────────────────────────────────────

-- AutoRace hero button
local arRow=RowFrame("race",50,1); arRow.BackgroundColor3=C.Panel
Instance.new("UIStroke",arRow).Color=C.Dim

local arTxt=Instance.new("TextLabel",arRow)
arTxt.Size=UDim2.new(0.78,0,0.52,0); arTxt.Position=UDim2.new(0,12,0.04,0)
arTxt.BackgroundTransparency=1; arTxt.Text="AutoRace: OFF"
arTxt.TextColor3=C.Dim; arTxt.Font=Enum.Font.GothamBlack
arTxt.TextSize=13; arTxt.TextXAlignment=Enum.TextXAlignment.Left

local arSub=Instance.new("TextLabel",arRow)
arSub.Size=UDim2.new(0.78,0,0.38,0); arSub.Position=UDim2.new(0,12,0.58,0)
arSub.BackgroundTransparency=1; arSub.Text="City Highway Race"
arSub.TextColor3=C.Dim; arSub.Font=Enum.Font.Gotham
arSub.TextSize=10; arSub.TextXAlignment=Enum.TextXAlignment.Left

local arDot=Instance.new("Frame",arRow)
arDot.Size=UDim2.new(0,9,0,9); arDot.Position=UDim2.new(1,-16,0.5,-4)
arDot.BackgroundColor3=C.Dim
Instance.new("UICorner",arDot).CornerRadius=UDim.new(0,5)

local arClickBtn=Instance.new("TextButton",arRow)
arClickBtn.Size=UDim2.new(1,0,1,0); arClickBtn.BackgroundTransparency=1; arClickBtn.Text=""

-- Status display
local statRow=RowFrame("race",38,2); statRow.BackgroundColor3=C.Panel
local statLbl=Instance.new("TextLabel",statRow)
statLbl.Size=UDim2.new(1,-10,1,0); statLbl.Position=UDim2.new(0,6,0,0)
statLbl.BackgroundTransparency=1; statLbl.Text="Status: Idle"
statLbl.TextColor3=C.Dim; statLbl.Font=Enum.Font.Code
statLbl.TextSize=11; statLbl.TextWrapped=true; statLbl.TextXAlignment=Enum.TextXAlignment.Left

-- Wire SetStatus to the label
_statusLbl = statLbl

SecLabel("race","FLIGHT SPEED",5)
DragSlider("race","AutoRace Speed",6, 50, AR_SPEED_CAP,
    function() return Config.AutoRaceSpeed end,
    function(v) Config.AutoRaceSpeed = math.clamp(v, 50, AR_SPEED_CAP) end)

-- AR button visual state
local function UpdateARVisual()
    local map={
        IDLE     = {arTxt="AutoRace: OFF",     col=C.Dim,    bg=C.Panel},
        QUEUING  = {arTxt="AutoRace: QUEUING", col=C.Orange, bg=C.Row},
        STARTING = {arTxt="AutoRace: STANDBY", col=C.Red,    bg=C.Row},
        RACING   = {arTxt="AutoRace: RACING",  col=C.Green,  bg=C.Row},
    }
    local s=map[AR_STATE] or map.IDLE
    arTxt.Text=s.arTxt; arTxt.TextColor3=s.col; arSub.TextColor3=s.col
    arRow.BackgroundColor3=s.bg; arDot.BackgroundColor3=s.col
    Instance.new("UIStroke",arRow).Color=s.col
end

arClickBtn.MouseButton1Click:Connect(function()
    Config.AutoRace = not Config.AutoRace

    if Config.AutoRace then
        -- Check if we're already in an active race
        local uuidF, stateV = FindPlayerRaceFolder()
        if uuidF then
            local sv = stateV and stateV.Value or ""
            if sv == "Racing" then
                AR_STATE="RACING"; UpdateARVisual()
                SetStatus("Already racing — joining loop!",0,200,80)
                if not raceThread then
                    raceThread = task.spawn(DoRaceLoop, uuidF)
                end
            else
                AR_STATE="STARTING"; UpdateARVisual()
                SetStatus("Race in countdown, standing by 🚦",255,152,0)
            end
            return
        end
        -- Not in a race — TP to queue
        AR_STATE="QUEUING"; UpdateARVisual()
        SetStatus("Teleporting to queue...",255,152,0)
        local char=player.Character
        if char and char:FindFirstChild("Humanoid") then
            local seat=char.Humanoid.SeatPart
            if seat and seat:IsA("VehicleSeat") then
                local car=seat.Parent
                local root=car.PrimaryPart or seat
                if root then
                    car:PivotTo(CFrame.new(QUEUE_POS))
                    root.AssemblyLinearVelocity=Vector3.zero
                    root.AssemblyAngularVelocity=Vector3.zero
                end
            end
        end
        SetStatus("Queued — drive into start gate",255,152,0)
    else
        -- Disable
        Config.AutoRace=false; AR_STATE="IDLE"
        if raceThread then task.cancel(raceThread); raceThread=nil end
        RestoreCollisions()           -- always restore the car we disabled (FIX #1)
        raceOwnsStatus=false
        UpdateARVisual()
        SetStatus("AutoRace OFF")
    end
end)

-- ── Car tab ──────────────────────────────────────────────────
SecLabel("car","DRIVING",1)
Toggle("car","⚡ Speed Hack",2,function(v) Config.SpeedHack=v; return v end)
SecLabel("car","NITRO",5)
Toggle("car","🔥 Infinite Nitro",6,function(v) Config.InfNitro=v; return v end)
SecLabel("car","TUNING",10)
Slider("car","Top Speed: %d",11,
    function() return Config.MaxSpeed end,
    function() Config.MaxSpeed=math.max(50,Config.MaxSpeed-50) end,
    function() Config.MaxSpeed=Config.MaxSpeed+50 end)
Slider("car","Acceleration: %.1f",12,
    function() return Config.Acceleration end,
    function() Config.Acceleration=math.max(0.5,Config.Acceleration-0.5) end,
    function() Config.Acceleration=Config.Acceleration+0.5 end)

-- ── World tab ─────────────────────────────────────────────────
SecLabel("world","TRAFFIC",1)
Toggle("world","🚫 Kill Traffic",2,function() return ToggleTraffic() end)
SecLabel("world","VISUALS",5)
Toggle("world","☀️ Full Bright",6,function() return ToggleFullBright() end)
SecLabel("world","PERFORMANCE",10)
Toggle("world","🖥️ FPS Boost",11,function() return ToggleFPSBoost() end)

-- ── Misc tab ─────────────────────────────────────────────────
SecLabel("misc","SETTINGS",1)
local function PlaceholderRow(page, text, order)
    local r=RowFrame(page,34,order); r.BackgroundColor3=C.Panel
    local l=Instance.new("TextLabel",r)
    l.Size=UDim2.new(1,-10,1,0); l.Position=UDim2.new(0,10,0,0)
    l.BackgroundTransparency=1; l.Text=text; l.TextColor3=C.Dim
    l.Font=Enum.Font.Gotham; l.TextSize=11; l.TextXAlignment=Enum.TextXAlignment.Left
end
PlaceholderRow("misc","🔧  Settings  (coming soon)",2)
PlaceholderRow("misc","💾  Save Config  (coming soon)",3)
PlaceholderRow("misc","📋  Changelog",4)
PlaceholderRow("misc","🔗  Credits  —  josepedov",5)

SwitchTab("race")

SetProg(95, "Finalising...", 5); task.wait(0.3)

-- ════════════════════════════════════════════════════════════
--  HEARTBEAT — handles state transitions and non-RACING logic
-- ════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()

    -- Full Bright enforcement
    if Config.FullBright then
        Lighting.Ambient=Color3.new(1,1,1)
        Lighting.OutdoorAmbient=Color3.new(1,1,1)
        Lighting.ClockTime=12
    end

    -- Update car handles
    local char=player.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    currentSeat=char.Humanoid.SeatPart
    if not currentSeat or not currentSeat:IsA("VehicleSeat") then currentCar=nil; return end
    currentCar=currentSeat.Parent

    -- A-Chassis values
    local gasVal,brakeVal,gearVal = (currentSeat.ThrottleFloat or 0), 0, 1
    local iface=player.PlayerGui:FindFirstChild("A-Chassis Interface")
    if iface and iface:FindFirstChild("Values") then
        local v=iface.Values
        if v:FindFirstChild("Throttle") then gasVal=v.Throttle.Value end
        if v:FindFirstChild("Brake") then brakeVal=v.Brake.Value end
        if v:FindFirstChild("Gear") then gearVal=v.Gear.Value end
    end

    -- Inf Nitro
    -- The game does NOT store nitro in NumberValue/IntValue children.
    -- It uses Attributes on the A-Chassis Values object:
    --   "CurrentBoost" = current nitro charge   (what we write to)
    --   "MaxBoost"     = max capacity           (what we read for the refill amount)
    -- We find the Values object via two paths (whichever resolves first):
    --   1. player.PlayerGui → A-Chassis Interface → Values
    --   2. currentCar:FindFirstChild("Values", true)  (deep search in the car)
    if Config.InfNitro then
        local valObj = nil
        local iface2 = player.PlayerGui:FindFirstChild("A-Chassis Interface")
        if iface2 then valObj = iface2:FindFirstChild("Values") end
        if not valObj then valObj = currentCar:FindFirstChild("Values", true) end
        if valObj then
            local maxB = valObj:GetAttribute("MaxBoost")
            if maxB and maxB > 0 then
                -- Refill CurrentBoost to MaxBoost every frame
                valObj:SetAttribute("CurrentBoost", maxB)
            end
        end
    end

    -- ── AutoRace state machine ─────────────────────────────
    if Config.AutoRace then

        if AR_STATE=="QUEUING" then
            local uuidF,stateV=FindPlayerRaceFolder()
            if uuidF then
                local sv=stateV and stateV.Value or ""
                if sv=="Racing" then
                    AR_STATE="RACING"; UpdateARVisual()
                    if not raceOwnsStatus then SetStatus("Race started! Launching loop...",0,210,80) end
                    if not raceThread then raceThread=task.spawn(DoRaceLoop,uuidF) end
                else
                    AR_STATE="STARTING"; UpdateARVisual()
                    if not raceOwnsStatus then SetStatus("Countdown — server moving car to grid 🚦",255,152,0) end
                end
            else
                -- Still waiting — gentle pulsing message
                if not raceOwnsStatus then
                    local t=math.floor(tick()*1.2)%2
                    SetStatus(t==0 and "⏳  Waiting for race start..." or "⏳  Drive into the start gate",255,152,0)
                end
            end

        elseif AR_STATE=="STARTING" then
            -- Pure poll — zero car touches
            local uuidF,stateV=FindPlayerRaceFolder()
            if uuidF then
                local sv=stateV and stateV.Value or ""
                if sv=="Racing" then
                    AR_STATE="RACING"; UpdateARVisual()
                    if not raceOwnsStatus then SetStatus("Race started! Launching loop...",0,210,80) end
                    if not raceThread then raceThread=task.spawn(DoRaceLoop,uuidF) end
                end
            else
                AR_STATE="QUEUING"; UpdateARVisual()
            end

        elseif AR_STATE=="RACING" then
            -- Coroutine has full ownership. Heartbeat touches NOTHING.
            -- If coroutine ended and changed state, update the button.
            if AR_STATE~="RACING" then UpdateARVisual() end
        end

        return  -- ← prevent falling into normal mode code below
    end

    -- ── Normal mode (AutoRace OFF) ─────────────────────────
    if AR_STATE~="IDLE" then
        AR_STATE="IDLE"; UpdateARVisual()
        if raceThread then task.cancel(raceThread); raceThread=nil end
        RestoreCollisions()   -- FIX #1: always restores disabledCar
        raceOwnsStatus=false
        SetStatus("AutoRace OFF")
    end

    -- SpeedHack
    local isRev=(gearVal==-1) or (brakeVal>0.1) or (gasVal<-0.1)
    if Config.SpeedHack then
        local rp=RaycastParams.new()
        rp.FilterDescendantsInstances={char,currentCar}
        rp.FilterType=Enum.RaycastFilterType.Exclude
        local grounded=Workspace:Raycast(currentSeat.Position,Vector3.new(0,-5,0),rp)
        if gasVal>Config.Deadzone and not isRev then
            if grounded then
                if currentSeat.AssemblyLinearVelocity.Magnitude < Config.MaxSpeed then
                    currentSeat.AssemblyLinearVelocity +=
                        currentSeat.CFrame.LookVector * Config.Acceleration
                    SetStatus("SpeedHack: BOOSTING",0,215,80)
                else
                    SetStatus("SpeedHack: MAX SPEED",255,200,0)
                end
            else
                SetStatus("SpeedHack: AIRBORNE",200,80,80)
            end
        else
            SetStatus(isRev and "Reversing..." or "Status: Idle")
        end
    else
        if not raceOwnsStatus then SetStatus("Status: Idle") end
    end
end)

-- ════════════════════════════════════════════════════════════
--  DISMISS LOADING SCREEN
-- ════════════════════════════════════════════════════════════
SetProg(100, "Ready!", 5)
task.wait(0.5)

-- Restore camera
loadAnimConn:Disconnect()
cam.CameraType = prevCamType

-- Fade the loading screen out
TweenService:Create(bg, TweenInfo.new(0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
    {BackgroundTransparency=1}):Play()
for _, d in ipairs(loadGui:GetDescendants()) do
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

print("[J22] Midnight Chasers — all systems ready")
print("[J22] AutoRace: floor-clamp fix · 3D fallback · stable coast | v22")

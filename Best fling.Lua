--[[════════════════════════════════════════════════════════════════════
    BEST FLING  ·  v4.0 MOBILE  ·  DELTA READY
    Panel: [Best Fling]  [✥ move] [✕]   center = ON/OFF square
    bottom = name box (never self-clears)
    Learns every game. Keeps its memory. Hides itself.
════════════════════════════════════════════════════════════════════]]

local ok, err = pcall(function()

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local VirtualUser  = game:GetService("VirtualUser")
local HttpSvc      = game:GetService("HttpService")
local TeleportSvc  = game:GetService("TeleportService")
local GuiSvc       = game:GetService("GuiService")

local LP = Players.LocalPlayer
assert(LP, "no local player")

local IS_TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled

--═══════════════ STORAGE ═══════════════
local DIR = "BestFling"
local MEM = DIR .. "/memory.json"
local BOX = DIR .. "/name.txt"
local POS = DIR .. "/pos.txt"

pcall(function() if isfolder and not isfolder(DIR) then makefolder(DIR) end end)

local function rd(p)
    local o
    pcall(function() if readfile and isfile and isfile(p) then o = readfile(p) end end)
    return o
end
local function wr(p, d)
    pcall(function() if writefile then writefile(p, d) end end)
end

local memory = { places = {}, wins = {}, power = 950 }
do
    local raw = rd(MEM)
    if raw then
        local d = HttpSvc:JSONDecode(raw)
        if type(d) == "table" then
            memory.places = d.places or {}
            memory.wins   = d.wins or {}
            memory.power  = d.power or 950
        end
    end
end
local function saveMem() pcall(function() wr(MEM, HttpSvc:JSONEncode(memory)) end) end

local placeKey = tostring(game.PlaceId)
memory.places[placeKey] = memory.places[placeKey] or { names = {} }
local learned = memory.places[placeKey].names

--═══════════════ ANTI ═══════════════
-- 1. anti-AFK, short random pokes
task.spawn(function()
    pcall(function()
        LP.Idled:Connect(function()
            for _ = 1, 2 do
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
                task.wait(0.2 + math.random() * 0.3)
            end
        end)
    end)
end)

-- 2. rejoin engine (job sticky, re-injects itself)
local LOADER = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/YOURNAME/bestfling/main/bestfling.lua"))()'

local function rejoin()
    pcall(function()
        if queue_on_teleport then queue_on_teleport(LOADER) end
        if syn and syn.queue_on_teleport then syn.queue_on_teleport(LOADER) end
        if Delta and Delta.queue_on_teleport then Delta.queue_on_teleport(LOADER) end
    end)
    pcall(function()
        TeleportSvc:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
    end)
end

-- 3. hook Kick
pcall(function()
    if type(hookfunction) == "function" then
        local old = LP.Kick
        hookfunction(LP.Kick, function(self, msg)
            task.spawn(function() task.wait(0.3) rejoin() end)
            return old(self, msg)
        end)
    end
end)

-- 4. kick watchdog: if we lose our player, come back
task.spawn(function()
    local gone = 0
    while true do
        task.wait(1)
        if LP.Parent == nil then
            gone = gone + 1
            if gone >= 2 then rejoin() break end
        else
            gone = 0
        end
    end
end)

-- 5. anti-ban: raise thread identity, hide the gui
pcall(function()
    if type(setthreadidentity) == "function" then setthreadidentity(8) end
end)

--═══════════════ NAME MATCHER ═══════════════
local function norm(s) return (tostring(s):lower():gsub("[^%w]", "")) end

local function lev(a, b)
    local la, lb = #a, #b
    if la == 0 then return lb end
    if lb == 0 then return la end
    local prev = {}
    for i = 0, lb do prev[i] = i end
    for i = 1, la do
        local cur = { [0] = i }
        for j = 1, lb do
            local c = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c)
        end
        prev = cur
    end
    return prev[lb]
end

local function score(q, n)
    q, n = norm(q), norm(n)
    if q == "" or n == "" then return 0 end
    if q == n then return 100 end
    if n:find(q, 1, true) then return 60 + math.floor(40 * (#q / #n)) end
    if q:find(n, 1, true) then return 55 end
    return math.floor((1 - lev(q, n) / math.max(#q, #n)) * 55)
end

local function bestMatch(q)
    local best, top = nil, 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local s = math.max(score(q, p.Name), score(q, p.DisplayName))
            for _, a in ipairs(learned) do
                if norm(a) == norm(p.Name) then s = s + 12 end
            end
            if s > top then top, best = s, p end
        end
    end
    if q == "" then return best end
    return best
end

--═══════════════ HACKING: BODY BREAKER ═══════════════
local function strip(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function()
                d.CanCollide = false
                d.CanTouch   = false
                if d.Anchored then d.Anchored = false end
            end)
        end
    end
end

local function grab(hrp)
    -- 3 ownership attempts, then verify
    pcall(function() hrp:SetNetworkOwner(LP) end)
    if hrp:GetNetworkOwner() ~= LP then
        pcall(function() hrp:SetNetworkOwnershipAuto() end)
        task.wait(0.02)
        pcall(function() hrp:SetNetworkOwner(LP) end)
    end
    return hrp:GetNetworkOwner() == LP
end

--═══════════════ FLING ═══════════════
local function fling(char)
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    strip(char)
    local owned = grab(hrp)
    local before = hrp.Position
    local p = memory.power + math.random(-150, 150)

    pcall(function()
        char:PivotTo(hrp.CFrame * CFrame.Angles(
            math.rad(math.random(-180, 180)),
            math.rad(math.random(-180, 180)), 0))
    end)

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.new(math.random(-p, p), p * 1.5, math.random(-p, p))
    bv.Parent = hrp

    local bav = Instance.new("BodyAngularVelocity")
    bav.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bav.AngularVelocity = Vector3.new(math.random(-600, 600), math.random(-600, 600), math.random(-600, 600))
    bav.Parent = hrp

    pcall(function()
        hrp.AssemblyLinearVelocity = bv.Velocity
    end)

    -- verify it actually moved; if not, hard-launch it
    task.delay(0.18, function()
        if not hrp or not hrp.Parent then return end
        if (hrp.Position - before).Magnitude < 4 then
            pcall(function()
                hrp.CFrame = hrp.CFrame + Vector3.new(0, 45, 0)
                hrp.AssemblyLinearVelocity = Vector3.new(
                    math.random(-p, p), p * 1.8, math.random(-p, p))
            end)
        end
    end)

    task.delay(0.85, function()
        pcall(function() bv:Destroy() end)
        pcall(function() bav:Destroy() end)
    end)

    if owned then memory.wins[placeKey] = (memory.wins[placeKey] or 0) + 1 end
    return true
end

--═══════════════ STATE / UI ═══════════════
local running, target, returnCF, conns = false, nil, nil, {}
local gui, frame, box, toggle, tLabel, status, handle, close, scale

local function track(c) table.insert(conns, c) return c end

local function parentForGui()
    local p
    pcall(function() if gethui then p = gethui() end end)
    return p or (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui")) or LP:WaitForChild("PlayerGui")
end

local function clampPos(px, py)
    local vp = workspace.CurrentCamera.ViewportSize
    local sz = frame.AbsoluteSize
    local maxX = math.max(0, vp.X - sz.X)
    local maxY = math.max(0, vp.Y - sz.Y)
    return UDim2.fromOffset(math.clamp(px, 0, maxX), math.clamp(py, 0, maxY))
end

local function build()
    gui = Instance.new("ScreenGui")
    gui.Name = "BestFlingUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999999
    gui.Parent = parentForGui()

    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        if Delta and Delta.protect_gui then Delta.protect_gui(gui) end
        if type(protect_gui) == "function" then protect_gui(gui) end
    end)

    frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(250, 200)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
    local st = Instance.new("UIStroke", frame)
    st.Color = Color3.fromRGB(62, 62, 74)
    st.Thickness = 1.5

    scale = Instance.new("UIScale")
    scale.Scale = IS_TOUCH and 1.15 or 1
    scale.Parent = frame

    local saved = rd(POS)
    if saved then
        local x, y = saved:match("(-?%d+),(%d+)")
        frame.Position = UDim2.fromOffset(tonumber(x) or 16, tonumber(y) or 90)
    else
        frame.Position = UDim2.new(0, 16, 0.5, -100)
    end

    -- title (drag target on touch)
    local title = Instance.new("TextButton")
    title.Size = UDim2.new(1, -110, 0, 30)
    title.Position = UDim2.fromOffset(12, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(238, 238, 248)
    title.Text = "Best Fling"
    title.Parent = frame

    -- move handle
    handle = Instance.new("TextButton")
    handle.Size = UDim2.fromOffset(46, 30)
    handle.Position = UDim2.new(1, -84, 0, 6)
    handle.BackgroundColor3 = Color3.fromRGB(34, 34, 43)
    handle.Text = "✥"
    handle.TextColor3 = Color3.fromRGB(180, 180, 200)
    handle.Font = Enum.Font.GothamBold
    handle.TextSize = 17
    handle.AutoButtonColor = false
    handle.Parent = frame
    Instance.new("UICorner", handle).CornerRadius = UDim.new(0, 7)

    -- close
    close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(34, 30)
    close.Position = UDim2.new(1, -36, 0, 6)
    close.BackgroundColor3 = Color3.fromRGB(72, 26, 33)
    close.Text = "✕"
    close.TextColor3 = Color3.fromRGB(255, 155, 165)
    close.Font = Enum.Font.GothamBold
    close.TextSize = 15
    close.AutoButtonColor = false
    close.Parent = frame
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)

    -- big square toggle
    toggle = Instance.new("TextButton")
    toggle.Size = UDim2.fromOffset(78, 78)
    toggle.Position = UDim2.new(0.5, -39, 0, 46)
    toggle.BackgroundColor3 = Color3.fromRGB(74, 26, 33)
    toggle.AutoButtonColor = false
    toggle.Parent = frame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 11)

    tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.fromScale(1, 1)
    tLabel.BackgroundTransparency = 1
    tLabel.Font = Enum.Font.GothamBlack
    tLabel.TextSize = 20
    tLabel.TextColor3 = Color3.fromRGB(255, 200, 206)
    tLabel.Text = "OFF"
    tLabel.Parent = toggle

    status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -24, 0, 16)
    status.Position = UDim2.fromOffset(12, 130)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextColor3 = Color3.fromRGB(120, 120, 142)
    status.Text = "idle"
    status.Parent = frame

    -- name box
    box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -24, 0, 38)
    box.Position = UDim2.new(0, 12, 1, -50)
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 16
    box.TextColor3 = Color3.fromRGB(232, 232, 242)
    box.PlaceholderText = "type a name"
    box.PlaceholderColor3 = Color3.fromRGB(96, 96, 112)
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Text = rd(BOX) or ""
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 9)
    local pad = Instance.new("UIPadding", box)
    pad.PaddingLeft = UDim.new(0, 10)

    box.FocusLost:Connect(function()
        wr(BOX, box.Text)
        if running then target = bestMatch(box.Text) end
    end)
end

--═══════════════ DRAG (touch + mouse, clamped, saved) ═══════════════
local function bindDrag()
    local on, startPos, startAbs = false, nil, nil

    local function begin(i)
        on = true
        startPos = i.Position
        startAbs = frame.AbsolutePosition
    end

    for _, obj in ipairs({ handle, gui and nil or nil }) do end

    local function attach(obj)
        obj.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                begin(i)
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then
                        on = false
                        local a = frame.AbsolutePosition
                        wr(POS, math.floor(a.X) .. "," .. math.floor(a.Y))
                    end
                end)
            end
        end)
    end

    attach(handle)
    attach(frame:FindFirstChild("BestFling") or frame)
    -- attach the title bar too
    for _, c in ipairs(frame:GetChildren()) do
        if c:IsA("TextButton") and c.Text == "Best Fling" then attach(c) break end
    end

    track(UIS.InputChanged:Connect(function(i)
        if not on then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - startPos
            frame.Position = clampPos(startAbs.X + d.X, startAbs.Y + d.Y)
        end
    end))

    track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local a = frame.AbsolutePosition
        frame.Position = clampPos(a.X, a.Y)
    end))
end

--═══════════════ CORE ═══════════════
local function myHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function pulse()
    if not running then return end
    strip(LP.Character)
    if target and target.Character then strip(target.Character) end
end

local function chase()
    while running do
        if not target or not target.Parent or not target.Character then
            target = bestMatch(box.Text)
            if target then
                status.Text = "locked: " .. target.Name
                if not table.find(learned, target.Name) then
                    table.insert(learned, target.Name)
                    saveMem()
                end
            else
                status.Text = "nobody here"
            end
            task.wait(0.2)
        else
            local char = target.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local mine = myHRP()
                if mine then
                    mine.CFrame = hrp.CFrame * CFrame.new(0, 2.5, 3.5)
                    mine.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity
                end
                fling(char)
                local t0 = os.clock()
                while running and target and target.Parent and hum.Health > 0
                      and os.clock() - t0 < 0.65 do
                    task.wait()
                end
            else
                task.wait(0.05)
                if target and target.Character then
                    local h2 = target.Character:FindFirstChildOfClass("Humanoid")
                    if h2 then
                        repeat task.wait() until not running or h2.Health > 0 or not h2.Parent
                    end
                end
            end
        end
        task.wait()
    end
end

local function on()
    if running then return end
    local mine = myHRP()
    if mine then returnCF = mine.CFrame end
    target = bestMatch(box.Text)
    if not target then
        status.Text = "no match"
        return
    end
    running = true
    toggle.BackgroundColor3 = Color3.fromRGB(24, 72, 40)
    tLabel.TextColor3 = Color3.fromRGB(190, 255, 208)
    tLabel.Text = "ON"
    status.Text = "locked: " .. target.Name
    wr(BOX, box.Text)
    saveMem()
    task.spawn(chase)
end

local function off()
    running = false
    toggle.BackgroundColor3 = Color3.fromRGB(74, 26, 33)
    tLabel.TextColor3 = Color3.fromRGB(255, 200, 206)
    tLabel.Text = "OFF"
    status.Text = "idle"
    local mine = myHRP()
    if mine then
        if returnCF then pcall(function() mine.CFrame = returnCF end) end
        pcall(function() mine.AssemblyLinearVelocity = Vector3.zero end)
    end
    target = nil
    saveMem()
end

local function killAll()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    saveMem()
    pcall(function() if gui then gui:Destroy() end)
    gui = nil
end

--═══════════════ WIRE ═══════════════
build()
bindDrag()

toggle.Activated:Connect(function() if running then off() else on() end end)
close.Activated:Connect(killAll)

-- collision + anti-void + anti-anchor
local ticker = 0
track(RunService.Heartbeat:Connect(function()
    if not running then return end
    ticker = ticker + 1
    if ticker % 5 == 0 then pulse() end

    local mine = myHRP()
    if mine then
        if mine.Anchored then mine.Anchored = false end
        if mine.Position.Y < -80 then
            local th = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if th then
                mine.CFrame = th.CFrame * CFrame.new(0, 2.5, 3.5)
            elseif returnCF then
                mine.CFrame = returnCF
            end
        end
    end
end))

track(LP.CharacterAdded:Connect(function()
    task.wait(0.35)
    if running then strip(LP.Character) end
end))

track(Players.PlayerRemoving:Connect(function(p)
    if p == target then
        target = nil
        status.Text = "target left"
    end
end))

task.spawn(function()
    while gui and gui.Parent do
        task.wait(15)
        saveMem()
    end
end)

-- unparent watchdog
task.spawn(function()
    while gui do
        task.wait(2.5)
        if gui and not gui.Parent then
            pcall(function() gui.Parent = parentForGui() end)
        end
    end
end)

end)

if not ok then warn("[BestFling] " .. tostring(err)) end

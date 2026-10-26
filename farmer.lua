--[[
    ╔══════════════════════════════════════════════╗
    ║           ASTRALEX TAXI FARMER v7            ║
    ║   Minimal UI: Header + Start/Stop            ║
    ╚══════════════════════════════════════════════╝
]]

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Debris              = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CONFIG = {
    JOB_NAME       = "TaxiJOB",
    RIDER_PREFIX   = "TaxiRider_",
    STOP_ZONE_NAME = "TaxiStopZone",
    
    WAIT_AT_JOB    = 3.0,
    E_HOLD_JOB     = 1.5,
    WAIT_BEFORE_E  = 3.0,
    E_HOLD_RIDER   = 1.5,
    WAIT_AT_STOP   = 3.0,
    WAIT_NO_RIDER  = 3.0,
    BETWEEN_STEPS  = 1.0,
    HEIGHT_OFFSET  = 3,
}

local State = { running = false, conn = nil }
local E_KEY = Enum.KeyCode.E
local VK_E  = 0x45

------------------------------------------------------------
-- THEME
------------------------------------------------------------
local Theme = {
    Bg         = Color3.fromRGB(10, 11, 18),
    BgDark     = Color3.fromRGB(8, 9, 14),
    Card       = Color3.fromRGB(19, 22, 34),
    CardHover  = Color3.fromRGB(25, 29, 45),
    Stroke     = Color3.fromRGB(38, 42, 60),
    Accent     = Color3.fromRGB(139, 92, 246),
    Accent2    = Color3.fromRGB(99, 102, 241),
    Accent3    = Color3.fromRGB(59, 130, 246),
    AccentGlow = Color3.fromRGB(167, 139, 250),
    Text       = Color3.fromRGB(240, 242, 248),
    TextMuted  = Color3.fromRGB(88, 94, 118),
    Green      = Color3.fromRGB(22, 163, 74),
    GreenGlow  = Color3.fromRGB(34, 197, 94),
    Red        = Color3.fromRGB(185, 28, 28),
    RedGlow    = Color3.fromRGB(220, 38, 38),
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function tw(obj, time, props, style, dir)
    if not obj then return end
    pcall(function()
        TweenService:Create(obj, TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
    end)
end

local function addCorner(parent, r)
    if not parent then return nil end
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 12); c.Parent = parent; return c
end

local function addGradient(parent, c1, c2, rot)
    if not parent then return nil end
    local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(c1, c2); g.Rotation = rot or 0; g.Parent = parent; return g
end

local function addStroke(parent, color, thickness, transparency)
    if not parent then return nil end
    local s = Instance.new("UIStroke"); s.Color = color or Theme.Stroke; s.Thickness = thickness or 1; s.Transparency = transparency or 0; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = parent; return s
end

local function addGlow(parent, color, size)
    if not parent then return nil end
    local g = Instance.new("ImageLabel")
    g.BackgroundTransparency = 1; g.Image = "rbxassetid://5028857084"; g.ImageColor3 = color or Theme.Accent
    g.ImageTransparency = 0.4; g.ScaleType = Enum.ScaleType.Slice; g.SliceCenter = Rect.new(24, 24, 276, 276)
    g.Size = UDim2.new(1, (size or 30) * 2, 1, (size or 30) * 2); g.Position = UDim2.new(0, -(size or 30), 0, -(size or 30))
    g.ZIndex = 0; g.Parent = parent; return g
end

local function ripple(button)
    if not button then return end
    local r = Instance.new("Frame")
    r.AnchorPoint = Vector2.new(0.5, 0.5); r.BackgroundColor3 = Color3.new(1, 1, 1); r.BackgroundTransparency = 0.6
    r.BorderSizePixel = 0; r.Size = UDim2.new(0, 0, 0, 0); r.Position = UDim2.new(0.5, 0, 0.5, 0)
    r.ZIndex = (button.ZIndex or 1) + 1; r.Parent = button; addCorner(r, 999)
    tw(r, 0.55, { Size = UDim2.new(0, 220, 0, 220), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    Debris:AddItem(r, 0.6)
end

------------------------------------------------------------
-- KEY SIM
------------------------------------------------------------
local hasKP = (type(keypress) == "function" and type(keyrelease) == "function")

local function pressE()
    if hasKP then pcall(function() keypress(VK_E) end) end
    pcall(function() VirtualInputManager:SendKeyEvent(true, E_KEY, false, game) end)
    pcall(function() VirtualInputManager:SendKeyEvent(true, E_KEY, false, nil) end)
end

local function releaseE()
    if hasKP then pcall(function() keyrelease(VK_E) end) end
    pcall(function() VirtualInputManager:SendKeyEvent(false, E_KEY, false, game) end)
    pcall(function() VirtualInputManager:SendKeyEvent(false, E_KEY, false, nil) end)
end

local function holdE(duration)
    pressE(); task.wait(duration or 1); releaseE()
end

------------------------------------------------------------
-- GAME HELPERS
------------------------------------------------------------
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(pos)
    local hrp = getHRP()
    if not hrp or not pos then return false end
    pcall(function()
        hrp.CFrame = CFrame.new(pos); hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

local function findExact(name)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == name then return obj end
    end
    return nil
end

local function findMyRider()
    local myId = tostring(LocalPlayer.UserId)
    local targetName = CONFIG.RIDER_PREFIX .. myId
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == targetName then return obj end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if string.sub(obj.Name, 1, #CONFIG.RIDER_PREFIX) == CONFIG.RIDER_PREFIX then
            if string.find(obj.Name, myId, 1, true) then return obj end
        end
    end
    return nil
end

local function getPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp.Position end
        local ok, cf = pcall(function() return obj:GetModelCFrame() end)
        if ok and cf then return cf.Position end
        for _, p in ipairs(obj:GetDescendants()) do
            if p:IsA("BasePart") then return p.Position end
        end
    end
    return nil
end

------------------------------------------------------------
-- SCREEN GUI
------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AstralexTaxiFarmer"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 998

local ok1 = pcall(function() screenGui.Parent = (gethui and gethui()) end)
if not ok1 or not screenGui.Parent then
    pcall(function() screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
end
if not screenGui.Parent then return end

------------------------------------------------------------
-- MAIN WINDOW (компактный)
------------------------------------------------------------
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 420, 0, 240)
main.Position = UDim2.new(0.5, -210, 0.5, -120)
main.BackgroundColor3 = Theme.Bg
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Parent = screenGui
addCorner(main, 20)
addGlow(main, Theme.Accent, 30)

local mainStroke = addStroke(main, Color3.new(1, 1, 1), 1, 0.85)
if mainStroke then
    local sg = Instance.new("UIGradient")
    sg.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.Accent), ColorSequenceKeypoint.new(0.5, Theme.Accent2), ColorSequenceKeypoint.new(1, Theme.Accent3) })
    sg.Rotation = 45; sg.Parent = mainStroke
end

local innerGrad = Instance.new("UIGradient")
innerGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 17, 26)), ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 9, 14)) })
innerGrad.Rotation = 135; innerGrad.Parent = main

------------------------------------------------------------
-- HEADER
------------------------------------------------------------
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = Theme.BgDark
header.BackgroundTransparency = 0.15
header.BorderSizePixel = 0
header.ClipsDescendants = true
header.Parent = main
addCorner(header, 20)

local headerBg = Instance.new("Frame")
headerBg.Size = UDim2.new(1, 0, 1, 0); headerBg.BorderSizePixel = 0; headerBg.Parent = header; addCorner(headerBg, 20)
local headerBgGrad = Instance.new("UIGradient")
headerBgGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 24, 38)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 24, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 24, 38)) })
headerBgGrad.Parent = headerBg

task.spawn(function()
    local t = 0
    while header.Parent do
        t = t + 0.008; headerBgGrad.Rotation = math.sin(t) * 20; task.wait(0.03)
    end
end)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 20); headerFix.Position = UDim2.new(0, 0, 1, -20)
headerFix.BackgroundColor3 = Color3.fromRGB(22, 24, 38); headerFix.BorderSizePixel = 0; headerFix.ZIndex = 1; headerFix.Parent = header

local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, 0, 0, 1); headerLine.Position = UDim2.new(0, 0, 1, -1)
headerLine.BackgroundColor3 = Color3.new(1, 1, 1); headerLine.BorderSizePixel = 0; headerLine.ZIndex = 3; headerLine.Parent = header

local headerLineGrad = Instance.new("UIGradient")
headerLineGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(1, 1) })
headerLineGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Theme.Accent), ColorSequenceKeypoint.new(1, Theme.Accent2) })
headerLineGrad.Parent = headerLine

local logoBox = Instance.new("Frame")
logoBox.Size = UDim2.new(0, 40, 0, 40); logoBox.Position = UDim2.new(0, 22, 0.5, -20)
logoBox.BackgroundColor3 = Theme.Accent; logoBox.BorderSizePixel = 0; logoBox.ZIndex = 4; logoBox.Parent = header
addCorner(logoBox, 12); addGlow(logoBox, Theme.AccentGlow, 12)

local logoGrad = addGradient(logoBox, Theme.Accent, Theme.Accent3, 45)

task.spawn(function()
    while logoBox.Parent and logoGrad do
        logoGrad.Rotation = (logoGrad.Rotation + 0.6) % 360; task.wait(0.03)
    end
end)

local logoText = Instance.new("TextLabel")
logoText.BackgroundTransparency = 1; logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.Font = Enum.Font.GothamBlack; logoText.Text = "T"; logoText.TextSize = 22; logoText.TextColor3 = Color3.new(1, 1, 1)
logoText.ZIndex = 5; logoText.Parent = logoBox

local brandText = Instance.new("TextLabel")
brandText.BackgroundTransparency = 1; brandText.Position = UDim2.new(0, 76, 0, 22)
brandText.Size = UDim2.new(1, -180, 0, 26); brandText.Font = Enum.Font.GothamBold
brandText.Text = "TAXI FARMER"; brandText.TextSize = 20; brandText.TextColor3 = Theme.Text
brandText.TextXAlignment = Enum.TextXAlignment.Left; brandText.ZIndex = 4; brandText.Parent = header

local brandGrad = Instance.new("UIGradient")
brandGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 160, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 180, 255)) })
brandGrad.Rotation = 15; brandGrad.Parent = brandText

------------------------------------------------------------
-- CLOSE BUTTON
------------------------------------------------------------
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36); closeBtn.Position = UDim2.new(1, -48, 0.5, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 40); closeBtn.BorderSizePixel = 0
closeBtn.Text = ""; closeBtn.AutoButtonColor = false; closeBtn.ZIndex = 5; closeBtn.Parent = header
addCorner(closeBtn, 10); addStroke(closeBtn, Color3.fromRGB(120, 40, 60), 1, 0.3)

local line1 = Instance.new("Frame")
line1.Size = UDim2.new(0, 16, 0, 3); line1.Position = UDim2.new(0.5, -8, 0.5, -1.5)
line1.BackgroundColor3 = Color3.fromRGB(255, 200, 200); line1.BorderSizePixel = 0; line1.Rotation = 45
line1.ZIndex = 6; line1.Parent = closeBtn; addCorner(line1, 999)

local line2 = Instance.new("Frame")
line2.Size = UDim2.new(0, 16, 0, 3); line2.Position = UDim2.new(0.5, -8, 0.5, -1.5)
line2.BackgroundColor3 = Color3.fromRGB(255, 200, 200); line2.BorderSizePixel = 0; line2.Rotation = -45
line2.ZIndex = 6; line2.Parent = closeBtn; addCorner(line2, 999)

closeBtn.MouseEnter:Connect(function()
    tw(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(200, 50, 60) })
    tw(line1, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
    tw(line2, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
end)
closeBtn.MouseLeave:Connect(function()
    tw(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(60, 30, 40) })
    tw(line1, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 200, 200) })
    tw(line2, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 200, 200) })
end)

closeBtn.MouseButton1Click:Connect(function()
    State.running = false; releaseE()
    if screenGui then
        for _, gui in ipairs(screenGui:GetDescendants()) do
            if gui:IsA("Frame") then pcall(function() tw(gui, 0.25, { BackgroundTransparency = 1 }) end)
            elseif gui:IsA("TextLabel") then pcall(function() tw(gui, 0.25, { TextTransparency = 1 }) end)
            elseif gui:IsA("TextButton") then pcall(function() tw(gui, 0.25, { TextTransparency = 1, BackgroundTransparency = 1 }) end) end
        end
        task.wait(0.3); screenGui:Destroy()
    end
end)

------------------------------------------------------------
-- CONTENT (только кнопки)
------------------------------------------------------------
local content = Instance.new("Frame")
content.Position = UDim2.new(0, 0, 0, 72)
content.Size = UDim2.new(1, 0, 1, -72)
content.BackgroundTransparency = 1
content.Parent = main

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 20); contentPad.PaddingBottom = UDim.new(0, 20)
contentPad.PaddingLeft = UDim.new(0, 22); contentPad.PaddingRight = UDim.new(0, 22)
contentPad.Parent = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 12); contentLayout.SortOrder = Enum.SortOrder.LayoutOrder; contentLayout.Parent = content

local function makeButton(order, text, color1, color2, strokeColor)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 56)
    card.BackgroundColor3 = Theme.Card; card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0; card.LayoutOrder = order; card.Parent = content
    addCorner(card, 14); addStroke(card, Theme.Stroke, 1, 0.4)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundColor3 = color1; btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 16; btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text; btn.TextStrokeTransparency = 0; btn.TextStrokeColor3 = strokeColor
    btn.AutoButtonColor = false; btn.ZIndex = 5; btn.Parent = card
    addCorner(btn, 14); addGradient(btn, color1, color2, 20); addStroke(btn, Color3.new(1, 1, 1), 1, 0.6)
    
    return btn
end

-- START
local startBtn = makeButton(1, "▶  START", Theme.Green, Theme.GreenGlow, Color3.fromRGB(0, 55, 20))
-- STOP
local stopBtn = makeButton(2, "■  STOP", Theme.Red, Theme.RedGlow, Color3.fromRGB(75, 0, 0))

------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------
local function mainLoop()
    while State.running do
        -- 1) TaxiJOB
        local job = findExact(CONFIG.JOB_NAME)
        if not job then
            task.wait(3)
        else
            local jobPos = getPos(job)
            if jobPos then
                teleportTo(jobPos + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0))
                task.wait(CONFIG.WAIT_AT_JOB) 
                if not State.running then break end
                holdE(CONFIG.E_HOLD_JOB)
            end
        end
        if not State.running then break end
        task.wait(CONFIG.BETWEEN_STEPS)

        -- 2) Rider
        local rider = nil
        local tStart = tick()
        while tick() - tStart < 5 do
            if not State.running then break end
            rider = findMyRider()
            if rider then break end
            task.wait(0.5)
        end

        if not State.running then break end

        if not rider then
            task.wait(CONFIG.WAIT_NO_RIDER)
        else
            local riderPos = getPos(rider)
            if riderPos then
                teleportTo(riderPos + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0))
                task.wait(CONFIG.WAIT_BEFORE_E)
                if not State.running then break end
                holdE(CONFIG.E_HOLD_RIDER)
                if not State.running then break end
                task.wait(CONFIG.BETWEEN_STEPS)

                -- 3) StopZone
                local stopZone = findExact(CONFIG.STOP_ZONE_NAME)
                if stopZone then
                    local stopPos = getPos(stopZone)
                    if stopPos then
                        teleportTo(stopPos + Vector3.new(0, CONFIG.HEIGHT_OFFSET, 0))
                        task.wait(CONFIG.WAIT_AT_STOP)
                    else
                        task.wait(2)
                    end
                else
                    task.wait(2)
                end
            end
        end
        if not State.running then break end
        task.wait(CONFIG.BETWEEN_STEPS)
    end
    releaseE()
end

------------------------------------------------------------
-- ACTIONS
------------------------------------------------------------
startBtn.MouseButton1Click:Connect(function()
    ripple(startBtn)
    if State.running then return end
    State.running = true
    State.conn = task.spawn(mainLoop)
end)

stopBtn.MouseButton1Click:Connect(function()
    ripple(stopBtn)
    if not State.running then return end
    State.running = false
    releaseE()
end)

------------------------------------------------------------
-- DRAG
------------------------------------------------------------
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

------------------------------------------------------------
-- ENTRANCE
------------------------------------------------------------
main.BackgroundTransparency = 1
main.Position = UDim2.new(0.5, -210, 0.5, -90)
task.spawn(function()
    task.wait(0.05)
    tw(main, 0.45, { BackgroundTransparency = 0, Position = UDim2.new(0.5, -210, 0.5, -120) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end)

print("[Astralex Taxi Farmer v7] loaded.")

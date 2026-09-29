--[[
    Rivals — Xeno Modern
    Aimbot + ESP + Sleek GUI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================== CONFIG =====================
local Config = {
    Aimbot = {
        Enabled = false,
        FOV = 120,
        Smooth = 0.22,
        Shake = 0,
        TeamCheck = true,
        WallCheck = true,
        Target = "Head", -- Head / Body / Legs
    },
    ESP = {
        Enabled = true,
        TeamCheck = true,
        MaxDistance = 1200,
        Color = Color3.fromRGB(255, 55, 55),
    },
}

local State = {
    Holding = false,
    GUI = true,
}

local Parts = {
    Head = "Head",
    Body = "HumanoidRootPart",
    Legs = "LeftFoot",
}

-- ===================== UTILS =====================
local function alive(plr)
    local c = plr.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function enemy(plr)
    if not Config.Aimbot.TeamCheck then return true end
    if not LocalPlayer.Team then return true end
    return plr.Team ~= LocalPlayer.Team
end

local function visible(part)
    if not Config.Aimbot.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local hit = Workspace:Raycast(origin, dir, params)
    return not hit or hit.Instance:IsDescendantOf(part.Parent)
end

local function getPart(char)
    local name = Parts[Config.Aimbot.Target] or "Head"
    local p = char:FindFirstChild(name)
    if p then return p end
    if Config.Aimbot.Target == "Legs" then
        return char:FindFirstChild("Left Leg") or char:FindFirstChild("RightFoot") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function getTarget()
    local best, bestDist = nil, Config.Aimbot.FOV
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and alive(plr) and enemy(plr) then
            local part = getPart(plr.Character)
            if part and visible(part) then
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = part
                    end
                end
            end
        end
    end
    return best
end

-- ===================== ESP =====================
local highlights = {}

local function applyHL(plr)
    if highlights[plr] then
        highlights[plr]:Destroy()
        highlights[plr] = nil
    end
    if not Config.ESP.Enabled then return end
    if not alive(plr) or (Config.ESP.TeamCheck and not enemy(plr)) then return end
    local char = plr.Character
    if not char then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = Config.ESP.Color
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    highlights[plr] = hl
end

local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then applyHL(plr) end
    end
end

local function hook(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.7)
        applyHL(plr)
    end)
    if plr.Character then applyHL(plr) end
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then hook(plr) end
end
Players.PlayerAdded:Connect(hook)
Players.PlayerRemoving:Connect(function(plr)
    if highlights[plr] then
        highlights[plr]:Destroy()
        highlights[plr] = nil
    end
end)

-- ===================== AIM =====================
local function aim()
    if not Config.Aimbot.Enabled or not State.Holding then return end
    local t = getTarget()
    if not t then return end

    local pos = t.Position
    if Config.Aimbot.Shake > 0 then
        local s = Config.Aimbot.Shake
        pos = pos + Vector3.new(
            (math.random() - 0.5) * s,
            (math.random() - 0.5) * s,
            (math.random() - 0.5) * s
        )
    end

    local look = CFrame.lookAt(Camera.CFrame.Position, pos)
    Camera.CFrame = Camera.CFrame:Lerp(look, Config.Aimbot.Smooth)
end

-- ===================== GUI =====================
local SG = Instance.new("ScreenGui")
SG.Name = "RivalsModern"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = CoreGui end)
if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 340, 0, 360)
Main.Position = UDim2.new(0.5, -170, 0.4, -180)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = Main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(45, 45, 55)
stroke.Thickness = 1
stroke.Parent = Main

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
Header.BorderSizePixel = 0
Header.Parent = Main

local hc = Instance.new("UICorner")
hc.CornerRadius = UDim.new(0, 8)
hc.Parent = Header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "RIVALS"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.TextSize = 15
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = Header

-- Content
local Body = Instance.new("ScrollingFrame")
Body.Size = UDim2.new(1, -20, 1, -50)
Body.Position = UDim2.new(0, 10, 0, 42)
Body.BackgroundTransparency = 1
Body.BorderSizePixel = 0
Body.ScrollBarThickness = 3
Body.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70)
Body.CanvasSize = UDim2.new(0, 0, 0, 420)
Body.Parent = Main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.Parent = Body

local function section(text)
    local f = Instance.new("TextLabel")
    f.Size = UDim2.new(1, 0, 0, 22)
    f.BackgroundTransparency = 1
    f.Text = text
    f.TextColor3 = Color3.fromRGB(120, 120, 140)
    f.TextSize = 11
    f.Font = Enum.Font.GothamMedium
    f.TextXAlignment = Enum.TextXAlignment.Left
    f.Parent = Body
end

local function toggle(text, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    f.BorderSizePixel = 0
    f.Parent = Body
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -60, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(210, 210, 220)
    l.TextSize = 13
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 44, 0, 22)
    b.Position = UDim2.new(1, -52, 0.5, -11)
    b.BackgroundColor3 = default and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(50, 50, 60)
    b.Text = default and "ON" or "OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = b

    local on = default
    b.MouseButton1Click:Connect(function()
        on = not on
        b.Text = on and "ON" or "OFF"
        b.BackgroundColor3 = on and Color3.fromRGB(50, 180, 90) or Color3.fromRGB(50, 50, 60)
        cb(on)
    end)
end

local function slider(text, min, max, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 48)
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    f.BorderSizePixel = 0
    f.Parent = Body
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 20)
    l.Position = UDim2.new(0, 12, 0, 4)
    l.BackgroundTransparency = 1
    l.Text = text .. ": " .. string.format("%.2f", default)
    l.TextColor3 = Color3.fromRGB(210, 210, 220)
    l.TextSize = 13
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 6)
    bar.Position = UDim2.new(0, 12, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    bar.BorderSizePixel = 0
    bar.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 140, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill

    local dragging = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = min + (max - min) * rel
            fill.Size = UDim2.new(rel, 0, 1, 0)
            l.Text = text .. ": " .. string.format("%.2f", val)
            cb(val)
        end
    end)
end

local function dropdown(text, options, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    f.BorderSizePixel = 0
    f.Parent = Body
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.45, 0, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(210, 210, 220)
    l.TextSize = 13
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local idx = 1
    for i, v in ipairs(options) do
        if v == default then idx = i break end
    end

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.45, 0, 0, 22)
    b.Position = UDim2.new(0.5, 0, 0.5, -11)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    b.Text = options[idx]
    b.TextColor3 = Color3.fromRGB(230, 230, 240)
    b.TextSize = 12
    b.Font = Enum.Font.Gotham
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = b

    b.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        b.Text = options[idx]
        cb(options[idx])
    end)
end

-- Build GUI
section("AIMBOT")
toggle("Enabled", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
toggle("Team Check", Config.Aimbot.TeamCheck, function(v)
    Config.Aimbot.TeamCheck = v
    Config.ESP.TeamCheck = v
    refreshESP()
end)
toggle("Wall Check", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
dropdown("Target", {"Head", "Body", "Legs"}, Config.Aimbot.Target, function(v)
    Config.Aimbot.Target = v
end)
slider("FOV", 40, 300, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v end)
slider("Smoothness", 0.05, 1, Config.Aimbot.Smooth, function(v) Config.Aimbot.Smooth = v end)
slider("FOV Shake", 0, 3, Config.Aimbot.Shake, function(v) Config.Aimbot.Shake = v end)

section("ESP")
toggle("Enabled", Config.ESP.Enabled, function(v)
    Config.ESP.Enabled = v
    refreshESP()
end)
toggle("Team Check", Config.ESP.TeamCheck, function(v)
    Config.ESP.TeamCheck = v
    refreshESP()
end)

section("KEYBINDS")
local keyInfo = Instance.new("TextLabel")
keyInfo.Size = UDim2.new(1, 0, 0, 40)
keyInfo.BackgroundTransparency = 1
keyInfo.Text = "E  =  Hold Aimbot\nRightShift  =  Toggle GUI"
keyInfo.TextColor3 = Color3.fromRGB(140, 140, 160)
keyInfo.TextSize = 12
keyInfo.Font = Enum.Font.Gotham
keyInfo.TextXAlignment = Enum.TextXAlignment.Left
keyInfo.Parent = Body

-- ===================== INPUT =====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        State.Holding = true
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        State.GUI = not State.GUI
        Main.Visible = State.GUI
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then
        State.Holding = false
    end
end)

-- ===================== LOOP =====================
RunService.RenderStepped:Connect(aim)

task.spawn(function()
    while true do
        task.wait(2.5)
        if Config.ESP.Enabled then refreshESP() end
    end
end)

print("[Rivals] Modern loaded | E = Aim | RightShift = GUI")

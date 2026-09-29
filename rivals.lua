--[[
    Zelbro — Rivals
    Aimbot + ESP
    Xeno Compatible
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================== CONFIG =====================
local Config = {
    Aimbot = {
        Enabled = false,
        Key = Enum.KeyCode.E,
        FOV = 120,
        Smooth = 0.2,
        TeamCheck = true,
        WallCheck = true,
        Target = "Head", -- Head / Body / Legs
    },
    ESP = {
        Enabled = true,
        TeamCheck = true,
        MaxDistance = 1200,
        Color = Color3.fromRGB(255, 50, 50),
    },
}

local State = {
    Holding = false,
    GUI = true,
    CurrentTab = "aimbot",
}

local PartMap = {
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
    local result = Workspace:Raycast(origin, dir, params)
    return not result or result.Instance:IsDescendantOf(part.Parent)
end

local function getPart(char)
    local name = PartMap[Config.Aimbot.Target] or "Head"
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

-- ===================== AIMBOT (Lock) =====================
local function aim()
    if not Config.Aimbot.Enabled or not State.Holding then return end
    local t = getTarget()
    if not t then return end
    local look = CFrame.lookAt(Camera.CFrame.Position, t.Position)
    Camera.CFrame = Camera.CFrame:Lerp(look, Config.Aimbot.Smooth)
end

-- ===================== GUI (Zelbro) =====================
local SG = Instance.new("ScreenGui")
SG.Name = "Zelbro"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = CoreGui end)
if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 420, 0, 340)
Main.Position = UDim2.new(0.5, -210, 0.5, -170)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 6)
mainCorner.Parent = Main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(40, 40, 48)
mainStroke.Thickness = 1
mainStroke.Parent = Main

-- Top bar
local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 30)
Top.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
Top.BorderSizePixel = 0
Top.Parent = Main

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 6)
topCorner.Parent = Top

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Zelbro  v1"
Title.TextColor3 = Color3.fromRGB(220, 220, 230)
Title.TextSize = 13
Title.Font = Enum.Font.GothamMedium
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

-- Tabs
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 26)
TabBar.Position = UDim2.new(0, 0, 0, 30)
TabBar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local tabs = {"aimbot", "esp", "settings"}
local tabButtons = {}

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -66)
Content.Position = UDim2.new(0, 8, 0, 60)
Content.BackgroundTransparency = 1
Content.Parent = Main

local function clearContent()
    for _, v in ipairs(Content:GetChildren()) do
        v:Destroy()
    end
end

local function addToggle(name, y, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.Position = UDim2.new(0, 0, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -55, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 40, 0, 18)
    b.Position = UDim2.new(1, -48, 0.5, -9)
    b.BackgroundColor3 = default and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(50, 50, 58)
    b.Text = default and "ON" or "OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 10
    b.Font = Enum.Font.GothamBold
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 3)
    bc.Parent = b

    local on = default
    b.MouseButton1Click:Connect(function()
        on = not on
        b.Text = on and "ON" or "OFF"
        b.BackgroundColor3 = on and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(50, 50, 58)
        callback(on)
    end)
end

local function addSlider(name, y, min, max, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 42)
    f.Position = UDim2.new(0, 0, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 18)
    l.Position = UDim2.new(0, 10, 0, 3)
    l.BackgroundTransparency = 1
    l.Text = name .. ": " .. tostring(default)
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 26)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    bar.BorderSizePixel = 0
    bar.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(70, 130, 220)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fill

    local dragging = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = math.floor(min + (max - min) * rel + 0.5)
            if type(default) == "number" and default < 10 then
                val = tonumber(string.format("%.2f", min + (max - min) * rel))
            end
            fill.Size = UDim2.new(rel, 0, 1, 0)
            l.Text = name .. ": " .. tostring(val)
            callback(val)
        end
    end)
end

local function addDropdown(name, y, options, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.Position = UDim2.new(0, 0, 0, y)
    f.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.4, 0, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(200, 200, 210)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local idx = 1
    for i, v in ipairs(options) do
        if v == default then idx = i break end
    end

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, 0, 0, 20)
    b.Position = UDim2.new(0.45, 0, 0.5, -10)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    b.Text = options[idx]
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.TextSize = 11
    b.Font = Enum.Font.Gotham
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 3)
    bc.Parent = b

    b.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        b.Text = options[idx]
        callback(options[idx])
    end)
end

local function showAimbot()
    clearContent()
    State.CurrentTab = "aimbot"
    for name, btn in pairs(tabButtons) do
        btn.TextColor3 = name == "aimbot" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 150)
    end

    addToggle("Enabled", 0, Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
    addToggle("Team Check", 32, Config.Aimbot.TeamCheck, function(v)
        Config.Aimbot.TeamCheck = v
        Config.ESP.TeamCheck = v
        refreshESP()
    end)
    addToggle("Wall Check", 64, Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
    addDropdown("Target", 96, {"Head", "Body", "Legs"}, Config.Aimbot.Target, function(v)
        Config.Aimbot.Target = v
    end)
    addSlider("FOV", 128, 40, 300, Config.Aimbot.FOV, function(v) Config.Aimbot.FOV = v end)
    addSlider("Smooth", 176, 0.05, 1, Config.Aimbot.Smooth, function(v) Config.Aimbot.Smooth = v end)
end

local function showESP()
    clearContent()
    State.CurrentTab = "esp"
    for name, btn in pairs(tabButtons) do
        btn.TextColor3 = name == "esp" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 150)
    end

    addToggle("Enabled", 0, Config.ESP.Enabled, function(v)
        Config.ESP.Enabled = v
        refreshESP()
    end)
    addToggle("Team Check", 32, Config.ESP.TeamCheck, function(v)
        Config.ESP.TeamCheck = v
        refreshESP()
    end)
end

local function showSettings()
    clearContent()
    State.CurrentTab = "settings"
    for name, btn in pairs(tabButtons) do
        btn.TextColor3 = name == "settings" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 150)
    end

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 80)
    info.BackgroundTransparency = 1
    info.Text = "Keybinds\n\nE  =  Hold Aimbot (change in code)\nRightShift  =  Toggle Menu"
    info.TextColor3 = Color3.fromRGB(160, 160, 170)
    info.TextSize = 12
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextYAlignment = Enum.TextYAlignment.Top
    info.Parent = Content
end

-- Create tabs
local tabX = 10
for _, name in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 1, 0)
    btn.Position = UDim2.new(0, tabX, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(140, 140, 150)
    btn.TextSize = 12
    btn.Font = Enum.Font.Gotham
    btn.Parent = TabBar
    tabButtons[name] = btn
    tabX = tabX + 75

    btn.MouseButton1Click:Connect(function()
        if name == "aimbot" then showAimbot()
        elseif name == "esp" then showESP()
        else showSettings() end
    end)
end

showAimbot()

-- ===================== INPUT =====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.Aimbot.Key then
        State.Holding = true
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        State.GUI = not State.GUI
        Main.Visible = State.GUI
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Config.Aimbot.Key then
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

print("[Zelbro] loaded | E = Aim | RightShift = Menu")

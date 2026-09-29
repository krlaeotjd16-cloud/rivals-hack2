--[[
    Zelbro v2 — Rivals
    Aimbot + ESP + FOV Circle
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
        Target = "Head",
        ShowFOV = true,
    },
    ESP = {
        Enabled = false,
        TeamCheck = true,
        MaxDistance = 1200,
        Box = true,
        Health = true,
        Name = true,
        Color = Color3.fromRGB(255, 60, 60),
    },
}

local State = {
    Holding = false,
    GUI = true,
    Binding = false,
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

-- ===================== FOV CIRCLE =====================
local FOVRing = Instance.new("Frame")
FOVRing.Name = "ZelbroFOV"
FOVRing.AnchorPoint = Vector2.new(0.5, 0.5)
FOVRing.BackgroundTransparency = 1
FOVRing.Size = UDim2.new(0, Config.Aimbot.FOV * 2, 0, Config.Aimbot.FOV * 2)
FOVRing.Visible = false
FOVRing.Parent = SG or game:GetService("CoreGui") -- 임시, 아래에서 재설정

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = Color3.fromRGB(255, 255, 255)
FOVStroke.Thickness = 1.5
FOVStroke.Transparency = 0.3
FOVStroke.Parent = FOVRing

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVRing

-- ===================== ESP =====================
local espFolder = Instance.new("Folder")
espFolder.Name = "ZelbroESP"
espFolder.Parent = CoreGui

local function clearESP(plr)
    local old = espFolder:FindFirstChild(plr.Name)
    if old then old:Destroy() end
end

local function makeESP(plr)
    clearESP(plr)
    if not Config.ESP.Enabled then return end
    if not alive(plr) or (Config.ESP.TeamCheck and not enemy(plr)) then return end
    local char = plr.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = plr.Name
    bill.Adornee = root
    bill.Size = UDim2.new(0, 120, 0, 50)
    bill.StudsOffset = Vector3.new(0, 3.2, 0)
    bill.AlwaysOnTop = true
    bill.Parent = espFolder

    if Config.ESP.Name then
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 16)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = plr.Name
        nameLabel.TextColor3 = Config.ESP.Color
        nameLabel.TextSize = 12
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextStrokeTransparency = 0.5
        nameLabel.Parent = bill
    end

    if Config.ESP.Health then
        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(0.8, 0, 0, 5)
        bg.Position = UDim2.new(0.1, 0, 0, 18)
        bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        bg.BorderSizePixel = 0
        bg.Parent = bill
        local bgc = Instance.new("UICorner")
        bgc.CornerRadius = UDim.new(1, 0)
        bgc.Parent = bg

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(hum.Health / hum.MaxHealth, 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(50, 220, 80)
        fill.BorderSizePixel = 0
        fill.Parent = bg
        local fc = Instance.new("UICorner")
        fc.CornerRadius = UDim.new(1, 0)
        fc.Parent = fill

        hum.HealthChanged:Connect(function()
            if fill and fill.Parent then
                fill.Size = UDim2.new(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 0, 1, 0)
            end
        end)
    end

    -- Box (Highlight)
    if Config.ESP.Box then
        local hl = Instance.new("Highlight")
        hl.FillColor = Config.ESP.Color
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        bill:SetAttribute("HasHL", true)
    end
end

local function refreshESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            makeESP(plr)
        end
    end
end

local function hook(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.8)
        makeESP(plr)
    end)
    if plr.Character then makeESP(plr) end
end

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then hook(plr) end
end
Players.PlayerAdded:Connect(hook)
Players.PlayerRemoving:Connect(function(plr)
    clearESP(plr)
end)

-- ===================== AIM =====================
local function aim()
    if not Config.Aimbot.Enabled or not State.Holding then return end
    local t = getTarget()
    if not t then return end
    local look = CFrame.lookAt(Camera.CFrame.Position, t.Position)
    Camera.CFrame = Camera.CFrame:Lerp(look, Config.Aimbot.Smooth)
end

-- ===================== GUI =====================
local SG = Instance.new("ScreenGui")
SG.Name = "Zelbro"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = CoreGui end)
if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- FOV 원 부모 재설정
FOVRing.Parent = SG

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 400, 0, 380)
Main.Position = UDim2.new(0.5, -200, 0.5, -190)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 8)
mc.Parent = Main

local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(50, 50, 60)
ms.Thickness = 1
ms.Parent = Main

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 34)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
Header.BorderSizePixel = 0
Header.Parent = Main
local hc = Instance.new("UICorner")
hc.CornerRadius = UDim.new(0, 8)
hc.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Zelbro"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Tabs
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.new(0, 0, 0, 34)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -72)
Content.Position = UDim2.new(0, 8, 0, 66)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70)
Content.CanvasSize = UDim2.new(0, 0, 0, 500)
Content.Parent = Main

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 5)
UIList.Parent = Content

local tabBtns = {}

local function clear()
    for _, v in ipairs(Content:GetChildren()) do
        if not v:IsA("UIListLayout") then v:Destroy() end
    end
end

local function toggle(name, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -55, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(210, 210, 220)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 42, 0, 20)
    b.Position = UDim2.new(1, -50, 0.5, -10)
    b.BackgroundColor3 = default and Color3.fromRGB(45, 170, 85) or Color3.fromRGB(48, 48, 56)
    b.Text = default and "ON" or "OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 10
    b.Font = Enum.Font.GothamBold
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = b

    local on = default
    b.MouseButton1Click:Connect(function()
        on = not on
        b.Text = on and "ON" or "OFF"
        b.BackgroundColor3 = on and Color3.fromRGB(45, 170, 85) or Color3.fromRGB(48, 48, 56)
        cb(on)
    end)
end

local function slider(name, min, max, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 44)
    f.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 18)
    l.Position = UDim2.new(0, 12, 0, 4)
    l.BackgroundTransparency = 1
    l.Text = name .. ": " .. tostring(default)
    l.TextColor3 = Color3.fromRGB(210, 210, 220)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 6)
    bar.Position = UDim2.new(0, 12, 0, 28)
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

    local drag = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local val = min + (max - min) * rel
            if max <= 5 then val = tonumber(string.format("%.2f", val))
            else val = math.floor(val + 0.5) end
            fill.Size = UDim2.new(rel, 0, 1, 0)
            l.Text = name .. ": " .. tostring(val)
            cb(val)
        end
    end)
end

local function dropdown(name, options, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.4, 0, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(210, 210, 220)
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
    b.Position = UDim2.new(0.42, 0, 0.5, -10)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    b.Text = options[idx]
    b.TextColor3 = Color3.fromRGB(230, 230, 240)
    b.TextSize = 11
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

local function keybind(name, current, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 28)
    f.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 1, 0)
    l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(210, 210, 220)
    l.TextSize = 12
    l.Font = Enum.Font.Gotham
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.4, 0, 0, 20)
    b.Position = UDim2.new(0.55, 0, 0.5, -10)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    b.Text = current.Name
    b.TextColor3 = Color3.fromRGB(230, 230, 240)
    b.TextSize = 11
    b.Font = Enum.Font.Gotham
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 4)
    bc.Parent = b

    b.MouseButton1Click:Connect(function()
        b.Text = "..."
        State.Binding = true
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Config.Aimbot.Key = input.KeyCode
                b.Text = input.KeyCode.Name
                State.Binding = false
                conn:Disconnect()
                cb(input.KeyCode)
            end
        end)
    end)
end

local function showAimbot()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "aimbot" and Color3.fromRGB(255,255,255) or Color3.fromRGB(130,130,140)
    end
    toggle("Enabled", Config.Aimbot.Enabled, function(v)
        Config.Aimbot.Enabled = v
        FOVRing.Visible = v and Config.Aimbot.ShowFOV
    end)
    toggle("Show FOV Circle", Config.Aimbot.ShowFOV, function(v)
        Config.Aimbot.ShowFOV = v
        FOVRing.Visible = Config.Aimbot.Enabled and v
    end)
    toggle("Team Check", Config.Aimbot.TeamCheck, function(v) Config.Aimbot.TeamCheck = v end)
    toggle("Wall Check", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
    dropdown("Target", {"Head", "Body", "Legs"}, Config.Aimbot.Target, function(v) Config.Aimbot.Target = v end)
    slider("FOV Size", 40, 300, Config.Aimbot.FOV, function(v)
        Config.Aimbot.FOV = v
        FOVRing.Size = UDim2.new(0, v * 2, 0, v * 2)
    end)
    slider("Smoothness", 0.05, 1, Config.Aimbot.Smooth, function(v) Config.Aimbot.Smooth = v end)
    keybind("Aim Key", Config.Aimbot.Key, function(k) Config.Aimbot.Key = k end)
end

local function showESP()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "esp" and Color3.fromRGB(255,255,255) or Color3.fromRGB(130,130,140)
    end
    toggle("Enabled", Config.ESP.Enabled, function(v)
        Config.ESP.Enabled = v
        refreshESP()
    end)
    toggle("Box", Config.ESP.Box, function(v)
        Config.ESP.Box = v
        refreshESP()
    end)
    toggle("Health Bar", Config.ESP.Health, function(v)
        Config.ESP.Health = v
        refreshESP()
    end)
    toggle("Name", Config.ESP.Name, function(v)
        Config.ESP.Name = v
        refreshESP()
    end)
    toggle("Team Check", Config.ESP.TeamCheck, function(v)
        Config.ESP.TeamCheck = v
        refreshESP()
    end)
end

local function showSettings()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "settings" and Color3.fromRGB(255,255,255) or Color3.fromRGB(130,130,140)
    end
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 60)
    info.BackgroundTransparency = 1
    info.Text = "RightShift = Toggle Menu\nAim Key는 Aimbot 탭에서 변경"
    info.TextColor3 = Color3.fromRGB(150, 150, 160)
    info.TextSize = 12
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = Content
end

-- Tabs
local names = {"aimbot", "esp", "settings"}
local x = 12
for _, n in ipairs(names) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 70, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.BackgroundTransparency = 1
    b.Text = n
    b.TextColor3 = Color3.fromRGB(130, 130, 140)
    b.TextSize = 12
    b.Font = Enum.Font.Gotham
    b.Parent = TabBar
    tabBtns[n] = b
    x = x + 78
    b.MouseButton1Click:Connect(function()
        if n == "aimbot" then showAimbot()
        elseif n == "esp" then showESP()
        else showSettings() end
    end)
end

showAimbot()

-- ===================== INPUT =====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp or State.Binding then return end
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
RunService.RenderStepped:Connect(function()
    aim()
    -- FOV 위치 마우스 따라다니게
    local m = UserInputService:GetMouseLocation()
    FOVRing.Position = UDim2.new(0, m.X, 0, m.Y)
end)

task.spawn(function()
    while true do
        task.wait(2)
        if Config.ESP.Enabled then refreshESP() end
    end
end)

print("[Zelbro] v2 loaded | RightShift = Menu")

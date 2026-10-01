--[[
    Zelbro v3 — Rivals
    Real Executor Optimized
    Aimbot + ESP (Box/Skeleton/Health/Name) + FOV Circle
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
        Key = Enum.UserInputType.MouseButton2, -- 우클릭
        FOV = 120,
        Smooth = 0.18,
        TeamCheck = true,
        WallCheck = true,
        Target = "Head", -- Head / Body / Legs
        ShowFOV = true,
        Silent = false,
    },
    ESP = {
        Enabled = false,
        TeamCheck = true,
        MaxDistance = 1500,
        Box = true,
        Skeleton = true,
        Health = true,
        Name = true,
        Tracer = false,
        Color = Color3.fromRGB(255, 55, 55),
        FriendColor = Color3.fromRGB(50, 255, 100),
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
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local result = Workspace:Raycast(origin, dir.Unit * dir.Magnitude, params)
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

local function worldToScreen(pos)
    local s, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), on, s.Z
end

local function getTarget()
    local best, bestDist = nil, Config.Aimbot.FOV
    local mouse = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and alive(plr) and enemy(plr) then
            local part = getPart(plr.Character)
            if part and visible(part) then
                local sp, on = worldToScreen(part.Position)
                if on then
                    local d = (sp - mouse).Magnitude
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
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Radius = Config.Aimbot.FOV
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Transparency = 0.8
FOVCircle.Visible = false

-- ===================== ESP =====================
local ESPObjects = {}

local function removeESP(plr)
    local obj = ESPObjects[plr]
    if not obj then return end
    for _, v in pairs(obj) do
        if typeof(v) == "userdata" and v.Remove then
            pcall(function() v:Remove() end)
        elseif typeof(v) == "Instance" then
            pcall(function() v:Destroy() end)
        end
    end
    ESPObjects[plr] = nil
end

local function createESP(plr)
    removeESP(plr)
    if not Config.ESP.Enabled then return end

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false

    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    name.Visible = false

    local healthBar = Drawing.new("Line")
    healthBar.Thickness = 2
    healthBar.Visible = false

    local healthBg = Drawing.new("Line")
    healthBg.Thickness = 2
    healthBg.Color = Color3.fromRGB(30, 30, 30)
    healthBg.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Visible = false

    -- Skeleton lines
    local skeleton = {}
    local bones = {"Head-Torso", "Torso-LeftArm", "Torso-RightArm", "Torso-LeftLeg", "Torso-RightLeg"}
    for i = 1, 5 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Visible = false
        skeleton[i] = line
    end

    ESPObjects[plr] = {
        box = box,
        name = name,
        healthBar = healthBar,
        healthBg = healthBg,
        tracer = tracer,
        skeleton = skeleton,
    }
end

local function updateESP()
    for plr, obj in pairs(ESPObjects) do
        if not alive(plr) or (Config.ESP.TeamCheck and not enemy(plr)) then
            obj.box.Visible = false
            obj.name.Visible = false
            obj.healthBar.Visible = false
            obj.healthBg.Visible = false
            obj.tracer.Visible = false
            for _, line in ipairs(obj.skeleton) do line.Visible = false end
            continue
        end

        local char = plr.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not head or not hum then
            obj.box.Visible = false
            continue
        end

        local rootPos, onScreen, depth = worldToScreen(root.Position)
        if not onScreen or depth > Config.ESP.MaxDistance then
            obj.box.Visible = false
            obj.name.Visible = false
            obj.healthBar.Visible = false
            obj.healthBg.Visible = false
            obj.tracer.Visible = false
            for _, line in ipairs(obj.skeleton) do line.Visible = false end
            continue
        end

        local headPos = worldToScreen(head.Position + Vector3.new(0, 0.5, 0))
        local footPos = worldToScreen(root.Position - Vector3.new(0, 3, 0))
        local height = math.abs(headPos.Y - footPos.Y)
        local width = height / 1.8
        local color = enemy(plr) and Config.ESP.Color or Config.ESP.FriendColor

        -- Box
        if Config.ESP.Box then
            obj.box.Size = Vector2.new(width, height)
            obj.box.Position = Vector2.new(rootPos.X - width/2, headPos.Y)
            obj.box.Color = color
            obj.box.Visible = true
        else
            obj.box.Visible = false
        end

        -- Name
        if Config.ESP.Name then
            obj.name.Text = plr.Name
            obj.name.Position = Vector2.new(rootPos.X, headPos.Y - 16)
            obj.name.Color = color
            obj.name.Visible = true
        else
            obj.name.Visible = false
        end

        -- Health Bar
        if Config.ESP.Health then
            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barX = rootPos.X - width/2 - 6
            obj.healthBg.From = Vector2.new(barX, footPos.Y)
            obj.healthBg.To = Vector2.new(barX, headPos.Y)
            obj.healthBg.Visible = true

            obj.healthBar.From = Vector2.new(barX, footPos.Y)
            obj.healthBar.To = Vector2.new(barX, footPos.Y - (height * hp))
            obj.healthBar.Color = Color3.fromRGB(255 * (1 - hp), 255 * hp, 40)
            obj.healthBar.Visible = true
        else
            obj.healthBar.Visible = false
            obj.healthBg.Visible = false
        end

        -- Tracer
        if Config.ESP.Tracer then
            obj.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
            obj.tracer.To = Vector2.new(rootPos.X, footPos.Y)
            obj.tracer.Color = color
            obj.tracer.Visible = true
        else
            obj.tracer.Visible = false
        end

        -- Skeleton
        if Config.ESP.Skeleton then
            local function getPos(partName)
                local p = char:FindFirstChild(partName)
                if p then
                    local sp, on = worldToScreen(p.Position)
                    return on and sp or nil
                end
                return nil
            end

            local h = getPos("Head")
            local t = getPos("UpperTorso") or getPos("Torso") or getPos("HumanoidRootPart")
            local la = getPos("LeftHand") or getPos("Left Arm")
            local ra = getPos("RightHand") or getPos("Right Arm")
            local ll = getPos("LeftFoot") or getPos("Left Leg")
            local rl = getPos("RightFoot") or getPos("Right Leg")

            local connections = {
                {h, t},
                {t, la},
                {t, ra},
                {t, ll},
                {t, rl},
            }

            for i, conn in ipairs(connections) do
                if conn[1] and conn[2] then
                    obj.skeleton[i].From = conn[1]
                    obj.skeleton[i].To = conn[2]
                    obj.skeleton[i].Color = color
                    obj.skeleton[i].Visible = true
                else
                    obj.skeleton[i].Visible = false
                end
            end
        else
            for _, line in ipairs(obj.skeleton) do line.Visible = false end
        end
    end
end

-- ===================== AIMBOT =====================
local function aim()
    if not Config.Aimbot.Enabled or not State.Holding then return end
    local target = getTarget()
    if not target then return end

    local pos = target.Position
    local look = CFrame.lookAt(Camera.CFrame.Position, pos)
    Camera.CFrame = Camera.CFrame:Lerp(look, Config.Aimbot.Smooth)
end

-- ===================== GUI =====================
local SG = Instance.new("ScreenGui")
SG.Name = "Zelbro"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = CoreGui end)
if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 410, 0, 400)
Main.Position = UDim2.new(0.5, -205, 0.5, -200)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 17)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 8)
mc.Parent = Main

local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(45, 45, 55)
ms.Thickness = 1
ms.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 34)
Header.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
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

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.new(0, 0, 0, 34)
TabBar.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -16, 1, -72)
Content.Position = UDim2.new(0, 8, 0, 66)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 70)
Content.CanvasSize = UDim2.new(0, 0, 0, 550)
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
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
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
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
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
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
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
    f.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
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
    b.Text = typeof(current) == "EnumItem" and current.Name or "RMB"
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
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                Config.Aimbot.Key = Enum.UserInputType.MouseButton1
                b.Text = "LMB"
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                Config.Aimbot.Key = Enum.UserInputType.MouseButton2
                b.Text = "RMB"
            else return end
            State.Binding = false
            conn:Disconnect()
            cb(Config.Aimbot.Key)
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
        FOVCircle.Visible = v and Config.Aimbot.ShowFOV
    end)
    toggle("Show FOV", Config.Aimbot.ShowFOV, function(v)
        Config.Aimbot.ShowFOV = v
        FOVCircle.Visible = Config.Aimbot.Enabled and v
    end)
    toggle("Team Check", Config.Aimbot.TeamCheck, function(v) Config.Aimbot.TeamCheck = v end)
    toggle("Wall Check", Config.Aimbot.WallCheck, function(v) Config.Aimbot.WallCheck = v end)
    dropdown("Target", {"Head", "Body", "Legs"}, Config.Aimbot.Target, function(v) Config.Aimbot.Target = v end)
    slider("FOV Size", 40, 350, Config.Aimbot.FOV, function(v)
        Config.Aimbot.FOV = v
        FOVCircle.Radius = v
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
        if v then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then createESP(plr) end
            end
        else
            for plr in pairs(ESPObjects) do removeESP(plr) end
        end
    end)
    toggle("Box", Config.ESP.Box, function(v) Config.ESP.Box = v end)
    toggle("Skeleton", Config.ESP.Skeleton, function(v) Config.ESP.Skeleton = v end)
    toggle("Health Bar", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    toggle("Name", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    toggle("Tracer", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
    toggle("Team Check", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)
end

local function showSettings()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "settings" and Color3.fromRGB(255,255,255) or Color3.fromRGB(130,130,140)
    end
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 70)
    info.BackgroundTransparency = 1
    info.Text = "RightShift = Toggle Menu\nAim Key는 Aimbot 탭에서 변경 가능\n기본 키: 우클릭 (RMB)"
    info.TextColor3 = Color3.fromRGB(150, 150, 160)
    info.TextSize = 12
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = Content
end

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
    local key = Config.Aimbot.Key
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        if input.KeyCode == key then State.Holding = true end
    else
        if input.UserInputType == key then State.Holding = true end
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        State.GUI = not State.GUI
        Main.Visible = State.GUI
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local key = Config.Aimbot.Key
    if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
        if input.KeyCode == key then State.Holding = false end
    else
        if input.UserInputType == key then State.Holding = false end
    end
end)

-- ===================== LOOP =====================
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Visible = Config.Aimbot.Enabled and Config.Aimbot.ShowFOV

    aim()
    if Config.ESP.Enabled then updateESP() end
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then createESP(plr) end
end
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Config.ESP.Enabled then createESP(plr) end
    end)
end)
Players.PlayerRemoving:Connect(removeESP)

print("[Zelbro] v3 Real loaded | RMB = Aim | RightShift = Menu")

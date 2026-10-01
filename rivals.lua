--[[
    Zelbro v5 — Rivals
    Real Executor | Black & White
    Lobby Distance Filter + Unlock Skins + Skybox
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================== CONFIG =====================
local Config = {
    Aimbot = {
        Enabled = false,
        FOV = 130,
        Smooth = 0.35,
        TeamCheck = true,
        WallCheck = true,
        Target = "Head",
        ShowFOV = true,
        MaxDistance = 400, -- 로비 필터 (이 거리 넘으면 타겟 안 함)
    },
    ESP = {
        Enabled = false,
        TeamCheck = true,
        MaxDistance = 1600,
        Box = true,
        Skeleton = true,
        Health = true,
        Name = true,
        Tracer = false,
        Color = Color3.fromRGB(255, 255, 255),
    },
    Skin = {
        UnlockAll = false,
    },
    World = {
        Skybox = false,
    },
}

local State = { GUI = true }

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
    local center = Camera.ViewportSize / 2
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and alive(plr) and enemy(plr) then
            local part = getPart(plr.Character)
            if part and visible(part) then
                local dist3D = (part.Position - myRoot.Position).Magnitude
                if dist3D > Config.Aimbot.MaxDistance then
                    continue -- 로비 사람 필터
                end

                local sp, on = worldToScreen(part.Position)
                if on then
                    local d = (sp - center).Magnitude
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

-- ===================== FOV (중앙 고정) =====================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.NumSides = 64
FOVCircle.Radius = Config.Aimbot.FOV
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Transparency = 0.7
FOVCircle.Visible = false

-- ===================== ESP =====================
local ESPObjects = {}

local function removeESP(plr)
    local obj = ESPObjects[plr]
    if not obj then return end
    for _, v in pairs(obj) do
        if typeof(v) == "table" then
            for _, line in pairs(v) do pcall(function() line:Remove() end) end
        else
            pcall(function() v:Remove() end)
        end
    end
    ESPObjects[plr] = nil
end

local function createESP(plr)
    removeESP(plr)
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false

    local name = Drawing.new("Text")
    name.Size = 13
    name.Center = true
    name.Outline = true
    name.Font = 2
    name.Visible = false

    local hpBar = Drawing.new("Line")
    hpBar.Thickness = 2
    hpBar.Visible = false

    local hpBg = Drawing.new("Line")
    hpBg.Thickness = 2
    hpBg.Color = Color3.fromRGB(40, 40, 40)
    hpBg.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Visible = false

    local skeleton = {}
    for i = 1, 5 do
        local line = Drawing.new("Line")
        line.Thickness = 1.5
        line.Visible = false
        skeleton[i] = line
    end

    ESPObjects[plr] = {
        box = box, name = name,
        hpBar = hpBar, hpBg = hpBg,
        tracer = tracer, skeleton = skeleton
    }
end

local function updateESP()
    local center = Camera.ViewportSize / 2
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    for plr, obj in pairs(ESPObjects) do
        if not Config.ESP.Enabled or not alive(plr) or (Config.ESP.TeamCheck and not enemy(plr)) then
            obj.box.Visible = false
            obj.name.Visible = false
            obj.hpBar.Visible = false
            obj.hpBg.Visible = false
            obj.tracer.Visible = false
            for _, l in ipairs(obj.skeleton) do l.Visible = false end
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

        -- 로비 필터 (ESP도 너무 먼 사람 제외)
        if myRoot and (root.Position - myRoot.Position).Magnitude > 500 then
            obj.box.Visible = false
            obj.name.Visible = false
            obj.hpBar.Visible = false
            obj.hpBg.Visible = false
            obj.tracer.Visible = false
            for _, l in ipairs(obj.skeleton) do l.Visible = false end
            continue
        end

        local rootPos, onScreen, depth = worldToScreen(root.Position)
        if not onScreen or depth > Config.ESP.MaxDistance then
            obj.box.Visible = false
            obj.name.Visible = false
            obj.hpBar.Visible = false
            obj.hpBg.Visible = false
            obj.tracer.Visible = false
            for _, l in ipairs(obj.skeleton) do l.Visible = false end
            continue
        end

        local headPos = worldToScreen(head.Position + Vector3.new(0, 0.4, 0))
        local footPos = worldToScreen(root.Position - Vector3.new(0, 3, 0))
        local height = math.abs(headPos.Y - footPos.Y)
        local width = height / 1.9
        local color = Config.ESP.Color

        if Config.ESP.Box then
            obj.box.Size = Vector2.new(width, height)
            obj.box.Position = Vector2.new(rootPos.X - width/2, headPos.Y)
            obj.box.Color = color
            obj.box.Visible = true
        else
            obj.box.Visible = false
        end

        if Config.ESP.Name then
            obj.name.Text = plr.Name
            obj.name.Position = Vector2.new(rootPos.X, headPos.Y - 15)
            obj.name.Color = color
            obj.name.Visible = true
        else
            obj.name.Visible = false
        end

        if Config.ESP.Health then
            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barX = rootPos.X - width/2 - 5
            obj.hpBg.From = Vector2.new(barX, footPos.Y)
            obj.hpBg.To = Vector2.new(barX, headPos.Y)
            obj.hpBg.Visible = true
            obj.hpBar.From = Vector2.new(barX, footPos.Y)
            obj.hpBar.To = Vector2.new(barX, footPos.Y - height * hp)
            -- 체력 색: 흰색 → 빨간색 그라데이션
            obj.hpBar.Color = Color3.fromRGB(255, math.floor(80 + 175 * hp), math.floor(80 * hp))
            obj.hpBar.Visible = true
        else
            obj.hpBar.Visible = false
            obj.hpBg.Visible = false
        end

        if Config.ESP.Tracer then
            obj.tracer.From = Vector2.new(center.X, Camera.ViewportSize.Y)
            obj.tracer.To = Vector2.new(rootPos.X, footPos.Y)
            obj.tracer.Color = color
            obj.tracer.Visible = true
        else
            obj.tracer.Visible = false
        end

        if Config.ESP.Skeleton then
            local function gp(n)
                local p = char:FindFirstChild(n)
                if p then
                    local s, o = worldToScreen(p.Position)
                    return o and s or nil
                end
            end
            local h = gp("Head")
            local t = gp("UpperTorso") or gp("Torso") or gp("HumanoidRootPart")
            local la = gp("LeftHand") or gp("Left Arm")
            local ra = gp("RightHand") or gp("Right Arm")
            local ll = gp("LeftFoot") or gp("Left Leg")
            local rl = gp("RightFoot") or gp("Right Leg")
            local conns = {{h,t},{t,la},{t,ra},{t,ll},{t,rl}}
            for i, c in ipairs(conns) do
                if c[1] and c[2] then
                    obj.skeleton[i].From = c[1]
                    obj.skeleton[i].To = c[2]
                    obj.skeleton[i].Color = color
                    obj.skeleton[i].Visible = true
                else
                    obj.skeleton[i].Visible = false
                end
            end
        else
            for _, l in ipairs(obj.skeleton) do l.Visible = false end
        end
    end
end

-- ===================== AIMBOT =====================
local function aim()
    if not Config.Aimbot.Enabled then return end
    local target = getTarget()
    if not target then return end
    local look = CFrame.lookAt(Camera.CFrame.Position, target.Position)
    local s = math.clamp(Config.Aimbot.Smooth, 0.12, 1)
    Camera.CFrame = Camera.CFrame:Lerp(look, s)
end

-- ===================== SKIN UNLOCK =====================
local function unlockAllSkins()
    if not Config.Skin.UnlockAll then return end
    -- 일반적인 스킨 언락 패턴
    for _, v in pairs(getgc(true)) do
        if typeof(v) == "table" then
            if rawget(v, "Skins") or rawget(v, "OwnedSkins") or rawget(v, "Unlocked") then
                pcall(function()
                    for key, _ in pairs(v) do
                        if typeof(key) == "string" and (key:lower():find("skin") or key:lower():find("unlock")) then
                            v[key] = true
                        end
                    end
                end)
            end
        end
    end
    -- Remote로도 시도
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _, r in pairs(remotes:GetDescendants()) do
            if r:IsA("RemoteEvent") and (r.Name:lower():find("skin") or r.Name:lower():find("unlock")) then
                pcall(function() r:FireServer(true) end)
            end
        end
    end
end

-- ===================== SKYBOX =====================
local originalSky = nil
local function setSkybox(on)
    if on then
        if not originalSky then
            originalSky = Lighting:FindFirstChildOfClass("Sky")
        end
        local sky = Instance.new("Sky")
        sky.SkyboxBk = "rbxassetid://159454299"
        sky.SkyboxDn = "rbxassetid://159454296"
        sky.SkyboxFt = "rbxassetid://159454293"
        sky.SkyboxLf = "rbxassetid://159454286"
        sky.SkyboxRt = "rbxassetid://159454300"
        sky.SkyboxUp = "rbxassetid://159454288"
        sky.Parent = Lighting
        if originalSky then originalSky.Parent = nil end
    else
        local current = Lighting:FindFirstChildOfClass("Sky")
        if current and current ~= originalSky then current:Destroy() end
        if originalSky then originalSky.Parent = Lighting end
    end
end

-- ===================== GUI =====================
local SG = Instance.new("ScreenGui")
SG.Name = "Zelbro"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() SG.Parent = CoreGui end)
if not SG.Parent then SG.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 380, 0, 440)
Main.Position = UDim2.new(0.5, -190, 0.5, -220)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = SG

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 6)
mc.Parent = Main

local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(255, 255, 255)
ms.Thickness = 1
ms.Transparency = 0.7
ms.Parent = Main

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -16, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "ZELBRO"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Font = Enum.Font.Code
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 26)
TabBar.Position = UDim2.new(0, 0, 0, 32)
TabBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -12, 1, -68)
Content.Position = UDim2.new(0, 6, 0, 62)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 2
Content.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
Content.CanvasSize = UDim2.new(0, 0, 0, 560)
Content.Parent = Main

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 4)
UIList.Parent = Content

local tabBtns = {}

local function clear()
    for _, v in ipairs(Content:GetChildren()) do
        if not v:IsA("UIListLayout") then v:Destroy() end
    end
end

local function toggle(name, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 3)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -50, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.TextSize = 12
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 38, 0, 18)
    b.Position = UDim2.new(1, -46, 0.5, -9)
    b.BackgroundColor3 = default and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 40, 40)
    b.Text = default and "ON" or "OFF"
    b.TextColor3 = default and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
    b.TextSize = 10
    b.Font = Enum.Font.Code
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 2)
    bc.Parent = b

    local on = default
    b.MouseButton1Click:Connect(function()
        on = not on
        b.Text = on and "ON" or "OFF"
        b.BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(40, 40, 40)
        b.TextColor3 = on and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200)
        cb(on)
    end)
end

local function slider(name, min, max, default, cb)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 40)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 3)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 0, 16)
    l.Position = UDim2.new(0, 10, 0, 3)
    l.BackgroundTransparency = 1
    l.Text = name .. ": " .. tostring(default)
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.TextSize = 11
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 5)
    bar.Position = UDim2.new(0, 10, 0, 26)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bar.BorderSizePixel = 0
    bar.Parent = f

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BorderSizePixel = 0
    fill.Parent = bar

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
    f.Size = UDim2.new(1, 0, 0, 26)
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    f.BorderSizePixel = 0
    f.Parent = Content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 3)
    c.Parent = f

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.4, 0, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = name
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.TextSize = 12
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local idx = 1
    for i, v in ipairs(options) do
        if v == default then idx = i break end
    end

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.5, 0, 0, 18)
    b.Position = UDim2.new(0.42, 0, 0.5, -9)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    b.Text = options[idx]
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 11
    b.Font = Enum.Font.Code
    b.Parent = f
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 2)
    bc.Parent = b

    b.MouseButton1Click:Connect(function()
        idx = idx % #options + 1
        b.Text = options[idx]
        cb(options[idx])
    end)
end

local function showAimbot()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "aimbot" and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,120,120)
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
    slider("Smoothness", 0.12, 1, Config.Aimbot.Smooth, function(v) Config.Aimbot.Smooth = v end)
    slider("Max Dist (Lobby Filter)", 100, 800, Config.Aimbot.MaxDistance, function(v) Config.Aimbot.MaxDistance = v end)
end

local function showESP()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "esp" and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,120,120)
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
    toggle("Health", Config.ESP.Health, function(v) Config.ESP.Health = v end)
    toggle("Name", Config.ESP.Name, function(v) Config.ESP.Name = v end)
    toggle("Tracer", Config.ESP.Tracer, function(v) Config.ESP.Tracer = v end)
    toggle("Team Check", Config.ESP.TeamCheck, function(v) Config.ESP.TeamCheck = v end)
end

local function showSkin()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "skin" and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,120,120)
    end
    toggle("Unlock All Skins", Config.Skin.UnlockAll, function(v)
        Config.Skin.UnlockAll = v
        if v then unlockAllSkins() end
    end)
end

local function showWorld()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "world" and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,120,120)
    end
    toggle("Skybox", Config.World.Skybox, function(v)
        Config.World.Skybox = v
        setSkybox(v)
    end)
end

local function showSettings()
    clear()
    for n, btn in pairs(tabBtns) do
        btn.TextColor3 = n == "settings" and Color3.fromRGB(255,255,255) or Color3.fromRGB(120,120,120)
    end
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, 60)
    info.BackgroundTransparency = 1
    info.Text = "RightShift = Menu\nAimbot = Toggle (Enabled 버튼)\nMax Dist로 로비 필터 조절"
    info.TextColor3 = Color3.fromRGB(160, 160, 160)
    info.TextSize = 11
    info.Font = Enum.Font.Code
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = Content
end

local names = {"aimbot", "esp", "skin", "world", "settings"}
local x = 6
for _, n in ipairs(names) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 68, 1, 0)
    b.Position = UDim2.new(0, x, 0, 0)
    b.BackgroundTransparency = 1
    b.Text = n
    b.TextColor3 = Color3.fromRGB(120, 120, 120)
    b.TextSize = 11
    b.Font = Enum.Font.Code
    b.Parent = TabBar
    tabBtns[n] = b
    x = x + 72
    b.MouseButton1Click:Connect(function()
        if n == "aimbot" then showAimbot()
        elseif n == "esp" then showESP()
        elseif n == "skin" then showSkin()
        elseif n == "world" then showWorld()
        else showSettings() end
    end)
end

showAimbot()

-- ===================== INPUT =====================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        State.GUI = not State.GUI
        Main.Visible = State.GUI
    end
end)

-- ===================== LOOP =====================
RunService.RenderStepped:Connect(function()
    local center = Camera.ViewportSize / 2
    FOVCircle.Position = center
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
        task.wait(0.4)
        if Config.ESP.Enabled then createESP(plr) end
    end)
end)
Players.PlayerRemoving:Connect(removeESP)

print("[Zelbro] v5 loaded | RightShift = Menu")

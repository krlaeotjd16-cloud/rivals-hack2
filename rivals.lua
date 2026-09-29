--[[
    Rivals — Aim / ESP / Skin / Range + Bypass
    GUI: Unnamed style
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================== CONFIG =====================
local Config = {
    Aimbot = {
        Enabled = true,
        Key = Enum.KeyCode.E,
        FOV = 130,
        Smoothness = 0.15,
        TeamCheck = true,
        VisibleCheck = true,
        TargetPart = "Head",
        Prediction = 0.14,
        Silent = true,
    },
    ESP = {
        Enabled = true,
        Boxes = true,
        Names = true,
        Tracers = true,
        Distance = true,
        TeamCheck = true,
        MaxDistance = 900,
        ColorEnemy = Color3.fromRGB(255, 45, 45),
        ColorTeam = Color3.fromRGB(45, 255, 110),
    },
    SkinHack = {
        Enabled = true,
        ForceSkin = "Gold",
        ApplyOnSpawn = true,
    },
    RangeMode = {
        Enabled = false,
        Key = Enum.KeyCode.R,
        Multiplier = 2.8,
        OriginalRange = nil,
    },
    Bypass = {
        AntiKick = true,
        BlockBadRemotes = true,
    },
    UI = {
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255),
    }
}

local State = {
    AimbotActive = false,
    RangeActive = false,
    ESPObjects = {},
    CurrentTarget = nil,
    SilentTarget = nil,
    GUIVisible = true,
}

-- ===================== UTILS =====================
local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isEnemy(player)
    if not Config.Aimbot.TeamCheck then return true end
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

local function getClosestPart(char)
    local part = char:FindFirstChild(Config.Aimbot.TargetPart)
    return part or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function worldToScreen(pos)
    local screen, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), onScreen, screen.Z
end

local function isVisible(part)
    if not Config.Aimbot.VisibleCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    local result = Workspace:Raycast(origin, dir.Unit * dir.Magnitude, params)
    return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

-- ===================== AIMBOT =====================
local function getBestTarget()
    local best, bestDist = nil, Config.Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) and isEnemy(plr) then
            local part = getClosestPart(plr.Character)
            if part and isVisible(part) then
                local screenPos, onScreen = worldToScreen(part.Position)
                if onScreen then
                    local dist = (screenPos - mousePos).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        best = part
                    end
                end
            end
        end
    end
    return best
end

local function aimAt(part)
    if not part then return end
    local targetPos = part.Position
    local hum = part.Parent:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then
        targetPos = targetPos + (hum.RootPart.AssemblyLinearVelocity * Config.Aimbot.Prediction)
    end
    if Config.Aimbot.Silent then
        State.SilentTarget = targetPos
        return
    end
    local screenPos = Camera:WorldToViewportPoint(targetPos)
    local mousePos = UserInputService:GetMouseLocation()
    local delta = Vector2.new(screenPos.X, screenPos.Y) - mousePos
    mousemoverel(delta.X * (1 - Config.Aimbot.Smoothness), delta.Y * (1 - Config.Aimbot.Smoothness))
end

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 64
FOVCircle.Radius = Config.Aimbot.FOV
FOVCircle.Filled = false
FOVCircle.Color = Config.UI.FOVColor
FOVCircle.Visible = Config.UI.ShowFOV

-- ===================== ESP =====================
local function createESP(player)
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Visible = false
    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    name.Visible = false
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Visible = false
    local dist = Drawing.new("Text")
    dist.Size = 13
    dist.Center = true
    dist.Outline = true
    dist.Visible = false
    State.ESPObjects[player] = {box = box, name = name, tracer = tracer, dist = dist}
end

local function removeESP(player)
    local obj = State.ESPObjects[player]
    if obj then
        for _, v in pairs(obj) do v:Remove() end
        State.ESPObjects[player] = nil
    end
end

local function updateESP()
    for plr, drawings in pairs(State.ESPObjects) do
        if not isAlive(plr) or (Config.ESP.TeamCheck and not isEnemy(plr)) then
            drawings.box.Visible = false
            drawings.name.Visible = false
            drawings.tracer.Visible = false
            drawings.dist.Visible = false
            continue
        end
        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not root or not head then
            drawings.box.Visible = false
            continue
        end
        local rootPos, onScreen, depth = worldToScreen(root.Position)
        local headPos = worldToScreen(head.Position + Vector3.new(0, 0.5, 0))
        local footPos = worldToScreen(root.Position - Vector3.new(0, 3, 0))
        if not onScreen or depth > Config.ESP.MaxDistance then
            drawings.box.Visible = false
            drawings.name.Visible = false
            drawings.tracer.Visible = false
            drawings.dist.Visible = false
            continue
        end
        local height = math.abs(headPos.Y - footPos.Y)
        local width = height / 2
        local color = isEnemy(plr) and Config.ESP.ColorEnemy or Config.ESP.ColorTeam
        if Config.ESP.Boxes then
            drawings.box.Size = Vector2.new(width, height)
            drawings.box.Position = Vector2.new(rootPos.X - width/2, headPos.Y)
            drawings.box.Color = color
            drawings.box.Visible = true
        end
        if Config.ESP.Names then
            drawings.name.Text = plr.Name
            drawings.name.Position = Vector2.new(rootPos.X, headPos.Y - 16)
            drawings.name.Color = color
            drawings.name.Visible = true
        end
        if Config.ESP.Tracers then
            drawings.tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
            drawings.tracer.To = Vector2.new(rootPos.X, footPos.Y)
            drawings.tracer.Color = color
            drawings.tracer.Visible = true
        end
        if Config.ESP.Distance then
            local metres = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
            drawings.dist.Text = metres .. "m"
            drawings.dist.Position = Vector2.new(rootPos.X, footPos.Y + 2)
            drawings.dist.Color = color
            drawings.dist.Visible = true
        end
    end
end

-- ===================== SKIN + RANGE =====================
local function applySkin(char)
    if not Config.SkinHack.Enabled then return end
    local skinValue = char:FindFirstChild("Skin") or char:FindFirstChild("CurrentSkin")
    if skinValue and skinValue:IsA("StringValue") then
        skinValue.Value = Config.SkinHack.ForceSkin
    end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local skinRemote = remotes:FindFirstChild("ChangeSkin") or remotes:FindFirstChild("EquipSkin")
        if skinRemote and skinRemote:IsA("RemoteEvent") then
            pcall(function() skinRemote:FireServer(Config.SkinHack.ForceSkin) end)
        end
    end
end

local function setRange(active)
    State.RangeActive = active
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local rangeVal = tool:FindFirstChild("Range") or tool:FindFirstChild("MaxRange") or tool:FindFirstChild("BulletRange")
        if rangeVal and rangeVal:IsA("NumberValue") then
            if active then
                if not Config.RangeMode.OriginalRange then
                    Config.RangeMode.OriginalRange = rangeVal.Value
                end
                rangeVal.Value = Config.RangeMode.OriginalRange * Config.RangeMode.Multiplier
            else
                if Config.RangeMode.OriginalRange then
                    rangeVal.Value = Config.RangeMode.OriginalRange
                end
            end
        end
    end
    for _, mod in ipairs(getgc(true)) do
        if typeof(mod) == "table" and rawget(mod, "Range") then
            if active then
                if not Config.RangeMode.OriginalRange then
                    Config.RangeMode.OriginalRange = mod.Range
                end
                mod.Range = Config.RangeMode.OriginalRange * Config.RangeMode.Multiplier
            else
                if Config.RangeMode.OriginalRange then
                    mod.Range = Config.RangeMode.OriginalRange
                end
            end
        end
    end
end

-- ===================== BYPASS =====================
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if Config.Bypass.AntiKick then
        if method == "Kick" or method == "kick" then return end
        if typeof(self) == "Instance" and self.ClassName == "RemoteEvent" then
            local name = self.Name:lower()
            if name:find("kick") or name:find("ban") or name:find("detect") or name:find("anticheat") then
                return
            end
        end
    end
    if Config.Bypass.BlockBadRemotes and method == "FireServer" then
        local name = tostring(self.Name):lower()
        if name:find("report") or name:find("flag") or name:find("log") or name:find("detect") then
            return
        end
    end
    return oldNamecall(self, ...)
end))

local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
    if Config.Aimbot.Silent and State.AimbotActive and State.SilentTarget then
        if self == Camera and key == "CFrame" then
            return CFrame.lookAt(Camera.CFrame.Position, State.SilentTarget)
        end
    end
    return oldIndex(self, key)
end))

-- ===================== UNNAMED STYLE GUI =====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RivalsUnnamed"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 420, 0, 320)
Main.Position = UDim2.new(0.5, -210, 0.5, -160)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 6)
Corner.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 6)
TopCorner.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Rivals  |  Unnamed"
Title.TextColor3 = Color3.fromRGB(220, 220, 220)
Title.TextSize = 14
Title.Font = Enum.Font.GothamMedium
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -32, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TopBar

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 1, -50)
Container.Position = UDim2.new(0, 10, 0, 40)
Container.BackgroundTransparency = 1
Container.Parent = Main

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0, 6)
UIList.Parent = Container

local function makeToggle(text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    frame.BorderSizePixel = 0
    frame.Parent = Container

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 0, 20)
    btn.Position = UDim2.new(1, -46, 0.5, -10)
    btn.BackgroundColor3 = default and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(60, 60, 60)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 3)
    bc.Parent = btn

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 80) or Color3.fromRGB(60, 60, 60)
        callback(state)
    end)
end

makeToggle("Aimbot (Silent)", Config.Aimbot.Enabled, function(v) Config.Aimbot.Enabled = v end)
makeToggle("ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
makeToggle("Boxes", Config.ESP.Boxes, function(v) Config.ESP.Boxes = v end)
makeToggle("Names", Config.ESP.Names, function(v) Config.ESP.Names = v end)
makeToggle("Tracers", Config.ESP.Tracers, function(v) Config.ESP.Tracers = v end)
makeToggle("Distance", Config.ESP.Distance, function(v) Config.ESP.Distance = v end)
makeToggle("Team Check", Config.Aimbot.TeamCheck, function(v)
    Config.Aimbot.TeamCheck = v
    Config.ESP.TeamCheck = v
end)
makeToggle("Skin Hack", Config.SkinHack.Enabled, function(v) Config.SkinHack.Enabled = v end)
makeToggle("Range Mode", Config.RangeMode.Enabled, function(v)
    Config.RangeMode.Enabled = v
    setRange(v)
end)
makeToggle("Show FOV", Config.UI.ShowFOV, function(v)
    Config.UI.ShowFOV = v
    FOVCircle.Visible = v
end)
makeToggle("Anti-Kick", Config.Bypass.AntiKick, function(v) Config.Bypass.AntiKick = v end)

CloseBtn.MouseButton1Click:Connect(function()
    State.GUIVisible = not State.GUIVisible
    Main.Visible = State.GUIVisible
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        State.GUIVisible = not State.GUIVisible
        Main.Visible = State.GUIVisible
    end
    if input.KeyCode == Config.Aimbot.Key then
        State.AimbotActive = true
    elseif input.KeyCode == Config.RangeMode.Key then
        Config.RangeMode.Enabled = not Config.RangeMode.Enabled
        setRange(Config.RangeMode.Enabled)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Config.Aimbot.Key then
        State.AimbotActive = false
        State.SilentTarget = nil
    end
end)

-- ===================== MAIN LOOP =====================
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Radius = Config.Aimbot.FOV
    FOVCircle.Visible = Config.UI.ShowFOV and Config.Aimbot.Enabled

    if Config.Aimbot.Enabled and State.AimbotActive then
        local target = getBestTarget()
        State.CurrentTarget = target
        if target then
            aimAt(target)
        else
            State.SilentTarget = nil
        end
    end
    if Config.ESP.Enabled then
        updateESP()
    end
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then createESP(plr) end
end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if Config.SkinHack.ApplyOnSpawn then applySkin(char) end
    if Config.RangeMode.Enabled then setRange(true) end
end)
if LocalPlayer.Character then applySkin(LocalPlayer.Character) end

print("[Rivals] Loaded | GUI: RightShift | Aim: E | Range: R")
